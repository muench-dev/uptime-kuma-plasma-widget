const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

function loadService() {
    const filePath = path.resolve(__dirname, "../contents/code/uptimeKumaService.js");
    let code = fs.readFileSync(filePath, "utf8");
    code = code.replace(".pragma library", "");
    const context = {};
    const fn = new Function("exports", code + `
        exports.toBase64 = toBase64;
        exports.parseUrlAndSlug = parseUrlAndSlug;
        exports.getSlugCandidates = getSlugCandidates;
        exports.getAuthHeaders = getAuthHeaders;
        exports.computeGroupStats = computeGroupStats;
        exports.parsePrometheusLabels = parsePrometheusLabels;
        exports.processPrometheusMetrics = processPrometheusMetrics;
        exports.processApiData = processApiData;
        exports.getStatusText = getStatusText;
        exports.getStatusColor = getStatusColor;
        exports.getStatusIcon = getStatusIcon;
        exports.getOverallStatusText = getOverallStatusText;
        exports.formatPing = formatPing;
        exports.getPingColor = getPingColor;
        exports.formatTime = formatTime;
        exports.getDemoData = getDemoData;
        exports.extractGroups = extractGroups;
        exports.parseGroupFilter = parseGroupFilter;
        exports.filterByGroup = filterByGroup;
        exports.STATUS_DOWN = STATUS_DOWN;
        exports.STATUS_UP = STATUS_UP;
        exports.STATUS_PENDING = STATUS_PENDING;
        exports.STATUS_MAINTENANCE = STATUS_MAINTENANCE;
    `);
    fn(context);
    return context;
}

const service = loadService();

describe("Uptime Kuma Service", () => {

    describe("parseUrlAndSlug", () => {
        it("handles empty URL with default slug", () => {
            const res = service.parseUrlAndSlug("", "custom");
            assert.equal(res.baseUrl, "");
            assert.equal(res.slug, "custom");
        });

        it("prepends https to standard hostnames and trims slashes", () => {
            const res = service.parseUrlAndSlug("status.example.com///", "default");
            assert.equal(res.baseUrl, "https://status.example.com");
            assert.equal(res.slug, "default");
        });

        it("prepends http to local IP addresses and localhost", () => {
            const resLocal = service.parseUrlAndSlug("localhost:3001", "default");
            assert.equal(resLocal.baseUrl, "http://localhost:3001");

            const resIp = service.parseUrlAndSlug("192.168.1.50:3001", "default");
            assert.equal(resIp.baseUrl, "http://192.168.1.50:3001");
        });

        it("extracts baseUrl and slug from full status page URL", () => {
            const res = service.parseUrlAndSlug("https://kuma.example.com/status/infrastructure", "default");
            assert.equal(res.baseUrl, "https://kuma.example.com");
            assert.equal(res.slug, "infrastructure");
        });

        it("extracts baseUrl and slug from API status page URL", () => {
            const res = service.parseUrlAndSlug("https://kuma.example.com/api/status-page/internal-apps", "default");
            assert.equal(res.baseUrl, "https://kuma.example.com");
            assert.equal(res.slug, "internal-apps");
        });
    });

    describe("getSlugCandidates", () => {
        it("returns default when slug is empty", () => {
            assert.deepEqual(service.getSlugCandidates(""), ["default"]);
            assert.deepEqual(service.getSlugCandidates(null), ["default"]);
        });

        it("slugifies titles and converts dots/spaces to hyphens", () => {
            const candidates = service.getSlugCandidates("muench.lan");
            assert.ok(candidates.includes("muench.lan"));
            assert.ok(candidates.includes("muench-lan"));
        });
    });

    describe("getAuthHeaders", () => {
        it("returns empty string array when no auth header is provided", () => {
            assert.deepEqual(service.getAuthHeaders(""), [""]);
        });

        it("generates Basic Auth with empty username for API keys", () => {
            const headers = service.getAuthHeaders("uk2_abcdef123456");
            assert.ok(headers.some(h => h.startsWith("Basic ")));
            assert.ok(headers.some(h => h.startsWith("Bearer ")));
        });

        it("preserves explicit Basic and Bearer auth tokens", () => {
            const basic = service.getAuthHeaders("Basic dXNlcjpwYXNz");
            assert.equal(basic[0], "Basic dXNlcjpwYXNz");

            const bearer = service.getAuthHeaders("Bearer mytoken123");
            assert.ok(bearer.includes("Bearer mytoken123"));
        });
    });

    describe("parsePrometheusLabels", () => {
        it("parses label key-value pairs correctly", () => {
            const line = 'monitor_status{monitor_id="42",monitor_name="Web App",monitor_type="http"} 1';
            const labels = service.parsePrometheusLabels(line);
            assert.equal(labels.monitor_id, "42");
            assert.equal(labels.monitor_name, "Web App");
            assert.equal(labels.monitor_type, "http");
        });

        it("handles empty or malformed strings gracefully", () => {
            assert.deepEqual(service.parsePrometheusLabels(""), {});
            assert.deepEqual(service.parsePrometheusLabels("no braces"), {});
        });
    });

    describe("processPrometheusMetrics", () => {
        it("processes Uptime Kuma v2 metrics format (with monitor_id, group, uptime ratio)", () => {
            const v2Metrics = `
# HELP monitor_status Monitor Status
monitor_status{monitor_id="1",monitor_name="Frontend",monitor_type="http",monitor_group="Web"} 1
monitor_response_time{monitor_id="1",monitor_name="Frontend",monitor_type="http",monitor_group="Web"} 45
monitor_uptime_ratio{monitor_id="1",monitor_name="Frontend",monitor_type="http",monitor_group="Web",window="1d"} 0.9995
monitor_cert_days_remaining{monitor_id="1",monitor_name="Frontend",monitor_type="http",monitor_group="Web"} 90
            `;
            const data = service.processPrometheusMetrics(v2Metrics, "https://kuma.example", 25);
            assert.equal(data.monitors.length, 1);
            const m = data.monitors[0];
            assert.equal(m.id, 1);
            assert.equal(m.name, "Frontend");
            assert.equal(m.groupName, "Web");
            assert.equal(m.status, service.STATUS_UP);
            assert.equal(m.ping, 45);
            assert.equal(m.uptime24h, 99.95);
            assert.equal(m.tags.length, 1);
            assert.equal(m.tags[0].name, "SSL 90d");
        });

        it("processes Uptime Kuma v1 metrics format (without monitor_id, with negative ping)", () => {
            const v1Metrics = `
# HELP monitor_status Monitor Status
monitor_status{monitor_hostname="null",monitor_name="Old Server",monitor_port="null",monitor_type="http",monitor_url="https://old.com"} 1
monitor_response_time{monitor_hostname="null",monitor_name="Old Server",monitor_port="null",monitor_type="http",monitor_url="https://old.com"} 32
monitor_status{monitor_hostname="db.local",monitor_name="Database",monitor_port="5432",monitor_type="port",monitor_url=""} 0
monitor_response_time{monitor_hostname="db.local",monitor_name="Database",monitor_port="5432",monitor_type="port",monitor_url=""} -1
            `;
            const data = service.processPrometheusMetrics(v1Metrics, "https://kuma.example", 25);
            assert.equal(data.monitors.length, 2);

            const mUp = data.monitors.find(m => m.name === "Old Server");
            assert.ok(mUp);
            assert.equal(mUp.status, service.STATUS_UP);
            assert.equal(mUp.ping, 32);

            const mDown = data.monitors.find(m => m.name === "Database");
            assert.ok(mDown);
            assert.equal(mDown.status, service.STATUS_DOWN);
            assert.equal(mDown.ping, null, "Negative response time in v1 must be converted to null");
        });
    });

    describe("processApiData", () => {
        it("handles Uptime Kuma v1 status page schema (single incident object)", () => {
            const statusPage = {
                config: { title: "v1 Status Page" },
                incident: {
                    id: 1,
                    title: "Network Maintenance",
                    content: "Switch upgrade in progress",
                    createdDate: "2026-09-29T12:00:00Z"
                },
                publicGroupList: [{
                    id: 1,
                    name: "Core Infrastructure",
                    monitorList: [{ id: 10, name: "Web Server", type: "http" }]
                }]
            };
            const heartbeats = {
                heartbeatList: { "10": [{ status: 1, ping: 22, time: "2026-09-29T12:05:00Z" }] },
                uptimeList: { "10_24": 0.999 }
            };

            const result = service.processApiData(statusPage, heartbeats, "https://kuma.example", "default", 25);
            assert.equal(result.incidents.length, 1);
            assert.equal(result.incidents[0].title, "Network Maintenance");
            assert.equal(result.monitors.length, 1);
            assert.equal(result.monitors[0].uptime24h, 99.9);
            assert.equal(result.monitors[0].ping, 22);
        });

        it("handles Uptime Kuma v2 status page schema (incidents array)", () => {
            const statusPage = {
                config: { title: "v2 Status Page" },
                incidents: [
                    { id: 1, title: "Active Incident", content: "Troubleshooting", createdDate: "2026-09-29T12:00:00Z" },
                    { id: 2, title: "Second Incident", content: "Investigating", createdDate: "2026-09-29T12:10:00Z" }
                ],
                publicGroupList: [{
                    id: 1,
                    name: "Public Services",
                    monitorList: [{ id: 20, name: "API Gateway", type: "http" }]
                }]
            };
            const heartbeats = {
                heartbeatList: { "20": [{ status: 1, ping: 12, time: "2026-09-29T12:05:00Z" }] },
                uptimeList: { "20_24": 1.0 }
            };

            const result = service.processApiData(statusPage, heartbeats, "https://kuma.example", "default", 25);
            assert.equal(result.incidents.length, 2);
            assert.equal(result.incidents[0].title, "Active Incident");
            assert.equal(result.monitors.length, 1);
            assert.equal(result.monitors[0].uptime24h, 100.0);
        });
    });

    describe("computeGroupStats", () => {
        it("correctly identifies all systems operational", () => {
            const monitors = [
                { status: service.STATUS_UP, ping: 20, uptime24h: 100.0 },
                { status: service.STATUS_UP, ping: 40, uptime24h: 100.0 }
            ];
            const stats = service.computeGroupStats(monitors);
            assert.equal(stats.total, 2);
            assert.equal(stats.up, 2);
            assert.equal(stats.down, 0);
            assert.equal(stats.hasDown, false);
            assert.equal(stats.overallStatus, service.STATUS_UP);
            assert.equal(stats.averagePing, 30);
            assert.equal(stats.overallStatusText, "All Systems Operational");
        });

        it("correctly identifies service disruptions", () => {
            const monitors = [
                { status: service.STATUS_UP, ping: 20, uptime24h: 100.0 },
                { status: service.STATUS_DOWN, ping: null, uptime24h: 90.0 }
            ];
            const stats = service.computeGroupStats(monitors);
            assert.equal(stats.total, 2);
            assert.equal(stats.up, 1);
            assert.equal(stats.down, 1);
            assert.equal(stats.hasDown, true);
            assert.equal(stats.overallStatus, service.STATUS_DOWN);
            assert.equal(stats.overallStatusText, "1 Service Disrupted");
        });
    });

    describe("extractGroups and filterByGroup", () => {
        const demoData = service.getDemoData(25);

        it("extracts unique group names from dataset", () => {
            const groups = service.extractGroups(demoData);
            assert.ok(groups.includes("Public Infrastructure"));
            assert.ok(groups.includes("Core Services"));
            assert.ok(groups.includes("Background Services"));
        });

        it("filters dataset by single group", () => {
            const filtered = service.filterByGroup(demoData, "Core Services");
            assert.ok(filtered.monitors.length > 0);
            for (const m of filtered.monitors) {
                assert.equal(m.groupName, "Core Services");
            }
        });

        it("filters dataset by pipe-separated multi-group", () => {
            const filtered = service.filterByGroup(demoData, "Core Services|Public Infrastructure");
            assert.ok(filtered.monitors.length > 0);
            for (const m of filtered.monitors) {
                assert.ok(m.groupName === "Core Services" || m.groupName === "Public Infrastructure");
            }
        });

        it("returns original dataset when filter is empty or 'all'", () => {
            assert.equal(service.filterByGroup(demoData, ""), demoData);
            assert.equal(service.filterByGroup(demoData, "all"), demoData);
        });
    });

    describe("formatting helpers", () => {
        it("formats ping and returns appropriate color threshold", () => {
            assert.equal(service.formatPing(null), "--");
            assert.equal(service.formatPing(45), "45 ms");
            assert.equal(service.getPingColor(50), "#2ecc71");
            assert.equal(service.getPingColor(150), "#f1c40f");
            assert.equal(service.getPingColor(400), "#e67e22");
        });

        it("maps status codes to text and colors", () => {
            assert.equal(service.getStatusText(service.STATUS_UP), "Up");
            assert.equal(service.getStatusText(service.STATUS_DOWN), "Down");
            assert.equal(service.getStatusColor(service.STATUS_UP), "#2ecc71");
            assert.equal(service.getStatusColor(service.STATUS_DOWN), "#e74c3c");
        });
    });
});
