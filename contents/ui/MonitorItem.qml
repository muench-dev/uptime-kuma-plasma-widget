import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../code/uptimeKumaService.js" as KumaService

Rectangle {
    id: monitorCard

    property var monitor: null
    property bool showLatency: true
    property bool showUptimePercent: true
    property bool showHeartbeats: true
    property bool showTags: true
    property int heartbeatCount: 25

    property bool expanded: false

    implicitHeight: cardLayout.implicitHeight + (Kirigami.Units.smallSpacing * 2)
    radius: Kirigami.Units.cornerRadius

    color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
    border.color: {
        if (!monitor) return Qt.rgba(0.5, 0.5, 0.5, 0.3);
        if (monitor.status === KumaService.STATUS_DOWN) return Qt.rgba(0.92, 0.25, 0.25, 0.6);
        if (mouseArea.containsMouse) return Kirigami.Theme.focusColor;
        return Qt.rgba(0.5, 0.5, 0.5, 0.2);
    }
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            monitorCard.expanded = !monitorCard.expanded;
        }
    }

    ColumnLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        // Main Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 1.5

            // Status Dot
            Item {
                width: 16
                height: 16
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: statusDot
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: monitor ? monitor.statusColor : "#95a5a6"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 4
                        height: parent.height + 4
                        radius: width / 2
                        color: parent.color
                        opacity: 0.35
                    }

                    SequentialAnimation on scale {
                        running: monitor && monitor.status === KumaService.STATUS_DOWN
                        loops: Animation.Infinite
                        PropertyAnimation { to: 1.25; duration: 500; easing.type: Easing.InOutQuad }
                        PropertyAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                    }
                }
            }

            // Monitor Name & Host/Type
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Label {
                        text: monitor ? monitor.name : ""
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        elide: Text.ElideRight
                        Layout.maximumWidth: monitorCard.width * 0.55
                    }

                    Rectangle {
                        visible: monitor && monitor.type !== ""
                        height: 16
                        width: typeLabel.implicitWidth + 8
                        radius: 3
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.2)

                        QQC2.Label {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: monitor ? monitor.type : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            font.bold: true
                            opacity: 0.8
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: {
                        if (!monitor) return "";
                        if (monitor.url) return monitor.url;
                        if (monitor.hostname) return monitor.hostname + (monitor.port ? (":" + monitor.port) : "");
                        return monitor.groupName || "";
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.65
                    elide: Text.ElideRight
                }
            }

            // Right Metrics (Latency & Uptime %)
            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                // Ping Latency Badge
                Rectangle {
                    visible: monitorCard.showLatency && monitor && monitor.ping !== null
                    height: 22
                    width: pingLayout.implicitWidth + 10
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(0.5, 0.5, 0.5, 0.15)

                    RowLayout {
                        id: pingLayout
                        anchors.centerIn: parent
                        spacing: 3

                        QQC2.Label {
                            text: monitor ? KumaService.formatPing(monitor.ping) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: monitor ? KumaService.getPingColor(monitor.ping) : Kirigami.Theme.textColor
                            font.bold: true
                        }
                    }
                }

                // 24h Uptime Pill
                Rectangle {
                    visible: monitorCard.showUptimePercent && monitor !== null
                    height: 22
                    width: uptimeLabel.implicitWidth + 12
                    radius: Kirigami.Units.cornerRadius
                    color: {
                        if (!monitor) return Qt.rgba(0.5, 0.5, 0.5, 0.15);
                        var u = monitor.uptime24h;
                        if (u >= 99.0) return Qt.rgba(0.18, 0.75, 0.45, 0.18);
                        if (u >= 95.0) return Qt.rgba(0.95, 0.65, 0.15, 0.18);
                        return Qt.rgba(0.92, 0.25, 0.25, 0.22);
                    }

                    QQC2.Label {
                        id: uptimeLabel
                        anchors.centerIn: parent
                        text: (monitor ? monitor.uptime24h.toFixed(1) : "100") + "%"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.bold: true
                        color: {
                            if (!monitor) return Kirigami.Theme.textColor;
                            var u = monitor.uptime24h;
                            if (u >= 99.0) return "#2ecc71";
                            if (u >= 95.0) return "#f39c12";
                            return "#e74c3c";
                        }
                    }
                }
            }
        }

        // Tags Row
        Row {
            visible: monitorCard.showTags && monitor && monitor.tags && monitor.tags.length > 0
            spacing: 4
            Layout.fillWidth: true

            Repeater {
                model: (monitor && monitor.tags) ? monitor.tags : []
                delegate: Rectangle {
                    required property var modelData
                    height: 16
                    width: tagLabel.implicitWidth + 8
                    radius: 3
                    color: modelData.color ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(
                        parseInt(modelData.color.slice(1,3), 16)/255,
                        parseInt(modelData.color.slice(3,5), 16)/255,
                        parseInt(modelData.color.slice(5,7), 16)/255, 0.25)) : Qt.rgba(0.5,0.5,0.5,0.2)
                    border.color: modelData.color || Qt.rgba(0.5, 0.5, 0.5, 0.3)
                    border.width: 1

                    QQC2.Label {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: modelData.name
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                        color: modelData.color || Kirigami.Theme.textColor
                    }
                }
            }
        }

        // Signature Heartbeat Bar
        HeartbeatBar {
            visible: monitorCard.showHeartbeats && monitor && monitor.heartbeats && monitor.heartbeats.length > 0
            Layout.fillWidth: true
            heartbeats: monitor ? monitor.heartbeats : []
            maxBars: monitorCard.heartbeatCount
        }

        // Expanded Details Section
        ColumnLayout {
            visible: monitorCard.expanded
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(0.5, 0.5, 0.5, 0.3)
                opacity: 0.5
            }

            // Error message if down
            Rectangle {
                visible: monitor && monitor.status === KumaService.STATUS_DOWN && monitor.lastMsg !== ""
                Layout.fillWidth: true
                height: errMsgLabel.implicitHeight + 10
                radius: 4
                color: Qt.rgba(0.92, 0.25, 0.25, 0.15)
                border.color: Qt.rgba(0.92, 0.25, 0.25, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6
                    Kirigami.Icon {
                        width: 14
                        height: 14
                        source: "dialog-warning"
                        color: "#e74c3c"
                    }
                    QQC2.Label {
                        id: errMsgLabel
                        Layout.fillWidth: true
                        text: monitor ? monitor.lastMsg : ""
                        color: "#e74c3c"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: Text.Wrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: {
                        if (!monitor || !monitor.lastTime) return "";
                        return "Last check: " + KumaService.formatTime(monitor.lastTime) + (monitor.lastMsg ? (" (" + monitor.lastMsg + ")") : "");
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.6
                    elide: Text.ElideRight
                }

                PlasmaComponents.Button {
                    visible: monitor && monitor.url !== ""
                    text: "Open"
                    icon.name: "internet-web-browser"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: {
                        if (monitor && monitor.url) {
                            Qt.openUrlExternally(monitor.url);
                        }
                    }
                }
            }
        }
    }
}
