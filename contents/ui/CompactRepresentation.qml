import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/uptimeKumaService.js" as KumaService

MouseArea {
    id: compactRep

    hoverEnabled: true

    readonly property bool isPlanar: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var stats: root.statusData ? root.statusData.stats : null
    readonly property bool hasDown: stats && stats.down > 0
    readonly property bool hasPending: stats && stats.pending > 0 && !hasDown
    readonly property string displayMode: {
        var m = Plasmoid.configuration.compactDisplayMode;
        if (m === "badgeOnly" || m === 1 || m === "1") return "badgeOnly";
        if (m === "uptimePercent" || m === 2 || m === "2") return "uptimePercent";
        if (m === "monitorsCount" || m === 3 || m === "3") return "monitorsCount";
        return "textAndBadge";
    }
    readonly property bool showLabel: !isVertical && displayMode !== "badgeOnly"

    implicitWidth: isVertical ? Kirigami.Units.iconSizes.small : (isPlanar ? Math.max(contentLayout.implicitWidth + Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 4) : (contentLayout.implicitWidth + Kirigami.Units.smallSpacing * 2))
    implicitHeight: isVertical ? (contentLayout.implicitHeight + Kirigami.Units.smallSpacing * 2) : (isPlanar ? Math.max(contentLayout.implicitHeight + Kirigami.Units.smallSpacing * 2, Kirigami.Units.gridUnit * 2) : Kirigami.Units.iconSizes.small)

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight

    onClicked: {
        root.expanded = !root.expanded;
    }

    // Status pill background
    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: isPlanar
            ? (compactRep.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.25))
            : (compactRep.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
        border.color: hasDown ? Qt.rgba(0.92, 0.25, 0.25, 0.6) : (compactRep.containsMouse ? Qt.rgba(0.5, 0.5, 0.5, 0.4) : (isPlanar ? Qt.rgba(1, 1, 1, 0.15) : "transparent"))
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    RowLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        // Applet Icon with status badge
        Item {
            id: iconItem
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: kumaIcon
                anchors.fill: parent
                source: Qt.resolvedUrl("../images/uptime-kuma.svg")
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                opacity: root.isLoading ? 0.6 : 1.0

                // Fallback to breeze icon if image fails
                onStatusChanged: {
                    if (status === Image.Error) {
                        fallbackIcon.visible = true;
                        kumaIcon.visible = false;
                    }
                }
            }

            Kirigami.Icon {
                id: fallbackIcon
                anchors.fill: parent
                source: "network-server"
                visible: false
            }

            // Status Badge Dot on Icon
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -1
                width: 7
                height: 7
                radius: 3.5
                color: {
                    if (root.hasError) return "#e74c3c";
                    if (!stats) return "#95a5a6";
                    if (hasDown) return "#e74c3c";
                    if (hasPending) return "#f39c12";
                    return "#2ecc71";
                }
                border.color: Kirigami.Theme.backgroundColor
                border.width: 1
            }

            // Pulse animation when outages exist
            SequentialAnimation on scale {
                running: hasDown
                loops: Animation.Infinite
                PropertyAnimation { to: 1.15; duration: 500; easing.type: Easing.InOutQuad }
                PropertyAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
            }
        }

        // Status Label (hidden in vertical panels or badgeOnly mode)
        QQC2.Label {
            id: statusLabel
            visible: compactRep.showLabel
            Layout.alignment: Qt.AlignVCenter
            font.bold: hasDown
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: {
                if (root.hasError) return "#e74c3c";
                if (hasDown) return "#e74c3c";
                return Kirigami.Theme.textColor;
            }

            text: {
                if (root.hasError) return "Error";
                if (root.isLoading && !stats) return "...";
                if (!stats || stats.total === 0) return "Uptime";

                if (compactRep.displayMode === "uptimePercent") {
                    var pct = (stats.overallUptime !== undefined && stats.overallUptime !== null)
                        ? Number(stats.overallUptime).toFixed(1) + "%"
                        : "100%";
                    return pct;
                }
                if (compactRep.displayMode === "monitorsCount") {
                    return stats.up + "/" + stats.total;
                }

                if (hasDown) {
                    return stats.down + (stats.down === 1 ? " Down" : " Down");
                }
                if (hasPending) {
                    return "Pending";
                }
                return stats.up + "/" + stats.total + " Up";
            }
        }
    }
}
