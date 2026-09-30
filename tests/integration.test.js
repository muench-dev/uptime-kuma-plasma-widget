const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const KUMA_URL = process.env.KUMA_URL;
const KUMA_API_KEY = process.env.KUMA_API_KEY || "uk1_mysecretkey";

// If KUMA_URL is not set, skip integration tests cleanly
if (!KUMA_URL) {
    describe("Uptime Kuma Real Instance Integration Tests", () => {
        it.skip("Integration tests skipped: KUMA_URL environment variable is not set", () => {});
    });
} else {
    // XMLHttpRequest polyfill for Node.js using native fetch
    class SimpleXHR {
        static DONE = 4;
        constructor() {
            this.readyState = 0;
            this.status = 0;
            this.responseText = "";
            this.headers = {};
            this.responseHeaders = {};
        }
        open(method, url) {
            this.method = method;
            this.url = url;
        }
        setRequestHeader(name, val) {
            this.headers[name] = val;
        }
        getResponseHeader(name) {
            return this.responseHeaders[name.toLowerCase()] || null;
        }
        send() {
            fetch(this.url, {
                method: this.method,
                headers: this.headers
            }).then(async res => {
                this.status = res.status;
                this.responseText = await res.text();
                res.headers.forEach((v, k) => { this.responseHeaders[k.toLowerCase()] = v; });
                this.readyState = SimpleXHR.DONE;
                if (this.onreadystatechange) this.onreadystatechange();
            }).catch(err => {
                if (this.onerror) this.onerror(err);
            });
        }
    }
    global.XMLHttpRequest = SimpleXHR;

    function loadService() {
        const filePath = path.resolve(__dirname, "../contents/code/uptimeKumaService.js");
        let code = fs.readFileSync(filePath, "utf8");
        code = code.replace(".pragma library", "");
        const context = {};
        const fn = new Function("exports", code + `
            exports.fetchAll = fetchAll;
            exports.fetchFromMetricsWithCandidates = fetchFromMetricsWithCandidates;
            exports.getAuthHeaders = getAuthHeaders;
            exports.STATUS_UP = STATUS_UP;
            exports.STATUS_DOWN = STATUS_DOWN;
        `);
        fn(context);
        return context;
    }

    const service = loadService();

    describe(`Real Uptime Kuma Integration (${KUMA_URL})`, () => {

        it("fetches public status page and parses monitors and heartbeats", async () => {
            const data = await new Promise((resolve, reject) => {
                service.fetchAll(KUMA_URL, "default", "", 10, (result) => {
                    resolve(result);
                }, (err) => {
                    reject(new Error("fetchAll failed: " + err));
                });
            });

            assert.equal(data.title, "Production Services");
            assert.ok(Array.isArray(data.monitors), "monitors should be an array");
            assert.equal(data.monitors.length, 1, "should have 1 seeded monitor");

            const mon = data.monitors[0];
            assert.equal(mon.name, "Web Frontend");
            assert.equal(mon.status, service.STATUS_UP);
            assert.equal(mon.statusText, "Up");
            assert.equal(mon.statusColor, "#2ecc71");
            assert.ok(Array.isArray(mon.heartbeats), "heartbeats should be an array");
            assert.ok(mon.heartbeats.length > 0, "should contain at least 1 heartbeat");

            // Verify stats calculation
            assert.equal(data.stats.total, 1);
            assert.equal(data.stats.up, 1);
            assert.equal(data.stats.down, 0);
            assert.equal(data.stats.overallStatus, service.STATUS_UP);
            assert.equal(data.stats.overallStatusText, "All Systems Operational");
        });

        it("scrapes Prometheus /metrics with API key and handles metrics format", async () => {
            const authCandidates = service.getAuthHeaders(KUMA_API_KEY);
            const data = await new Promise((resolve, reject) => {
                service.fetchFromMetricsWithCandidates(KUMA_URL, authCandidates, 0, 10, (result) => {
                    resolve(result);
                }, (err) => {
                    reject(new Error("fetchFromMetrics failed: " + err));
                });
            });

            assert.ok(Array.isArray(data.monitors));
            assert.equal(data.monitors.length, 1);

            const mon = data.monitors[0];
            assert.equal(mon.name, "Web Frontend");
            assert.equal(mon.status, service.STATUS_UP);
            assert.equal(mon.statusText, "Up");
            assert.equal(typeof mon.ping, "number");
            assert.ok(mon.ping >= 0);

            // Verify stats calculation from metrics
            assert.equal(data.stats.total, 1);
            assert.equal(data.stats.up, 1);
            assert.equal(data.stats.down, 0);
        });

        it("fails authentication with invalid API key on /metrics", async () => {
            const invalidAuth = service.getAuthHeaders("uk1_definitely_invalid_key");
            const err = await new Promise((resolve) => {
                service.fetchFromMetricsWithCandidates(KUMA_URL, invalidAuth, 0, 10, (result) => {
                    resolve(null);
                }, (errMsg) => {
                    resolve(errMsg);
                });
            });

            assert.ok(err, "should fail with error when given invalid API key");
            assert.match(err, /401|auth|failed/i);
        });

    });
}
