import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import "../code/uptimeKumaService.js" as KumaService

Rectangle {
    id: incidentBanner

    property var incident: null

    visible: incident !== null && incident !== undefined
    implicitHeight: visible ? layout.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0

    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(0.95, 0.65, 0.15, 0.15)
    border.color: Qt.rgba(0.95, 0.65, 0.15, 0.6)
    border.width: 1

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignTop
            width: 20
            height: 20
            source: "dialog-warning"
            color: "#f39c12"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    text: incident ? incident.title : ""
                    font.bold: true
                    color: "#f39c12"
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    text: incident && incident.createdDate ? KumaService.formatTime(incident.createdDate) : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: incident ? incident.content : ""
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
