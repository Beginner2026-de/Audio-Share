import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "i18n.js" as I18n

Item {
    id: root

    property var pluginApi: null

    property string localeName: Qt.locale().name
    property bool virtualActive: false
    property int selectedCount: 0
    property int masterVolume: 100
    property bool masterMute: false
    property string scriptPath: Qt.resolvedUrl("scripts/audio-share.sh").toString().replace("file://", "")

    function t(key, vars) {
        return I18n.tr(root.localeName, key, vars)
    }

    implicitWidth: pillRow.implicitWidth + 20
    implicitHeight: 28

    function refreshStatus() {
        if (!statusProc.running) {
            statusProc.command = ["bash", root.scriptPath, "status"]
            statusProc.running = true
        }
    }

    Component.onCompleted: refreshStatus()

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    root.virtualActive = Boolean(data.virtualActive)
                    root.masterVolume = Number(data.virtualVolume ?? 100)
                    root.masterMute = Boolean(data.virtualMute)
                    const sinks = Array.isArray(data.sinks) ? data.sinks : []
                    root.selectedCount = sinks.filter(s => s.selected).length
                } catch (e) {
                    // Ignoriere unvollstaendige Ausgaben beim Shell-Start
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse
            ? Commons.Color.surfaceVariant
            : (root.virtualActive ? Commons.Color.primaryContainer : "transparent")
        border.width: root.virtualActive ? 1 : 0
        border.color: Commons.Color.primary

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.virtualActive ? "󰋋+" : "󰋋"
                font.pixelSize: 14
                color: root.virtualActive ? Commons.Color.primary : Commons.Color.onSurface
            }

            Text {
                text: root.virtualActive
                    ? (root.t("widgetTitle") + " · " + root.selectedCount)
                    : root.t("widgetTitle")
                font.pixelSize: 12
                font.weight: root.virtualActive ? Font.DemiBold : Font.Medium
                color: root.virtualActive ? Commons.Color.primary : Commons.Color.onSurface
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.refreshStatus()
                if (root.pluginApi && root.pluginApi.togglePanel) {
                    root.pluginApi.togglePanel()
                } else if (root.pluginApi && root.pluginApi.openPanel) {
                    root.pluginApi.openPanel()
                }
            }
        }
    }
}
