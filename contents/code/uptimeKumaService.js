.pragma library

// Monitor status constants
const STATUS_DOWN = 0;
const STATUS_UP = 1;
const STATUS_PENDING = 2;
const STATUS_MAINTENANCE = 3;

/**
 * Pure JS Base64 encoder (reliable in all QML / QtQuick runtimes)
 */
function toBase64(str) {
    if (typeof Qt !== "undefined" && Qt.btoa) {
        return Qt.btoa(str);
    }
    if (typeof btoa === "function") {
        return btoa(str);
    }
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var output = "";
    for (var block = 0, charCode, idx = 0, map = chars;
        str.charAt(idx | 0) || (map = '=', idx % 1);
        output += map.charAt(63 & block >> 8 - idx % 1 * 8)) {
        charCode = str.charCodeAt(idx += 3/4);
        block = block << 8 | charCode;
    }
    return output;
}

/**
 * Normalizes user-entered server URL and slug.
 */
function parseUrlAndSlug(inputUrl, defaultSlug) {
    if (!inputUrl || inputUrl.trim().length === 0) {
        return { baseUrl: "", slug: defaultSlug || "default" };
    }

    var url = inputUrl.trim();
    var slug = defaultSlug ? defaultSlug.trim() : "default";

    // Handle full status page URLs
    // e.g. https://kuma.example.com/status/my-services
    var statusMatch = url.match(/^(https?:\/\/[^\/]+)\/status\/([^\/\?#]+)/i);
    if (statusMatch) {
        return {
            baseUrl: statusMatch[1],
            slug: statusMatch[2]
        };
    }

    // e.g. https://kuma.example.com/api/status-page/my-services
    var apiMatch = url.match(/^(https?:\/\/[^\/]+)\/api\/status-page\/([^\/\?#]+)/i);
    if (apiMatch) {
        return {
            baseUrl: apiMatch[1],
            slug: apiMatch[2]
        };
    }

    // Prepend http/https if missing
    if (!url.match(/^https?:\/\//i)) {
        if (url.startsWith("localhost") || url.startsWith("127.0.0.1") || url.match(/^192\.168\./) || url.match(/^10\./)) {
            url = "http://" + url;
        } else {
            url = "https://" + url;
        }
    }

    // Remove trailing slash
    url = url.replace(/\/+$/, "");

    return {
        baseUrl: url,
        slug: slug || "default"
    };
}

/**
 * Generates candidate slugs based on user input.
 * Uptime Kuma slugifies status page titles/slugs (replacing dots, spaces, slashes with hyphens).
 */
function getSlugCandidates(slug) {
    if (!slug || slug.trim().length === 0) {
        return ["default"];
    }
    var clean = slug.trim();
    var candidates = [clean];

    // Uptime Kuma slugified form: lowercase, dots/spaces/slashes/underscores to hyphens
    var slugified = clean.toLowerCase()
        .replace(/[\._\s\/]+/g, "-")
        .replace(/[^a-z0-9_-]+/g, "")
        .replace(/^-+|-+$/g, "");

    if (slugified.length > 0 && candidates.indexOf(slugified) === -1) {
        candidates.push(slugified);
    }

    // Try hyphen-to-dot variant if applicable
    var withDots = clean.replace(/-/g, ".");
    if (withDots !== clean && candidates.indexOf(withDots) === -1) {
        candidates.push(withDots);
    }

    return candidates;
}

/**
 * Build candidate Authorization headers for Uptime Kuma.
 * In Uptime Kuma, API keys (uk1_..., uk2_...) require Basic Auth:
 * Authorization: Basic base64(:<apiKey>)
 */
function getAuthHeaders(rawAuth) {
    if (!rawAuth || rawAuth.trim().length === 0) {
        return [""];
    }

    var trimmed = rawAuth.trim();
    var candidates = [];

    // Extract raw key if user prefixed with "Bearer " or passed "uk..."
    var ukMatch = trimmed.match(/^(?:Bearer\s+)?(uk[0-9a-zA-Z_-]+)$/i);
    if (ukMatch) {
        var apiKey = ukMatch[1];
        // Uptime Kuma requires Basic Auth with empty username for API keys
        candidates.push("Basic " + toBase64(":" + apiKey));
        candidates.push("Bearer " + apiKey);
        return candidates;
    }

    if (trimmed.startsWith("Basic ")) {
        candidates.push(trimmed);
        return candidates;
    }

    if (trimmed.startsWith("Bearer ")) {
        candidates.push(trimmed);
        var tokenWithoutBearer = trimmed.replace(/^Bearer\s+/i, "");
        candidates.push("Basic " + toBase64(":" + tokenWithoutBearer));
        return candidates;
    }

    // Generic token
    candidates.push("Bearer " + trimmed);
    candidates.push("Basic " + toBase64(":" + trimmed));
    candidates.push(trimmed);
    return candidates;
}

/**
 * Perform an HTTP request with custom headers
 */
function requestHttp(url, authHeader, acceptHeader, onSuccess, onError, redirectCount) {
    redirectCount = redirectCount || 0;
    if (redirectCount > 5) {
        if (onError) onError("Too many HTTP redirects", 310);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    if (acceptHeader) {
        xhr.setRequestHeader("Accept", acceptHeader);
    }

    if (authHeader && authHeader.trim().length > 0) {
        var h = authHeader.trim();
        if (h.indexOf(":") !== -1 && !h.startsWith("Basic ") && !h.startsWith("Bearer ")) {
            var parts = h.split(":");
            xhr.setRequestHeader(parts[0].trim(), parts.slice(1).join(":").trim());
        } else {
            xhr.setRequestHeader("Authorization", h);
        }
    }

    xhr.timeout = 15000;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    if (onSuccess) onSuccess(xhr.responseText, xhr.status);
                } catch (e) {
                    if (onError) onError("Error processing response: " + e.message, xhr.status);
                }
            } else if (xhr.status >= 301 && xhr.status <= 308) {
                var redirectLocation = xhr.getResponseHeader("Location");
                if (redirectLocation) {
                    if (redirectLocation.startsWith("/")) {
                        var parsedOrigin = url.match(/^(https?:\/\/[^\/]+)/i);
                        if (parsedOrigin) redirectLocation = parsedOrigin[1] + redirectLocation;
                    }
                    requestHttp(redirectLocation, authHeader, acceptHeader, onSuccess, onError, redirectCount + 1);
                    return;
                }
                if (onError) onError("HTTP redirect " + xhr.status + " without Location header", xhr.status);
            } else if (xhr.status === 404) {
                if (onError) onError("Not found (HTTP 404)", 404);
            } else if (xhr.status === 401 || xhr.status === 403) {
                if (onError) onError("Authorization failed (HTTP " + xhr.status + ")", xhr.status);
            } else if (xhr.status === 0) {
                if (onError) onError("Unable to connect to server. Check URL, network, or SSL certificate.", 0);
            } else {
                if (onError) onError("HTTP error " + xhr.status + ": " + (xhr.statusText || "Request failed"), xhr.status);
            }
        }
    };

    xhr.ontimeout = function() {
        if (onError) onError("Connection timed out after 15 seconds.", -1);
    };

    xhr.onerror = function() {
        if (onError) onError("Network request failed. Is the server online?", -2);
    };

    try {
        xhr.send();
    } catch (e) {
        if (onError) onError("Network error: " + e.message, -3);
    }
}

/**
 * Main fetch function:
 * 1. Attempts to fetch from public/protected Status Page (/api/status-page/:slug)
 * 2. If 404, falls back to Prometheus /metrics endpoint (supports Uptime Kuma API Keys!)
 */
function fetchAll(baseUrl, slug, authHeader, maxHistory, arg5, arg6, arg7) {
    var callback, errorCallback, preferredGroup;
    if (typeof arg5 === "function") {
        callback = arg5;
        errorCallback = arg6;
        preferredGroup = arg7 || "";
    } else {
        preferredGroup = arg5 || "";
        callback = arg6;
        errorCallback = arg7;
    }

    var parsed = parseUrlAndSlug(baseUrl, slug);
    if (!parsed.baseUrl) {
        if (errorCallback) errorCallback("Server URL is not configured.");
        return;
    }

    var authCandidates = getAuthHeaders(authHeader);
    var primaryAuth = authCandidates[0] || "";
    var slugCandidates = getSlugCandidates(parsed.slug);

    function tryStatusPage(index) {
        if (index >= slugCandidates.length) {
            // If all Status Page candidates failed (404, etc.), try /metrics fallback
            fetchFromMetricsWithCandidates(parsed.baseUrl, authCandidates, 0, maxHistory, callback, function(metricsErr) {
                if (errorCallback) {
                    errorCallback("Status page '" + parsed.slug + "' not found (HTTP 404).\nCheck status page slug in settings, or provide a valid API Key to scrape /metrics directly. (Metrics fallback: " + metricsErr + ")");
                }
            });
            return;
        }

        var candidateSlug = slugCandidates[index];
        var statusPageUrl = parsed.baseUrl + "/api/status-page/" + encodeURIComponent(candidateSlug);
        var heartbeatUrl = parsed.baseUrl + "/api/status-page/heartbeat/" + encodeURIComponent(candidateSlug);

        // Try status page candidate
        requestHttp(statusPageUrl, primaryAuth, "application/json", function(statusPageRaw) {
            var statusPageData;
            try {
                statusPageData = JSON.parse(statusPageRaw);
            } catch (e) {
                tryStatusPage(index + 1);
                return;
            }

            // Fetch heartbeats
            requestHttp(heartbeatUrl, primaryAuth, "application/json", function(heartbeatRaw) {
                var heartbeatData = { heartbeatList: {}, uptimeList: {} };
                try {
                    heartbeatData = JSON.parse(heartbeatRaw);
                } catch (e) {}

                try {
                    var processed = processApiData(statusPageData, heartbeatData, parsed.baseUrl, candidateSlug, maxHistory);

                    // If a specific group is requested, check if it exists in status page monitors
                    if (preferredGroup && preferredGroup.trim().length > 0 && preferredGroup.toLowerCase() !== "all" && authCandidates[0] && authCandidates[0].length > 0) {
                        var pTarget = preferredGroup.trim().toLowerCase();
                        var hasMatchingGroup = false;
                        for (var pm = 0; pm < processed.monitors.length; pm++) {
                            var pMon = processed.monitors[pm];
                            if ((pMon.groupName && pMon.groupName.toLowerCase() === pTarget) ||
                                (pMon.name && pMon.name.toLowerCase() === pTarget)) {
                                hasMatchingGroup = true;
                                break;
                            }
                        }
                        // If group is not in this status page, try next slug or /metrics
                        if (!hasMatchingGroup) {
                            if (index + 1 < slugCandidates.length) {
                                tryStatusPage(index + 1);
                                return;
                            } else {
                                fetchFromMetricsWithCandidates(parsed.baseUrl, authCandidates, 0, maxHistory, callback, function(mErr) {
                                    if (callback) callback(processed);
                                });
                                return;
                            }
                        }
                    }

                    if (callback) callback(processed);
                } catch (err) {
                    if (errorCallback) errorCallback("Error processing status data: " + err.message);
                }
            }, function(hbErr) {
                // Heartbeat failed, still display status page monitors
                try {
                    var processedFallback = processApiData(statusPageData, { heartbeatList: {}, uptimeList: {} }, parsed.baseUrl, candidateSlug, maxHistory);
                    if (callback) callback(processedFallback);
                } catch (err) {
                    if (errorCallback) errorCallback("Heartbeat error: " + hbErr);
                }
            });
        }, function(spError, statusCode) {
            // If candidate returned 404, try next candidate
            tryStatusPage(index + 1);
        });
    }

    tryStatusPage(0);
}

/**
 * Tries fetching /metrics with candidate authentication headers
 */
function fetchFromMetricsWithCandidates(baseUrl, candidates, index, maxHistory, callback, errorCallback) {
    if (index >= candidates.length) {
        errorCallback("All authentication methods failed for /metrics");
        return;
    }

    var auth = candidates[index];
    var metricsUrl = baseUrl + "/metrics";

    requestHttp(metricsUrl, auth, "text/plain", function(metricsText) {
        try {
            var processed = processPrometheusMetrics(metricsText, baseUrl, maxHistory);
            callback(processed);
        } catch (err) {
            errorCallback("Failed to parse metrics: " + err.message);
        }
    }, function(err, statusCode) {
        // Try next candidate
        if (index + 1 < candidates.length && (statusCode === 401 || statusCode === 403 || statusCode === 404)) {
            fetchFromMetricsWithCandidates(baseUrl, candidates, index + 1, maxHistory, callback, errorCallback);
        } else {
            errorCallback(err);
        }
    });
}

/**
 * Calculates aggregated statistics for a list of monitors.
 */
function computeGroupStats(monitors) {
    monitors = monitors || [];
    var total = monitors.length;
    var up = 0;
    var down = 0;
    var pending = 0;
    var maintenance = 0;
    var pingSum = 0;
    var pingCount = 0;
    var uptimeSum = 0;
    var uptimeCount = 0;

    for (var i = 0; i < monitors.length; i++) {
        var m = monitors[i];
        if (m.status === STATUS_UP) {
            up++;
            if (m.ping !== null && m.ping !== undefined) {
                pingSum += m.ping;
                pingCount++;
            }
        } else if (m.status === STATUS_DOWN) {
            down++;
        } else if (m.status === STATUS_PENDING) {
            pending++;
        } else if (m.status === STATUS_MAINTENANCE) {
            maintenance++;
        }

        if (m.uptime24h !== null && m.uptime24h !== undefined) {
            uptimeSum += m.uptime24h;
            uptimeCount++;
        }
    }

    var overallStatus = STATUS_UP;
    if (down > 0) {
        overallStatus = STATUS_DOWN;
    } else if (pending > 0) {
        overallStatus = STATUS_PENDING;
    } else if (maintenance > 0 && up === 0) {
        overallStatus = STATUS_MAINTENANCE;
    }

    return {
        total: total,
        up: up,
        down: down,
        pending: pending,
        maintenance: maintenance,
        hasDown: down > 0,
        averagePing: pingCount > 0 ? Math.round(pingSum / pingCount) : null,
        overallUptime: uptimeCount > 0 ? Math.round((uptimeSum / uptimeCount) * 100) / 100 : 100.0,
        overallStatus: overallStatus,
        overallStatusText: getOverallStatusText(overallStatus, down, pending, total)
    };
}

/**
 * Resolves the appropriate group for a monitor parsed from Prometheus metrics.
 * Prometheus /metrics from Uptime Kuma does not export monitor group hierarchies.
 * Only returns explicit monitor_group label if provided; otherwise returns empty string.
 */
function resolvePrometheusMonitorGroup(mon, knownGroups, groupMonitors) {
    if (mon && mon.explicitGroup && mon.explicitGroup.trim().length > 0) {
        return mon.explicitGroup.trim();
    }
    return "";
}

/**
 * Parses Prometheus /metrics text exposition format from Uptime Kuma
 */
function processPrometheusMetrics(rawMetrics, baseUrl, maxHistory) {
    maxHistory = maxHistory || 25;
    var monitors = {};
    var lines = rawMetrics.split("\n");

    // Pre-scan to discover explicit groups if provided via monitor_group label
    var knownGroups = [];
    for (var p = 0; p < lines.length; p++) {
        var pLine = lines[p].trim();
        if (pLine.indexOf("{") !== -1) {
            var pLabels = parsePrometheusLabels(pLine);
            if (pLabels.monitor_group) {
                var explicit = pLabels.monitor_group.trim();
                if (explicit && knownGroups.indexOf(explicit) === -1) {
                    knownGroups.push(explicit);
                }
            }
        }
    }

    var autoNumericId = 1;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line || line.startsWith("#")) continue;

        // Metric format: metric_name{label1="val1",...} value
        var match = line.match(/^([a-z_]+)\{([^}]+)\}\s+([0-9.eE+-]+)$/);
        if (!match) continue;

        var metricName = match[1];
        var metricVal = parseFloat(match[3]);

        var labels = parsePrometheusLabels(line);
        // Uptime Kuma v2 provides monitor_id; v1 provides monitor_name without monitor_id
        var idKey = labels.monitor_id || labels.monitor_name;
        if (!idKey) continue;

        var mType = (labels.monitor_type || "http").toUpperCase();
        var mName = labels.monitor_name || ("Monitor #" + idKey);
        var numericId = labels.monitor_id ? parseInt(labels.monitor_id) : autoNumericId++;

        // Skip synthetic aggregate group monitors
        if (mType === "GROUP") continue;

        if (!monitors[idKey]) {
            var mUrl = labels.monitor_url && labels.monitor_url !== "https://" && labels.monitor_url !== "http://" && labels.monitor_url !== "null" ? labels.monitor_url : "";
            var mHost = labels.monitor_hostname && labels.monitor_hostname !== "null" ? labels.monitor_hostname : "";
            var mPort = labels.monitor_port && labels.monitor_port !== "null" ? parseInt(labels.monitor_port) : null;

            monitors[idKey] = {
                id: numericId,
                name: mName,
                groupName: labels.monitor_group || "",
                explicitGroup: labels.monitor_group || "",
                type: mType,
                url: mUrl,
                hostname: mHost,
                port: mPort,
                status: STATUS_UP,
                ping: null,
                uptime24h: 100.0,
                certDays: null
            };
        }

        // Accumulate missing URL / hostname / group attributes across diverse metric entries
        if (labels.monitor_url && labels.monitor_url !== "https://" && labels.monitor_url !== "http://" && labels.monitor_url !== "null" && !monitors[idKey].url) {
            monitors[idKey].url = labels.monitor_url;
        }
        if (labels.monitor_hostname && labels.monitor_hostname !== "null" && !monitors[idKey].hostname) {
            monitors[idKey].hostname = labels.monitor_hostname;
        }
        if (labels.monitor_group && !monitors[idKey].explicitGroup) {
            monitors[idKey].explicitGroup = labels.monitor_group;
        }

        if (metricName === "monitor_status") {
            monitors[idKey].status = Math.round(metricVal);
        } else if (metricName === "monitor_response_time") {
            // Note: Uptime Kuma v1 sets response time to -1 if monitor is down or unmeasured
            var pVal = Math.round(metricVal);
            monitors[idKey].ping = pVal >= 0 ? pVal : null;
        } else if (metricName === "monitor_uptime_ratio" && labels.window === "1d") {
            monitors[idKey].uptime24h = Math.round(metricVal * 10000) / 100;
        } else if (metricName === "monitor_cert_days_remaining") {
            monitors[idKey].certDays = Math.round(metricVal);
        }
    }

    var allMonitors = [];
    var keys = Object.keys(monitors);
    for (var j = 0; j < keys.length; j++) {
        var mon = monitors[keys[j]];
        mon.groupName = resolvePrometheusMonitorGroup(mon, knownGroups);

        // Build tags
        var tags = [];
        if (mon.certDays !== null) {
            tags.push({
                name: "SSL " + mon.certDays + "d",
                color: mon.certDays < 14 ? "#e74c3c" : "#10b981"
            });
        }

        // Generate synthetic heartbeat history based on current status and 24h uptime
        var syntheticHbs = [];
        var failCount = mon.status === STATUS_DOWN ? 2 : (mon.uptime24h < 99.0 ? 1 : 0);
        for (var h = 0; h < maxHistory; h++) {
            var isDownBeat = (failCount > 0 && h >= maxHistory - failCount);
            syntheticHbs.push({
                status: isDownBeat ? STATUS_DOWN : (mon.status === STATUS_DOWN ? STATUS_DOWN : STATUS_UP),
                ping: isDownBeat ? null : mon.ping,
                time: "",
                msg: isDownBeat ? "Outage" : (mon.status === STATUS_UP ? "OK" : "")
            });
        }

        allMonitors.push({
            id: mon.id,
            name: mon.name,
            groupName: mon.groupName,
            type: mon.type,
            url: mon.url,
            hostname: mon.hostname,
            port: mon.port,
            status: mon.status,
            statusText: getStatusText(mon.status),
            statusColor: getStatusColor(mon.status),
            ping: mon.ping,
            uptime24h: mon.uptime24h,
            lastMsg: mon.status === STATUS_UP ? "200 - OK" : (mon.status === STATUS_DOWN ? "Service is DOWN" : ""),
            lastTime: new Date().toISOString(),
            tags: tags,
            heartbeats: syntheticHbs
        });
    }

    // Sort: failing services first, then by name
    allMonitors.sort(function(a, b) {
        if (a.status === STATUS_DOWN && b.status !== STATUS_DOWN) return -1;
        if (b.status === STATUS_DOWN && a.status !== STATUS_DOWN) return 1;
        return a.name.localeCompare(b.name);
    });

    var cleanHost = baseUrl.replace(/^https?:\/\//, "");

    // Groups are only constructed if explicit monitor_group labels exist in metrics
    var metricGroups = [];
    if (knownGroups.length > 0) {
        var groupBuckets = {};
        for (var mIdx = 0; mIdx < allMonitors.length; mIdx++) {
            var monItem = allMonitors[mIdx];
            var gName = monItem.groupName;
            if (gName) {
                if (!groupBuckets[gName]) groupBuckets[gName] = [];
                groupBuckets[gName].push(monItem);
            }
        }
        for (var gk = 0; gk < knownGroups.length; gk++) {
            var grpName = knownGroups[gk];
            var grpMons = groupBuckets[grpName];
            if (grpMons && grpMons.length > 0) {
                metricGroups.push({
                    id: gk + 1,
                    name: grpName,
                    monitors: grpMons,
                    stats: computeGroupStats(grpMons)
                });
            }
        }
    }

    var overallStats = computeGroupStats(allMonitors);

    return {
        title: cleanHost + " Monitors",
        description: "Uptime Kuma Metrics Overview",
        statusPageUrl: baseUrl,
        incidents: [],
        groups: metricGroups,
        monitors: allMonitors,
        stats: overallStats,
        lastUpdated: new Date()
    };
}

/**
 * Transforms raw Status Page API responses into UI model
 */
function processApiData(statusPageData, heartbeatData, baseUrl, slug, maxHistory) {
    maxHistory = maxHistory || 25;
    var config = statusPageData.config || {};
    var publicGroupList = statusPageData.publicGroupList || [];
    // Uptime Kuma v2 returns `incidents` (array), v1 returns `incident` (single object or null)
    var incidents = statusPageData.incidents;
    if (!Array.isArray(incidents)) {
        if (statusPageData.incident) {
            incidents = [statusPageData.incident];
        } else {
            incidents = [];
        }
    }
    var heartbeatList = (heartbeatData && heartbeatData.heartbeatList) ? heartbeatData.heartbeatList : {};
    var uptimeList = (heartbeatData && heartbeatData.uptimeList) ? heartbeatData.uptimeList : {};

    var allMonitors = [];
    var groups = [];
    var totalUp = 0;
    var totalDown = 0;
    var totalPending = 0;
    var totalMaintenance = 0;
    var pingSum = 0;
    var pingCount = 0;
    var uptimeSum = 0;
    var uptimeCount = 0;

    for (var g = 0; g < publicGroupList.length; g++) {
        var groupObj = publicGroupList[g];
        var groupMonitors = [];
        var mList = groupObj.monitorList || [];

        for (var m = 0; m < mList.length; m++) {
            var rawM = mList[m];
            var mId = rawM.id;
            var hbs = heartbeatList[mId] || heartbeatList[String(mId)] || [];

            var latestHb = hbs.length > 0 ? hbs[hbs.length - 1] : null;

            var status = STATUS_UP;
            if (rawM.status !== undefined && rawM.status !== null) {
                status = rawM.status;
            } else if (latestHb && latestHb.status !== undefined) {
                status = latestHb.status;
            }

            var ping = null;
            if (latestHb && latestHb.ping !== undefined && latestHb.ping !== null) {
                ping = Math.round(latestHb.ping);
                if (status === STATUS_UP) {
                    pingSum += ping;
                    pingCount++;
                }
            }

            var uptime24h = 100.0;
            var key24 = mId + "_24";
            if (uptimeList[key24] !== undefined) {
                uptime24h = Math.round(uptimeList[key24] * 10000) / 100;
            } else if (hbs.length > 0) {
                var upHbs = 0;
                for (var h = 0; h < hbs.length; h++) {
                    if (hbs[h].status === STATUS_UP) upHbs++;
                }
                uptime24h = Math.round((upHbs / hbs.length) * 10000) / 100;
            }

            uptimeSum += uptime24h;
            uptimeCount++;

            if (status === STATUS_UP) {
                totalUp++;
            } else if (status === STATUS_DOWN) {
                totalDown++;
            } else if (status === STATUS_PENDING) {
                totalPending++;
            } else if (status === STATUS_MAINTENANCE) {
                totalMaintenance++;
            }

            var historySlice = [];
            var startIdx = Math.max(0, hbs.length - maxHistory);
            for (var k = startIdx; k < hbs.length; k++) {
                var item = hbs[k];
                historySlice.push({
                    status: item.status,
                    ping: item.ping !== undefined && item.ping !== null ? Math.round(item.ping) : null,
                    time: item.time || "",
                    msg: item.msg || ""
                });
            }

            var monitorItem = {
                id: mId,
                name: rawM.name || ("Monitor #" + mId),
                groupName: groupObj.name || "Default",
                type: (rawM.type || "http").toUpperCase(),
                url: rawM.url || "",
                hostname: rawM.hostname || "",
                port: rawM.port || null,
                status: status,
                statusText: getStatusText(status),
                statusColor: getStatusColor(status),
                ping: ping,
                uptime24h: uptime24h,
                lastMsg: latestHb ? (latestHb.msg || "") : "",
                lastTime: latestHb ? (latestHb.time || "") : "",
                tags: rawM.tags || [],
                heartbeats: historySlice
            };

            groupMonitors.push(monitorItem);
            allMonitors.push(monitorItem);
        }

        groups.push({
            id: groupObj.id || g,
            name: groupObj.name || "Monitors",
            monitors: groupMonitors,
            stats: computeGroupStats(groupMonitors)
        });
    }

    var overallStats = computeGroupStats(allMonitors);

    return {
        title: config.title || "Uptime Kuma",
        description: config.description || "",
        statusPageUrl: baseUrl + "/status/" + slug,
        incidents: incidents,
        groups: groups,
        monitors: allMonitors,
        stats: overallStats,
        lastUpdated: new Date()
    };
}

function getStatusText(status) {
    switch (status) {
        case STATUS_UP: return "Up";
        case STATUS_DOWN: return "Down";
        case STATUS_PENDING: return "Pending";
        case STATUS_MAINTENANCE: return "Maintenance";
        default: return "Unknown";
    }
}

function getStatusColor(status) {
    switch (status) {
        case STATUS_UP: return "#2ecc71";
        case STATUS_DOWN: return "#e74c3c";
        case STATUS_PENDING: return "#f39c12";
        case STATUS_MAINTENANCE: return "#3498db";
        default: return "#95a5a6";
    }
}

function getStatusIcon(status) {
    switch (status) {
        case STATUS_UP: return "answer-correct";
        case STATUS_DOWN: return "dialog-error";
        case STATUS_PENDING: return "dialog-warning";
        case STATUS_MAINTENANCE: return "preferences-system";
        default: return "dialog-question";
    }
}

function getOverallStatusText(status, downCount, pendingCount, total) {
    if (total === 0) return "No Monitors Configured";
    if (downCount > 0) {
        return downCount === 1 ? "1 Service Disrupted" : downCount + " Services Down";
    }
    if (pendingCount > 0) {
        return "Degraded Performance";
    }
    return "All Systems Operational";
}

function formatPing(ping) {
    if (ping === null || ping === undefined) return "--";
    return ping + " ms";
}

function getPingColor(ping) {
    if (ping === null || ping === undefined) return "#95a5a6";
    if (ping < 100) return "#2ecc71";
    if (ping < 300) return "#f1c40f";
    return "#e67e22";
}

function formatTime(isoString) {
    if (!isoString) return "";
    try {
        var d = new Date(isoString);
        if (isNaN(d.getTime())) return isoString;
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    } catch (e) {
        return isoString;
    }
}

function getDemoData(maxHistory) {
    maxHistory = maxHistory || 25;

    function makeHbs(status, basePing, count, hasFailure) {
        var res = [];
        var now = Date.now();
        for (var i = 0; i < count; i++) {
            var isDown = hasFailure && (i === count - 3 || i === count - 4);
            var hbStatus = isDown ? STATUS_DOWN : status;
            var jitter = Math.floor(Math.random() * 10) - 5;
            res.push({
                status: hbStatus,
                ping: isDown ? null : Math.max(1, basePing + jitter),
                time: new Date(now - (count - i) * 60000).toISOString(),
                msg: isDown ? "504 Gateway Timeout" : "200 - OK"
            });
        }
        return res;
    }

    var monitors = [
        {
            id: 1,
            name: "Main Production Web App",
            groupName: "Public Infrastructure",
            type: "HTTP",
            url: "https://example.com",
            hostname: "example.com",
            port: 443,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 32,
            uptime24h: 99.98,
            lastMsg: "200 - OK",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Production", color: "#10b981" }, { name: "Web", color: "#3b82f6" }],
            heartbeats: makeHbs(STATUS_UP, 32, maxHistory, false)
        },
        {
            id: 2,
            name: "REST API Gateway",
            groupName: "Public Infrastructure",
            type: "HTTP",
            url: "https://api.example.com/health",
            hostname: "api.example.com",
            port: 443,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 18,
            uptime24h: 100.0,
            lastMsg: "200 - OK",
            lastTime: new Date().toISOString(),
            tags: [{ name: "API", color: "#8b5cf6" }],
            heartbeats: makeHbs(STATUS_UP, 18, maxHistory, false)
        },
        {
            id: 3,
            name: "Auth & Single Sign-On (SSO)",
            groupName: "Core Services",
            type: "HTTP",
            url: "https://auth.example.com",
            hostname: "auth.example.com",
            port: 443,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 45,
            uptime24h: 99.45,
            lastMsg: "200 - OK",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Security", color: "#f59e0b" }],
            heartbeats: makeHbs(STATUS_UP, 45, maxHistory, true)
        },
        {
            id: 4,
            name: "Primary Database (PostgreSQL)",
            groupName: "Core Services",
            type: "TCP",
            url: "",
            hostname: "db.internal.net",
            port: 5432,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 4,
            uptime24h: 100.0,
            lastMsg: "TCP Connection Succeeded",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Database", color: "#06b6d4" }],
            heartbeats: makeHbs(STATUS_UP, 4, maxHistory, false)
        },
        {
            id: 5,
            name: "Redis Cache Cluster",
            groupName: "Core Services",
            type: "TCP",
            url: "",
            hostname: "redis.internal.net",
            port: 6379,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 2,
            uptime24h: 100.0,
            lastMsg: "TCP Connection Succeeded",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Cache", color: "#ec4899" }],
            heartbeats: makeHbs(STATUS_UP, 2, maxHistory, false)
        },
        {
            id: 6,
            name: "Mail Delivery Worker",
            groupName: "Background Services",
            type: "PORT",
            url: "",
            hostname: "smtp.example.com",
            port: 587,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 15,
            uptime24h: 100.0,
            lastMsg: "Port is open",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Worker", color: "#64748b" }],
            heartbeats: makeHbs(STATUS_UP, 15, maxHistory, false)
        },
        {
            id: 7,
            name: "Internal DNS Resolver",
            groupName: "Background Services",
            type: "DNS",
            url: "",
            hostname: "1.1.1.1",
            port: 53,
            status: STATUS_UP,
            statusText: "Up",
            statusColor: "#2ecc71",
            ping: 11,
            uptime24h: 100.0,
            lastMsg: "DNS Query resolved successfully",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Network", color: "#3b82f6" }],
            heartbeats: makeHbs(STATUS_UP, 11, maxHistory, false)
        },
        {
            id: 8,
            name: "Legacy Reporting API",
            groupName: "Background Services",
            type: "HTTP",
            url: "https://reports.legacy.internal/status",
            hostname: "reports.legacy.internal",
            port: 443,
            status: STATUS_DOWN,
            statusText: "Down",
            statusColor: "#e74c3c",
            ping: null,
            uptime24h: 91.2,
            lastMsg: "Connection refused: connect ECONNREFUSED",
            lastTime: new Date().toISOString(),
            tags: [{ name: "Legacy", color: "#94a3b8" }],
            heartbeats: makeHbs(STATUS_DOWN, 200, maxHistory, false)
        }
    ];

    var groups = [
        { id: 1, name: "Public Infrastructure", monitors: [monitors[0], monitors[1]], stats: computeGroupStats([monitors[0], monitors[1]]) },
        { id: 2, name: "Core Services", monitors: [monitors[2], monitors[3], monitors[4]], stats: computeGroupStats([monitors[2], monitors[3], monitors[4]]) },
        { id: 3, name: "Background Services", monitors: [monitors[5], monitors[6], monitors[7]], stats: computeGroupStats([monitors[5], monitors[6], monitors[7]]) }
    ];

    var overallStats = computeGroupStats(monitors);

    return {
        title: "Kuma Cloud Status",
        description: "Official real-time systems status overview",
        statusPageUrl: "https://status.example.com",
        incidents: [
            {
                id: 101,
                title: "Investigating Legacy Reporting Latency",
                content: "Engineers are currently troubleshooting connection errors on the legacy reporting service.",
                style: "warning",
                createdDate: new Date().toISOString()
            }
        ],
        groups: groups,
        monitors: monitors,
        stats: overallStats,
        lastUpdated: new Date()
    };
}

/**
 * Extracts a list of unique group names available from statusData
 */
function extractGroups(statusData) {
    if (!statusData) return [];
    var set = {};
    if (statusData.groups && Array.isArray(statusData.groups)) {
        for (var i = 0; i < statusData.groups.length; i++) {
            var g = statusData.groups[i];
            if (g && g.name && g.name.trim().length > 0 && g.name.trim().toLowerCase() !== "default") {
                set[g.name.trim()] = true;
            }
        }
    }
    if (statusData.monitors && Array.isArray(statusData.monitors)) {
        for (var j = 0; j < statusData.monitors.length; j++) {
            var m = statusData.monitors[j];
            if (m.groupName && m.groupName.trim().length > 0 && m.groupName.trim().toLowerCase() !== "default") {
                set[m.groupName.trim()] = true;
            }
        }
    }
    var keys = Object.keys(set);
    keys.sort();
    return keys;
}

/**
 * Normalizes a group filter argument into an array of trimmed group names.
 */
function parseGroupFilter(groupFilter) {
    if (!groupFilter) return [];
    if (Array.isArray(groupFilter)) {
        return groupFilter.map(function(s) { return String(s).trim(); }).filter(function(s) { return s.length > 0; });
    }
    if (typeof groupFilter === "string") {
        var str = groupFilter.trim();
        if (str.length === 0 || str.toLowerCase() === "all") return [];
        var parts = str.indexOf("|") !== -1 ? str.split("|") : [str];
        return parts.map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
    }
    return [];
}

/**
 * Slices statusData to only include monitors and statistics for specified group(s).
 * Supports pipe-separated names ("Group A|Group B"), array, or single group string.
 */
function filterByGroup(statusData, groupFilter) {
    if (!statusData) return null;
    var targetGroups = parseGroupFilter(groupFilter);
    if (targetGroups.length === 0) {
        return statusData;
    }

    var targetLowers = targetGroups.map(function(s) { return s.toLowerCase(); });
    var allMonitors = statusData.monitors || [];
    var matchedMonitors = [];
    var seenMonitorIds = {};

    function matchesAnyTarget(gName, mType, mName) {
        var gn = (gName || "").trim().toLowerCase();
        var isGroupType = (mType || "").toLowerCase() === "group";
        var mn = (mName || "").trim().toLowerCase();
        for (var t = 0; t < targetLowers.length; t++) {
            var target = targetLowers[t];
            if (gn === target) return true;
            if (isGroupType && mn === target) return true;
        }
        return false;
    }

    for (var i = 0; i < allMonitors.length; i++) {
        var mon = allMonitors[i];
        if (matchesAnyTarget(mon.groupName, mon.type, mon.name)) {
            if (!seenMonitorIds[mon.id]) {
                seenMonitorIds[mon.id] = true;
                matchedMonitors.push(mon);
            }
        }
    }

    var filteredGroups = [];
    if (statusData.groups && Array.isArray(statusData.groups)) {
        for (var g = 0; g < statusData.groups.length; g++) {
            var grp = statusData.groups[g];
            var gNameLower = (grp.name || "").trim().toLowerCase();
            var isTargetGroup = false;
            for (var tg = 0; tg < targetLowers.length; tg++) {
                if (gNameLower === targetLowers[tg]) {
                    isTargetGroup = true;
                    break;
                }
            }
            if (isTargetGroup) {
                var grpMonitors = (grp.monitors || []).filter(function(m) {
                    return seenMonitorIds[m.id];
                });
                filteredGroups.push({
                    id: grp.id || (filteredGroups.length + 1),
                    name: grp.name,
                    monitors: grpMonitors,
                    stats: computeGroupStats(grpMonitors)
                });
            }
        }
    }

    // Fallback if groups were not pre-structured in statusData
    if (filteredGroups.length === 0 && matchedMonitors.length > 0) {
        var groupBuckets = {};
        for (var mIdx = 0; mIdx < matchedMonitors.length; mIdx++) {
            var mItem = matchedMonitors[mIdx];
            var bucketName = mItem.groupName || "Default";
            if (!groupBuckets[bucketName]) groupBuckets[bucketName] = [];
            groupBuckets[bucketName].push(mItem);
        }
        var bKeys = Object.keys(groupBuckets).sort();
        for (var bk = 0; bk < bKeys.length; bk++) {
            var bMons = groupBuckets[bKeys[bk]];
            filteredGroups.push({
                id: bk + 1,
                name: bKeys[bk],
                monitors: bMons,
                stats: computeGroupStats(bMons)
            });
        }
    }

    var overallStats = computeGroupStats(matchedMonitors);
    var baseTitle = statusData.title || "Uptime Kuma";
    var filterLabel = targetGroups.length === 1 ? targetGroups[0] : (targetGroups.length + " Groups");
    var groupTitle = baseTitle.indexOf(filterLabel) !== -1 ? baseTitle : (baseTitle + " (" + filterLabel + ")");

    return {
        title: groupTitle,
        groupFilter: targetGroups.join("|"),
        description: statusData.description,
        statusPageUrl: statusData.statusPageUrl,
        incidents: statusData.incidents || [],
        groups: filteredGroups,
        monitors: matchedMonitors,
        stats: overallStats,
        lastUpdated: statusData.lastUpdated || new Date()
    };
}

/**
 * Parses Prometheus label string into an object:
 * e.g. monitor_status{monitor_id="1",monitor_name="muench.lan Apps",monitor_type="group"} 1
 */
function parsePrometheusLabels(line) {
    var labels = {};
    if (!line) return labels;
    var openBrace = line.indexOf("{");
    var closeBrace = line.lastIndexOf("}");
    if (openBrace === -1 || closeBrace === -1 || closeBrace <= openBrace) {
        return labels;
    }
    var labelsStr = line.substring(openBrace + 1, closeBrace);
    var labelRegex = /([a-zA-Z0-9_]+)="([^"]*)"/g;
    var m;
    while ((m = labelRegex.exec(labelsStr)) !== null) {
        labels[m[1]] = m[2];
    }
    return labels;
}

/**
 * Lightweight fetch to retrieve available groups from Status Page API or /metrics
 */
function fetchGroupsOnly(baseUrl, slug, authHeader, callback, errorCallback) {
    var parsed = parseUrlAndSlug(baseUrl, slug);
    if (!parsed.baseUrl) {
        if (errorCallback) errorCallback("Server URL is not configured.");
        return;
    }

    var authCandidates = getAuthHeaders(authHeader);
    var primaryAuth = authCandidates[0] || "";
    var slugCandidates = getSlugCandidates(parsed.slug);
    // "default" is the implicit dashboard, so retain the /metrics fallback when it has no status page.
    var hasStatusPageSlug = slug && slug.trim().length > 0 && slug.trim().toLowerCase() !== "default";

    function tryStatusPageGroup(index) {
        if (index >= slugCandidates.length) {
            if (hasStatusPageSlug) {
                if (errorCallback) errorCallback("Status page not found for '" + parsed.slug + "'.");
                return;
            }
            // Fallback to /metrics
            fetchGroupsFromMetrics(parsed.baseUrl, authCandidates, 0, function(groups) {
                if (callback) callback(groups);
            }, function(metricsErr) {
                if (errorCallback) errorCallback("Status page not found for '" + parsed.slug + "'. (Metrics fallback: " + metricsErr + ")");
            });
            return;
        }

        var candidateSlug = slugCandidates[index];
        var statusPageUrl = parsed.baseUrl + "/api/status-page/" + encodeURIComponent(candidateSlug);

        requestHttp(statusPageUrl, primaryAuth, "application/json", function(statusPageRaw) {
            var statusPageData;
            try {
                statusPageData = JSON.parse(statusPageRaw);
            } catch (e) {
                tryStatusPageGroup(index + 1);
                return;
            }

            var groupSet = {};
            var publicGroupList = statusPageData.publicGroupList || [];
            for (var g = 0; g < publicGroupList.length; g++) {
                var grp = publicGroupList[g];
                if (grp.name && grp.name.trim().length > 0) {
                    groupSet[grp.name.trim()] = true;
                }
            }

            var result = Object.keys(groupSet).sort();
            if (callback) callback(result);
        }, function(spError, statusCode) {
            tryStatusPageGroup(index + 1);
        });
    }

    tryStatusPageGroup(0);
}

function fetchGroupsFromMetrics(baseUrl, candidates, index, callback, errorCallback) {
    if (index >= candidates.length) {
        if (errorCallback) errorCallback("All authentication methods failed for /metrics");
        return;
    }

    var auth = candidates[index];
    var metricsUrl = baseUrl + "/metrics";

    requestHttp(metricsUrl, auth, "text/plain", function(metricsText) {
        try {
            var groupSet = {};
            var lines = metricsText.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.startsWith("monitor_status{") || line.startsWith("monitor_response_time{") || line.startsWith("monitor_cert_")) {
                    var labels = parsePrometheusLabels(line);
                    if (labels.monitor_group && labels.monitor_group.trim().length > 0) {
                        groupSet[labels.monitor_group.trim()] = true;
                    }
                }
            }
            var result = Object.keys(groupSet).sort();
            if (callback) callback(result);
        } catch (e) {
            if (errorCallback) errorCallback("Error parsing metrics: " + e.message);
        }
    }, function(err, statusCode) {
        if (index + 1 < candidates.length && (statusCode === 401 || statusCode === 403 || statusCode === 404)) {
            fetchGroupsFromMetrics(baseUrl, candidates, index + 1, callback, errorCallback);
        } else {
            if (errorCallback) errorCallback(err);
        }
    });
}
