import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../../code/uptimeKumaService.js" as KumaService

KCM.SimpleKCM {
    id: configAppearance

    property string cfg_desktopMode
    property string cfg_selectedGroup
    property string cfg_availableGroups
    property string cfg_compactDisplayMode
    property int cfg_heartbeatCount
    property bool cfg_showLatency
    property bool cfg_showUptimePercent
    property bool cfg_showTags

    property string cfg_desktopModeDefault: "full"
    property string cfg_selectedGroupDefault: ""
    property string cfg_availableGroupsDefault: ""
    property string cfg_compactDisplayModeDefault: "textAndBadge"
    property int cfg_heartbeatCountDefault: 25
    property bool cfg_showLatencyDefault: true
    property bool cfg_showUptimePercentDefault: true
    property bool cfg_showTagsDefault: true

    property bool isFetchingGroups: false
    property string groupFetchStatus: ""
    property var distinctGroupList: getDistinctGroups()

    onCfg_availableGroupsChanged: {
        updateGroupList();
    }

    onCfg_selectedGroupChanged: {
        Plasmoid.configuration.selectedGroup = cfg_selectedGroup || "";
    }

    Timer {
        id: fetchTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (configAppearance.isFetchingGroups) {
                configAppearance.isFetchingGroups = false;
                configAppearance.groupFetchStatus = "Query timed out. Check network or server connection.";
            }
        }
    }

    function getDistinctGroups() {
        var set = {};
        var avail = configAppearance.cfg_availableGroups || Plasmoid.configuration.availableGroups || "";
        if (avail && avail.length > 0) {
            var list = avail.split("|");
            for (var i = 0; i < list.length; i++) {
                var g = list[i].trim();
                if (g.length > 0) set[g] = true;
            }
        }
        var cur = configAppearance.cfg_selectedGroup || Plasmoid.configuration.selectedGroup || "";
        if (cur && cur.length > 0 && cur !== "all") {
            var curList = cur.split("|");
            for (var j = 0; j < curList.length; j++) {
                var s = curList[j].trim();
                if (s.length > 0) set[s] = true;
            }
        }
        var keys = Object.keys(set);
        keys.sort();
        return keys;
    }

    function getSelectedGroupList() {
        var raw = configAppearance.cfg_selectedGroup || "";
        if (!raw || raw.trim().length === 0 || raw === "all") return [];
        return raw.split("|").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
    }

    function isGroupChecked(name) {
        var list = getSelectedGroupList();
        return list.indexOf(name) !== -1;
    }

    function toggleGroupSelection(name, checked) {
        var list = getSelectedGroupList();
        var idx = list.indexOf(name);
        if (checked && idx === -1) {
            list.push(name);
        } else if (!checked && idx !== -1) {
            list.splice(idx, 1);
        }
        var newVal = list.join("|");
        configAppearance.cfg_selectedGroup = newVal;
        Plasmoid.configuration.selectedGroup = newVal;
    }

    function selectAllGroups() {
        var all = getDistinctGroups();
        var newVal = all.join("|");
        configAppearance.cfg_selectedGroup = newVal;
        Plasmoid.configuration.selectedGroup = newVal;
    }

    function clearGroupSelection() {
        configAppearance.cfg_selectedGroup = "";
        Plasmoid.configuration.selectedGroup = "";
    }

    function updateGroupList() {
        distinctGroupList = getDistinctGroups();
    }

    function refreshGroupsFromApi() {
        var sUrl = Plasmoid.configuration.serverUrl;
        var slug = Plasmoid.configuration.slug || "default";
        var auth = Plasmoid.configuration.authHeader || "";

        if (!sUrl || sUrl.trim().length === 0) {
            groupFetchStatus = "Configure Server URL in General settings first.";
            return;
        }

        isFetchingGroups = true;
        groupFetchStatus = "Querying Uptime Kuma API for groups...";
        fetchTimeoutTimer.restart();

        KumaService.fetchGroupsOnly(sUrl, slug, auth, function(groups) {
            fetchTimeoutTimer.stop();
            isFetchingGroups = false;
            if (groups && groups.length > 0) {
                configAppearance.cfg_availableGroups = groups.join("|");
                Plasmoid.configuration.availableGroups = groups.join("|");
                groupFetchStatus = "Found " + groups.length + " group" + (groups.length === 1 ? "" : "s") + " from server.";
                updateGroupList();
            } else {
                groupFetchStatus = "No groups found on status page.";
            }
        }, function(errorMsg) {
            fetchTimeoutTimer.stop();
            isFetchingGroups = false;
            groupFetchStatus = "Could not fetch groups: " + errorMsg;
        });
    }

    Component.onCompleted: {
        if (!cfg_selectedGroup && Plasmoid.configuration.selectedGroup) {
            cfg_selectedGroup = Plasmoid.configuration.selectedGroup;
        }
        if (!cfg_availableGroups && Plasmoid.configuration.availableGroups) {
            cfg_availableGroups = Plasmoid.configuration.availableGroups;
        }
        updateGroupList();
        if (configAppearance.cfg_availableGroups && configAppearance.cfg_availableGroups.length > 0) {
            var count = configAppearance.cfg_availableGroups.split("|").length;
            groupFetchStatus = "Loaded " + count + " cached group" + (count === 1 ? "" : "s") + ".";
        }
        refreshGroupsFromApi();
    }

    QQC2.ButtonGroup {
        id: desktopModeGroup
    }

    QQC2.ButtonGroup {
        id: displayModeGroup
    }

    Kirigami.FormLayout {
        id: formLayout

        // 1. Desktop representation & group selection
        Item {
            Kirigami.FormData.label: "Widget on Desktop"
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: "Desktop appearance:"
            Kirigami.FormData.buddyFor: modeDesktopFull
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: modeDesktopFull
                QQC2.ButtonGroup.group: desktopModeGroup
                text: "Full Dashboard (flat list of monitor cards, heartbeat history, latency)"
                checked: configAppearance.cfg_desktopMode === "full" || !configAppearance.cfg_desktopMode
                onToggled: if (checked) configAppearance.cfg_desktopMode = "full"
            }

            QQC2.RadioButton {
                id: modeDesktopGrouped
                QQC2.ButtonGroup.group: desktopModeGroup
                text: "Grouped by Category (group cards with health badges and collapsible monitors)"
                checked: configAppearance.cfg_desktopMode === "grouped"
                onToggled: if (checked) configAppearance.cfg_desktopMode = "grouped"
            }

            QQC2.RadioButton {
                id: modeDesktopCompact
                QQC2.ButtonGroup.group: desktopModeGroup
                text: "Compact Widget (small icon/badge on desktop, click to expand)"
                checked: configAppearance.cfg_desktopMode === "compact"
                onToggled: if (checked) configAppearance.cfg_desktopMode = "compact"
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: "Filter by group(s):"
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: {
                        var list = configAppearance.getSelectedGroupList();
                        if (list.length === 0) return "Showing all groups";
                        return "Selected (" + list.length + "): " + list.join(", ");
                    }
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                QQC2.Button {
                    text: "Select All"
                    visible: configAppearance.distinctGroupList.length > 0
                    onClicked: configAppearance.selectAllGroups()
                }

                QQC2.Button {
                    text: "Clear"
                    visible: configAppearance.getSelectedGroupList().length > 0
                    QQC2.ToolTip.text: "Clear filter (show all groups)"
                    QQC2.ToolTip.visible: hovered
                    onClicked: configAppearance.clearGroupSelection()
                }

                QQC2.Button {
                    id: refreshGroupsBtn
                    icon.name: "view-refresh"
                    enabled: !configAppearance.isFetchingGroups
                    QQC2.ToolTip.text: "Query Uptime Kuma API to refresh available groups"
                    QQC2.ToolTip.visible: hovered
                    onClicked: configAppearance.refreshGroupsFromApi()
                }
            }

            // Scrollable list of group checkboxes
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(Kirigami.Units.gridUnit * 10, Math.max(Kirigami.Units.gridUnit * 4, configAppearance.distinctGroupList.length * 32 + Kirigami.Units.smallSpacing * 2))
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.separatorColor
                border.width: 1

                QQC2.ScrollView {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 2

                        QQC2.Label {
                            visible: configAppearance.distinctGroupList.length === 0 && !configAppearance.isFetchingGroups
                            text: "No groups found. Click Refresh to query groups from your Uptime Kuma instance."
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: configAppearance.distinctGroupList
                            delegate: QQC2.CheckBox {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                checked: configAppearance.isGroupChecked(modelData)
                                onToggled: configAppearance.toggleGroupSelection(modelData, checked)
                            }
                        }
                    }
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                visible: configAppearance.isFetchingGroups || configAppearance.groupFetchStatus !== ""
                Layout.fillWidth: true

                QQC2.BusyIndicator {
                    running: configAppearance.isFetchingGroups
                    visible: configAppearance.isFetchingGroups
                    implicitWidth: Kirigami.Units.gridUnit
                    implicitHeight: Kirigami.Units.gridUnit
                }

                QQC2.Label {
                    text: configAppearance.groupFetchStatus
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.8
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    color: configAppearance.groupFetchStatus.indexOf("Could not") !== -1 || configAppearance.groupFetchStatus.indexOf("timed out") !== -1 ? "#e74c3c" : Kirigami.Theme.textColor
                }
            }

            QQC2.Label {
                text: "Select one or multiple groups to monitor, or leave cleared to show all monitors."
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        // 2. Compact / Panel representation selection
        Item {
            Kirigami.FormData.label: "Compact / Panel Style"
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            text: "Used when the widget is in a taskbar panel, or when 'Compact Widget' is chosen on the desktop:"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            Kirigami.FormData.label: "Display mode:"
            Kirigami.FormData.buddyFor: modeTextAndBadge
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: modeTextAndBadge
                QQC2.ButtonGroup.group: displayModeGroup
                text: "Icon with Status Text (e.g. 66/66 Up, 1 Down)"
                checked: configAppearance.cfg_compactDisplayMode === "textAndBadge" || configAppearance.cfg_compactDisplayMode === "0" || !configAppearance.cfg_compactDisplayMode
                onToggled: if (checked) configAppearance.cfg_compactDisplayMode = "textAndBadge"
            }

            QQC2.RadioButton {
                id: modeBadgeOnly
                QQC2.ButtonGroup.group: displayModeGroup
                text: "Icon only with status badge"
                checked: configAppearance.cfg_compactDisplayMode === "badgeOnly" || configAppearance.cfg_compactDisplayMode === "1"
                onToggled: if (checked) configAppearance.cfg_compactDisplayMode = "badgeOnly"
            }

            QQC2.RadioButton {
                id: modeUptimePercent
                QQC2.ButtonGroup.group: displayModeGroup
                text: "Icon with 24h Uptime % (e.g. 99.8%)"
                checked: configAppearance.cfg_compactDisplayMode === "uptimePercent" || configAppearance.cfg_compactDisplayMode === "2"
                onToggled: if (checked) configAppearance.cfg_compactDisplayMode = "uptimePercent"
            }

            QQC2.RadioButton {
                id: modeMonitorsCount
                QQC2.ButtonGroup.group: displayModeGroup
                text: "Icon with Count Ratio (e.g. 66/66)"
                checked: configAppearance.cfg_compactDisplayMode === "monitorsCount" || configAppearance.cfg_compactDisplayMode === "3"
                onToggled: if (checked) configAppearance.cfg_compactDisplayMode = "monitorsCount"
            }
        }

        // 3. Monitor cards & Heartbeat bar options
        Item {
            Kirigami.FormData.label: "Monitor Cards & Heartbeat Bar"
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: "Heartbeat history count:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                from: 10
                to: 50
                stepSize: 5
                value: configAppearance.cfg_heartbeatCount
                onValueChanged: configAppearance.cfg_heartbeatCount = value
            }

            QQC2.Label {
                text: "checks"
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Details:"
            text: "Show ping latency (ms)"
            checked: configAppearance.cfg_showLatency
            onCheckedChanged: configAppearance.cfg_showLatency = checked
        }

        QQC2.CheckBox {
            text: "Show 24h uptime percentage"
            checked: configAppearance.cfg_showUptimePercent
            onCheckedChanged: configAppearance.cfg_showUptimePercent = checked
        }

        QQC2.CheckBox {
            text: "Show monitor tags"
            checked: configAppearance.cfg_showTags
            onCheckedChanged: configAppearance.cfg_showTags = checked
        }
    }
}
