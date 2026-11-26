import QtQuick
import QtQuick.Controls
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

    implicitWidth: 34
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

        Canvas {
            id: dualHeadphonesIcon
            width: 20
            height: 20
            anchors.centerIn: parent

            property color iconColor: root.virtualActive ? Commons.Color.primary : Commons.Color.onSurface

            onIconColorChanged: requestPaint()
            Component.onCompleted: requestPaint()

            function drawHeadphone(ctx, ox, oy, alpha) {
                ctx.save()
                ctx.globalAlpha = alpha
                ctx.strokeStyle = iconColor.toString()
                ctx.fillStyle = iconColor.toString()
                ctx.lineWidth = 1.65
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                // Kopfbuegel
                ctx.beginPath()
                ctx.arc(ox + 6.5, oy + 7.0, 5.2, Math.PI, 0, false)
                ctx.stroke()

                // Linke und rechte Ohrmuschel
                ctx.beginPath()
                ctx.roundedRect(ox + 1.0, oy + 6.8, 2.5, 4.4, 1.1, 1.1)
                ctx.roundedRect(ox + 9.5, oy + 6.8, 2.5, 4.4, 1.1, 1.1)
                ctx.fill()
                ctx.restore()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                // Hinterer Kopfhoerer (leicht nach rechts oben versetzt)
                drawHeadphone(ctx, 5.5, 1.5, 0.55)
                // Vorderer Kopfhoerer (leicht nach links unten versetzt)
                drawHeadphone(ctx, 1.5, 5.5, 1.0)
            }
        }

        ToolTip.visible: mouseArea.containsMouse
        ToolTip.delay: 450
        ToolTip.text: root.virtualActive
            ? root.t("widgetSubtitleActive", { count: root.selectedCount })
            : root.t("widgetSubtitleIdle")

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
