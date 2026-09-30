import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_serverUrl
    property string cfg_slug
    property string cfg_authHeader
    property int cfg_updateInterval
    property bool cfg_notifyOnStatusChange

    property string cfg_serverUrlDefault: ""
    property string cfg_slugDefault: "default"
    property string cfg_authHeaderDefault: ""
    property int cfg_updateIntervalDefault: 60
    property bool cfg_notifyOnStatusChangeDefault: true

    Kirigami.FormLayout {
        id: formLayout

        Item {
            Kirigami.FormData.label: "Uptime Kuma Server"
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: serverUrlField
            Kirigami.FormData.label: "Server URL:"
            placeholderText: "https://status.example.com or http://localhost:3001"
            text: configGeneral.cfg_serverUrl
            onTextChanged: configGeneral.cfg_serverUrl = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "Enter your Uptime Kuma base URL or full status page URL."
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: slugField
            Kirigami.FormData.label: "Status Page Slug:"
            placeholderText: "default"
            text: configGeneral.cfg_slug
            onTextChanged: configGeneral.cfg_slug = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "The status page identifier configured in Uptime Kuma (usually 'default')."
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: authHeaderField
            Kirigami.FormData.label: "API Key / Auth Token:"
            placeholderText: "uk2_... or Bearer <token>"
            text: configGeneral.cfg_authHeader
            echoMode: TextInput.PasswordEchoOnEdit
            onTextChanged: configGeneral.cfg_authHeader = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "Uptime Kuma API Key (e.g. uk2_...) or Bearer / Basic token. If provided, the widget can query your monitors directly via /metrics or a protected status page."
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Item {
            Kirigami.FormData.label: "Polling & Notifications"
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: "Update Interval:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                id: intervalSpinBox
                from: 15
                to: 600
                stepSize: 15
                value: configGeneral.cfg_updateInterval
                onValueChanged: configGeneral.cfg_updateInterval = value
            }

            QQC2.Label {
                text: "seconds"
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Notifications:"
            text: "Notify when a service goes down or recovers"
            checked: configGeneral.cfg_notifyOnStatusChange
            onCheckedChanged: configGeneral.cfg_notifyOnStatusChange = checked
        }
    }
}
