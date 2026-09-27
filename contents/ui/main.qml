import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import "../code/uptimeKumaService.js" as KumaService

PlasmoidItem {
    id: root

    property string activeGroup: Plasmoid.configuration.selectedGroup || ""
    property var rawStatusData: null
    property var statusData: null

    function updateFilteredStatus() {
        if (!rawStatusData) {
            root.statusData = null;
            return;
        }
        var selected = root.activeGroup || Plasmoid.configuration.selectedGroup || "";
        if (!selected || selected.trim().length === 0 || selected === "all") {
            root.statusData = root.rawStatusData;
        } else {
            root.statusData = KumaService.filterByGroup(root.rawStatusData, selected);
        }
    }

    onActiveGroupChanged: {
        updateFilteredStatus();
    }
    property bool isLoading: false
    property bool hasError: false
    property string errorMessage: ""
    property var lastUpdated: null

    property var previousStatusMap: ({})
    property bool initialCheckDone: false

    preferredRepresentation: {
        if (Plasmoid.formFactor === PlasmaCore.Types.Planar) {
            return (Plasmoid.configuration.desktopMode === "compact") ? compactRepresentation : fullRepresentation;
        }
        return compactRepresentation;
    }
    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    hideOnWindowDeactivate: !Plasmoid.configuration.pinned
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    toolTipMainText: (statusData && statusData.title) ? statusData.title : Plasmoid.title
    toolTipSubText: {
        if (!statusData) {
            return hasError ? ("Error: " + errorMessage) : "Click to configure or view status";
        }
        var stats = statusData.stats;
        var lines = [];
        lines.push(stats.overallStatusText);
        lines.push("Monitors: " + stats.up + " Up, " + stats.down + " Down");
        if (stats.averagePing !== null) {
            lines.push("Avg Ping: " + stats.averagePing + " ms • 24h Uptime: " + stats.overallUptime.toFixed(1) + "%");
        }
        if (lastUpdated) {
            lines.push("Updated: " + KumaService.formatTime(lastUpdated));
        }
        return lines.join("\n");
    }

    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
    }

    function sendDesktopNotification(title, message, iconName) {
        if (!Plasmoid.configuration.notifyOnStatusChange) return;

        var cleanTitle = title.replace(/'/g, "'\\''");
        var cleanMsg = message.replace(/'/g, "'\\''");
        var icon = iconName || "network-server";

        var cmd = "notify-send -a 'Uptime Kuma' -i '" + icon + "' '" + cleanTitle + "' '" + cleanMsg + "'";
        execSource.connectSource(cmd);
    }

    Timer {
        id: refreshTimer
        interval: Math.max(10, Plasmoid.configuration.updateInterval) * 1000
        running: true
        repeat: true
        onTriggered: {
            root.fetchData();
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onServerUrlChanged() {
            root.fetchData();
        }
        function onSlugChanged() {
            root.fetchData();
        }
        function onAuthHeaderChanged() {
            root.fetchData();
        }
        function onSelectedGroupChanged() {
            root.activeGroup = Plasmoid.configuration.selectedGroup || "";
            root.updateFilteredStatus();
            if (root.statusData && root.statusData.monitors && root.statusData.monitors.length === 0 && Plasmoid.configuration.authHeader) {
                root.fetchData();
            }
        }
        function onValueChanged(key, value) {
            if (key === "selectedGroup") {
                root.activeGroup = value || "";
                root.updateFilteredStatus();
                if (root.statusData && root.statusData.monitors && root.statusData.monitors.length === 0 && Plasmoid.configuration.authHeader) {
                    root.fetchData();
                }
            }
        }
        function onUpdateIntervalChanged() {
            refreshTimer.restart();
        }
    }

    function fetchData() {
        var serverUrl = Plasmoid.configuration.serverUrl;
        var slug = Plasmoid.configuration.slug || "default";
        var authHeader = Plasmoid.configuration.authHeader;
        var maxHistory = Plasmoid.configuration.heartbeatCount || 25;

        if (!serverUrl || serverUrl.trim().length === 0) {
            root.isLoading = false;
            return;
        }

        root.isLoading = true;
        root.hasError = false;
        root.errorMessage = "";

        KumaService.fetchAll(serverUrl, slug, authHeader, maxHistory, function(data) {
            root.isLoading = false;
            root.hasError = false;
            root.errorMessage = "";
            root.lastUpdated = new Date();

            if (root.initialCheckDone && Plasmoid.configuration.notifyOnStatusChange && data.monitors) {
                for (var i = 0; i < data.monitors.length; i++) {
                    var m = data.monitors[i];
                    var prevStatus = root.previousStatusMap[m.id];

                    if (prevStatus !== undefined) {
                        if (prevStatus === KumaService.STATUS_UP && m.status === KumaService.STATUS_DOWN) {
                            var errMsg = m.lastMsg ? ("\nReason: " + m.lastMsg) : "";
                            root.sendDesktopNotification(
                                "Service Down: " + m.name,
                                "Outage detected on " + m.name + " (" + m.type + ")!" + errMsg,
                                "dialog-error"
                            );
                        } else if (prevStatus === KumaService.STATUS_DOWN && m.status === KumaService.STATUS_UP) {
                            var pingInfo = m.ping !== null ? (" (Ping: " + m.ping + " ms)") : "";
                            root.sendDesktopNotification(
                                "Service Restored: " + m.name,
                                m.name + " is back UP and operational" + pingInfo + ".",
                                "answer-correct"
                            );
                        }
                    }
                }
            }

            var newMap = {};
            if (data.monitors) {
                for (var j = 0; j < data.monitors.length; j++) {
                    newMap[data.monitors[j].id] = data.monitors[j].status;
                }
            }
            root.previousStatusMap = newMap;
            root.initialCheckDone = true;

            var discoveredGroups = KumaService.extractGroups(data);
            if (discoveredGroups && discoveredGroups.length > 0) {
                Plasmoid.configuration.availableGroups = discoveredGroups.join("|");
            }

            root.rawStatusData = data;
            root.updateFilteredStatus();

        }, function(errorMsg) {
            root.isLoading = false;
            root.hasError = true;
            root.errorMessage = errorMsg;
        });
    }

    function loadDemoData() {
        var demo = KumaService.getDemoData(Plasmoid.configuration.heartbeatCount || 25);
        var demoGroups = KumaService.extractGroups(demo);
        if (demoGroups && demoGroups.length > 0) {
            Plasmoid.configuration.availableGroups = demoGroups.join("|");
        }
        root.rawStatusData = demo;
        root.updateFilteredStatus();
        root.lastUpdated = new Date();
        root.hasError = false;
        root.errorMessage = "";
    }

    Component.onCompleted: {
        root.activeGroup = Plasmoid.configuration.selectedGroup || "";
        if (Plasmoid.configuration.serverUrl && Plasmoid.configuration.serverUrl.trim().length > 0) {
            fetchData();
        }
    }
}
