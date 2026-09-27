import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../code/uptimeKumaService.js" as KumaService

Item {
    id: heartbeatBar

    property var heartbeats: []
    property int maxBars: 25

    implicitHeight: 18
    implicitWidth: layout.implicitWidth

    Row {
        id: layout
        anchors.fill: parent
        spacing: 3

        readonly property int barCount: Math.min(heartbeatBar.heartbeats ? heartbeatBar.heartbeats.length : 0, heartbeatBar.maxBars)
        readonly property real computedBarWidth: {
            if (barCount <= 0) return 6;
            var avail = heartbeatBar.width - ((barCount - 1) * layout.spacing);
            var w = avail / barCount;
            return Math.max(3, Math.min(10, w));
        }

        Repeater {
            model: heartbeatBar.heartbeats ? heartbeatBar.heartbeats.slice(-heartbeatBar.maxBars) : []

            delegate: Rectangle {
                id: barRect
                required property var modelData
                required property int index

                width: layout.computedBarWidth
                height: heartbeatBar.height
                radius: 2

                color: {
                    var s = modelData.status;
                    if (s === KumaService.STATUS_UP) return "#2ecc71";
                    if (s === KumaService.STATUS_DOWN) return "#e74c3c";
                    if (s === KumaService.STATUS_PENDING) return "#f39c12";
                    if (s === KumaService.STATUS_MAINTENANCE) return "#3498db";
                    return "#95a5a6";
                }

                opacity: barMouse.containsMouse ? 1.0 : 0.85
                scale: barMouse.containsMouse ? 1.15 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }

                MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    QQC2.ToolTip.text: {
                        var statusStr = KumaService.getStatusText(modelData.status);
                        var pingStr = modelData.ping !== null && modelData.ping !== undefined ? (modelData.ping + " ms") : "No ping";
                        var timeStr = KumaService.formatTime(modelData.time);
                        var msgStr = modelData.msg ? ("\n" + modelData.msg) : "";
                        return statusStr + " (" + pingStr + ")" + (timeStr ? ("\n" + timeStr) : "") + msgStr;
                    }
                }
            }
        }
    }
}
