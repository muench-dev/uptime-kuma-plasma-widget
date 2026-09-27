import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/uptimeKumaService.js" as KumaService

PlasmaExtras.Representation {
    id: fullRep

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24
    Layout.maximumWidth: Kirigami.Units.gridUnit * 38
    Layout.maximumHeight: Kirigami.Units.gridUnit * 36

    property string searchQuery: ""
    property string activeFilter: "all"
    readonly property bool isGroupedMode: Plasmoid.configuration.desktopMode === "grouped"

    property var collapsedGroups: ({})

    function isGroupCollapsed(groupName) {
        if (Object.prototype.hasOwnProperty.call(collapsedGroups, groupName)) {
            return collapsedGroups[groupName];
        }
        return Plasmoid.configuration.groupsCollapsedByDefault;
    }

    function toggleGroupCollapsed(groupName) {
        var copy = Object.assign({}, collapsedGroups);
        copy[groupName] = !copy[groupName];
        collapsedGroups = copy;
    }

    readonly property var statusData: {
        var base = root.statusData;
        var filter = Plasmoid.configuration.selectedGroup || "";
        if (!base) return null;
        if (!filter || filter.trim().length === 0 || filter === "all") return base;
        if (base.groupFilter === filter) return base;
        return KumaService.filterByGroup(base, filter);
    }
    readonly property var stats: statusData ? statusData.stats : null

    readonly property var filteredMonitors: {
        if (!statusData || !statusData.monitors) return [];
        var list = statusData.monitors;
        var q = searchQuery.trim().toLowerCase();
        var f = activeFilter;

        return list.filter(function(m) {
            if (f === "issues") {
                if (m.status !== KumaService.STATUS_DOWN && m.status !== KumaService.STATUS_PENDING) return false;
            } else if (f === "up") {
                if (m.status !== KumaService.STATUS_UP) return false;
            }

            if (q.length > 0) {
                var nameMatch = m.name && m.name.toLowerCase().indexOf(q) !== -1;
                var groupMatch = m.groupName && m.groupName.toLowerCase().indexOf(q) !== -1;
                var hostMatch = m.hostname && m.hostname.toLowerCase().indexOf(q) !== -1;
                var typeMatch = m.type && m.type.toLowerCase().indexOf(q) !== -1;
                return nameMatch || groupMatch || hostMatch || typeMatch;
            }

            return true;
        });
    }

    readonly property var filteredGroups: {
        if (!statusData || !statusData.groups) return [];
        var rawGroups = statusData.groups;
        var q = searchQuery.trim().toLowerCase();
        var f = activeFilter;
        var result = [];

        for (var i = 0; i < rawGroups.length; i++) {
            var grp = rawGroups[i];
            var monitors = grp.monitors || [];

            var matchedMons = monitors.filter(function(m) {
                if (f === "issues") {
                    if (m.status !== KumaService.STATUS_DOWN && m.status !== KumaService.STATUS_PENDING) return false;
                } else if (f === "up") {
                    if (m.status !== KumaService.STATUS_UP) return false;
                }

                if (q.length > 0) {
                    var nameMatch = m.name && m.name.toLowerCase().indexOf(q) !== -1;
                    var groupMatch = m.groupName && m.groupName.toLowerCase().indexOf(q) !== -1;
                    var hostMatch = m.hostname && m.hostname.toLowerCase().indexOf(q) !== -1;
                    var typeMatch = m.type && m.type.toLowerCase().indexOf(q) !== -1;
                    return nameMatch || groupMatch || hostMatch || typeMatch;
                }

                return true;
            });

            var groupMatchesQuery = q.length > 0 && grp.name && grp.name.toLowerCase().indexOf(q) !== -1;
            if (groupMatchesQuery && matchedMons.length === 0 && f === "all") {
                matchedMons = monitors;
            }

            if (matchedMons.length > 0) {
                var groupStats = (matchedMons.length === monitors.length && grp.stats) 
                    ? grp.stats 
                    : KumaService.computeGroupStats(matchedMons);

                result.push({
                    id: grp.id || (i + 1),
                    name: grp.name || "Default",
                    monitors: matchedMons,
                    stats: groupStats
                });
            }
        }
        return result;
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentHeight: headerRow.implicitHeight
        position: PlasmaComponents.ToolBar.Header

        RowLayout {
            id: headerRow
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Image {
                width: 20
                height: 20
                source: Qt.resolvedUrl("../images/uptime-kuma.svg")
                sourceSize.width: 20
                sourceSize.height: 20
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaExtras.Heading {
                level: 3
                text: statusData ? statusData.title : "Uptime Kuma"
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 8
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaExtras.SearchField {
                id: searchInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                placeholderText: "Filter monitors..."
                onTextChanged: {
                    fullRep.searchQuery = text;
                }
            }

            PlasmaComponents.ToolButton {
                id: refreshBtn
                icon.name: "view-refresh"
                display: PlasmaComponents.ToolButton.IconOnly
                text: "Refresh"
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolTip.text: "Refresh Status"
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered

                onClicked: {
                    root.fetchData();
                }

                NumberAnimation on rotation {
                    running: root.isLoading
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: "internet-web-browser"
                display: PlasmaComponents.ToolButton.IconOnly
                text: "Open Status Page"
                visible: statusData && statusData.statusPageUrl !== ""
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolTip.text: "Open Status Page in Browser"
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered

                onClicked: {
                    if (statusData && statusData.statusPageUrl) {
                        Qt.openUrlExternally(statusData.statusPageUrl);
                    }
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: fullRep.isGroupedMode ? "view-list-details" : "view-group-symbolic"
                display: PlasmaComponents.ToolButton.IconOnly
                text: fullRep.isGroupedMode ? "Switch to Flat View" : "Switch to Grouped View"
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolTip.text: fullRep.isGroupedMode ? "Switch to Flat View" : "Switch to Grouped View"
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered

                onClicked: {
                    Plasmoid.configuration.desktopMode = fullRep.isGroupedMode ? "full" : "grouped";
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: "configure-symbolic"
                display: PlasmaComponents.ToolButton.IconOnly
                text: "Configure"
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolTip.text: "Configure Widget"
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered

                onClicked: {
                    Plasmoid.internalAction("configure").trigger();
                }
            }

            PlasmaComponents.ToolButton {
                id: pinBtn
                icon.name: "window-pin-symbolic"
                display: PlasmaComponents.ToolButton.IconOnly
                text: "Keep Open"
                checkable: true
                checked: Plasmoid.configuration.pinned
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolTip.text: checked ? "Keep open (Pinned)" : "Pin popup open"
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered

                onToggled: {
                    Plasmoid.configuration.pinned = checked;
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        // 1. Unconfigured Welcome Screen
        ColumnLayout {
            anchors.centerIn: parent
            visible: !statusData && !root.isLoading && !root.hasError
            spacing: Kirigami.Units.gridUnit
            width: Math.min(parent.width - 40, 360)

            Image {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                source: Qt.resolvedUrl("../images/uptime-kuma.svg")
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
            }

            PlasmaExtras.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 2
                text: "Uptime Kuma"
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.8
                text: "Connect to your Uptime Kuma server to monitor real-time server status, latency, and uptime directly in Plasma."
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    icon.name: "configure"
                    text: "Configure Server"
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }

                PlasmaComponents.Button {
                    icon.name: "preview"
                    text: "Preview Demo"
                    onClicked: root.loadDemoData()
                }
            }
        }

        // 2. Error Message Screen
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.hasError && !statusData
            spacing: Kirigami.Units.gridUnit
            width: Math.min(parent.width - 40, 340)

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                width: 48
                height: 48
                source: "dialog-warning"
                color: "#e74c3c"
            }

            PlasmaExtras.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 3
                text: "Connection Failed"
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: "#e74c3c"
                text: root.errorMessage
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    icon.name: "view-refresh"
                    text: "Retry"
                    onClicked: root.fetchData()
                }

                PlasmaComponents.Button {
                    icon.name: "configure"
                    text: "Settings"
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }
            }
        }

        // 3. Busy Indicator
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.isLoading && !statusData
            spacing: Kirigami.Units.gridUnit

            PlasmaComponents.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Connecting to Uptime Kuma..."
                opacity: 0.7
            }
        }

        // 4. Populated Dashboard View
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            visible: statusData !== null
            spacing: Kirigami.Units.smallSpacing

            StatusHeader {
                Layout.fillWidth: true
                stats: fullRep.stats
                statusTitle: statusData ? statusData.title : ""
                lastUpdated: root.lastUpdated
            }

            IncidentBanner {
                Layout.fillWidth: true
                incident: (statusData && statusData.incidents && statusData.incidents.length > 0) ? statusData.incidents[0] : null
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                PlasmaComponents.Button {
                    text: "All (" + (stats ? stats.total : 0) + ")"
                    checkable: true
                    checked: fullRep.activeFilter === "all"
                    onClicked: fullRep.activeFilter = "all"
                }

                PlasmaComponents.Button {
                    text: "Issues (" + ((stats ? stats.down : 0) + (stats ? stats.pending : 0)) + ")"
                    checkable: true
                    checked: fullRep.activeFilter === "issues"
                    highlighted: stats && (stats.down > 0 || stats.pending > 0)
                    onClicked: fullRep.activeFilter = "issues"
                }

                PlasmaComponents.Button {
                    text: "Up (" + (stats ? stats.up : 0) + ")"
                    checkable: true
                    checked: fullRep.activeFilter === "up"
                    onClicked: fullRep.activeFilter = "up"
                }

                Item { Layout.fillWidth: true }

                QQC2.Label {
                    visible: root.isLoading
                    text: "Updating..."
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.6
                }
            }

            // Flat monitor list (visible in full mode)
            ListView {
                id: monitorList
                visible: !fullRep.isGroupedMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing

                model: fullRep.filteredMonitors

                delegate: MonitorItem {
                    required property var modelData
                    width: monitorList.width
                    monitor: modelData
                    showLatency: Plasmoid.configuration.showLatency
                    showUptimePercent: Plasmoid.configuration.showUptimePercent
                    showHeartbeats: Plasmoid.configuration.showHeartbeats !== false
                    showTags: Plasmoid.configuration.showTags
                    heartbeatCount: Plasmoid.configuration.heartbeatCount
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: monitorList.count === 0 && fullRep.searchQuery !== ""
                    iconName: "edit-find"
                    text: "No monitors found"
                    explanation: "No services matched '" + fullRep.searchQuery + "'"
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    policy: monitorList.contentHeight > monitorList.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
                }
            }

            // Grouped section cards list (visible in grouped mode)
            ListView {
                id: groupSectionList
                visible: fullRep.isGroupedMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing

                model: fullRep.filteredGroups

                delegate: Rectangle {
                    id: groupCard
                    required property var modelData
                    required property int index
                    width: groupSectionList.width
                    implicitHeight: groupCardLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.65)
                    border.color: (modelData.stats && modelData.stats.down > 0) 
                        ? Qt.rgba(0.92, 0.25, 0.25, 0.7) 
                        : Kirigami.Theme.separatorColor
                    border.width: 1

                    ColumnLayout {
                        id: groupCardLayout
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // Clickable group header row
                        MouseArea {
                            id: groupHeaderArea
                            Layout.fillWidth: true
                            implicitHeight: groupHeaderRow.implicitHeight + Kirigami.Units.smallSpacing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                fullRep.toggleGroupCollapsed(modelData.name);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Kirigami.Units.cornerRadius
                                color: groupHeaderArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            }

                            RowLayout {
                                id: groupHeaderRow
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    width: Kirigami.Units.iconSizes.small
                                    height: Kirigami.Units.iconSizes.small
                                    source: fullRep.isGroupCollapsed(modelData.name) ? "arrow-right" : "arrow-down"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Kirigami.Icon {
                                    width: Kirigami.Units.iconSizes.small
                                    height: Kirigami.Units.iconSizes.small
                                    source: "network-server-symbolic"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                PlasmaExtras.Heading {
                                    level: 4
                                    text: modelData.name
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Ping badge (if enabled)
                                Rectangle {
                                    visible: Plasmoid.configuration.showLatency && modelData.stats && modelData.stats.averagePing !== null
                                    implicitWidth: grpPingText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Qt.rgba(0.2, 0.6, 1.0, 0.15)
                                    Layout.alignment: Qt.AlignVCenter

                                    QQC2.Label {
                                        id: grpPingText
                                        anchors.centerIn: parent
                                        text: (modelData.stats && modelData.stats.averagePing !== null) ? (modelData.stats.averagePing + " ms") : ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.bold: true
                                        color: (modelData.stats && modelData.stats.averagePing !== null) ? KumaService.getPingColor(modelData.stats.averagePing) : Kirigami.Theme.textColor
                                    }
                                }

                                // 24h Uptime badge (if enabled)
                                Rectangle {
                                    visible: Plasmoid.configuration.showUptimePercent && modelData.stats && modelData.stats.overallUptime !== undefined
                                    implicitWidth: grpUptimeText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                    Layout.alignment: Qt.AlignVCenter

                                    QQC2.Label {
                                        id: grpUptimeText
                                        anchors.centerIn: parent
                                        text: (modelData.stats && modelData.stats.overallUptime !== undefined) ? (modelData.stats.overallUptime.toFixed(1) + "%") : ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.85
                                    }
                                }

                                // Health Status Pill
                                Rectangle {
                                    implicitWidth: grpStatusText.implicitWidth + 14
                                    implicitHeight: 22
                                    radius: 11
                                    color: {
                                        if (!modelData.stats) return "#2ecc71";
                                        if (modelData.stats.down > 0) return "#e74c3c";
                                        if (modelData.stats.pending > 0) return "#f39c12";
                                        return "#2ecc71";
                                    }
                                    Layout.alignment: Qt.AlignVCenter

                                    QQC2.Label {
                                        id: grpStatusText
                                        anchors.centerIn: parent
                                        text: {
                                            if (!modelData.stats) return "";
                                            if (modelData.stats.down > 0) return modelData.stats.down + " Down";
                                            if (modelData.stats.pending > 0) return modelData.stats.pending + " Pending";
                                            return modelData.stats.up + "/" + modelData.stats.total + " Up";
                                        }
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    }
                                }
                            }
                        }

                        // Collapsible monitors list
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: !fullRep.isGroupCollapsed(modelData.name)
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: modelData.monitors
                                delegate: MonitorItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    monitor: modelData
                                    showLatency: Plasmoid.configuration.showLatency
                                    showUptimePercent: Plasmoid.configuration.showUptimePercent
                                    showHeartbeats: Plasmoid.configuration.showHeartbeats !== false
                                    showTags: Plasmoid.configuration.showTags
                                    heartbeatCount: Plasmoid.configuration.heartbeatCount
                                }
                            }
                        }
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: groupSectionList.count === 0 && (fullRep.searchQuery !== "" || fullRep.activeFilter !== "all")
                    iconName: "edit-find"
                    text: "No monitors found"
                    explanation: "No groups or services matched the current filter."
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    policy: groupSectionList.contentHeight > groupSectionList.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
                }
            }
        }
    }
}
