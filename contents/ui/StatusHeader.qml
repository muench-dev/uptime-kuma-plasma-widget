import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import "../code/uptimeKumaService.js" as KumaService

Rectangle {
    id: statusHeader

    property var stats: null
    property string statusTitle: "Uptime Kuma"
    property var lastUpdated: null

    implicitHeight: mainLayout.implicitHeight + Kirigami.Units.smallSpacing * 3
    radius: Kirigami.Units.cornerRadius

    readonly property bool isDown: stats && stats.down > 0
    readonly property bool isPending: stats && stats.pending > 0 && !isDown

    color: {
        if (!stats || stats.total === 0) {
            return Kirigami.Theme.backgroundColor;
        }
        if (isDown) {
            return Qt.rgba(0.92, 0.25, 0.25, 0.18);
        }
        if (isPending) {
            return Qt.rgba(0.95, 0.65, 0.15, 0.18);
        }
        return Qt.rgba(0.18, 0.75, 0.45, 0.18);
    }

    border.color: {
        if (!stats || stats.total === 0) {
            return Qt.rgba(0.5, 0.5, 0.5, 0.3);
        }
        if (isDown) return Qt.rgba(0.92, 0.25, 0.25, 0.5);
        if (isPending) return Qt.rgba(0.95, 0.65, 0.15, 0.5);
        return Qt.rgba(0.18, 0.75, 0.45, 0.5);
    }
    border.width: 1

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        // Top Row: Status Icon + Title + Subtitle
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.gridUnit

            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: {
                    if (isDown) return "#e74c3c";
                    if (isPending) return "#f39c12";
                    return "#2ecc71";
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: {
                        if (isDown) return "dialog-error";
                        if (isPending) return "dialog-warning";
                        return "answer-correct";
                    }
                    color: "white"
                }

                SequentialAnimation on scale {
                    running: isDown
                    loops: Animation.Infinite
                    PropertyAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutQuad }
                    PropertyAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: stats ? stats.overallStatusText : "Checking Status..."
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.75
                    text: {
                        var page = statusTitle || "Uptime Kuma";
                        var timeStr = lastUpdated ? (" • Checked " + KumaService.formatTime(lastUpdated)) : "";
                        return page + timeStr;
                    }
                    elide: Text.ElideRight
                }
            }
        }

        // Horizontal Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(0.5, 0.5, 0.5, 0.3)
            opacity: 0.6
        }

        // Bottom Row: Summary Metrics Pills
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Up Pill
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(0.18, 0.75, 0.45, 0.15)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: "#2ecc71"
                    }
                    QQC2.Label {
                        text: (stats ? stats.up : 0) + " Up"
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // Down Pill
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: Kirigami.Units.cornerRadius
                color: isDown ? Qt.rgba(0.92, 0.25, 0.25, 0.25) : Qt.rgba(0.5, 0.5, 0.5, 0.1)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: isDown ? "#e74c3c" : "#95a5a6"
                    }
                    QQC2.Label {
                        text: (stats ? stats.down : 0) + " Down"
                        font.bold: isDown
                        color: isDown ? "#e74c3c" : Kirigami.Theme.textColor
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // Avg Ping Pill
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(0.5, 0.5, 0.5, 0.1)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Kirigami.Icon {
                        width: 14
                        height: 14
                        source: "network-connect"
                        opacity: 0.7
                    }
                    QQC2.Label {
                        text: (stats && stats.averagePing !== null) ? (stats.averagePing + " ms") : "--"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // 24h Uptime Pill
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(0.5, 0.5, 0.5, 0.1)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Kirigami.Icon {
                        width: 14
                        height: 14
                        source: "view-financial-transfer"
                        opacity: 0.7
                    }
                    QQC2.Label {
                        text: (stats ? stats.overallUptime.toFixed(1) : "100") + "%"
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }
        }
    }
}
