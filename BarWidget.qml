import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "i18n.js" as I18n

Item {
    id: root

    property var bar: null
    property string localeName: Qt.locale().name
    property bool virtualActive: false
    property int selectedCount: 0
    property int masterVolume: 100
    property bool masterMute: false
    property string themeForeground: "#c0caf5"
    property string themeAccent: "#7aa2f7"
    property string scriptPath: Qt.resolvedUrl("scripts/audio-share.sh").toString().replace("file://", "")

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property color iconBaseColor: (Commons.Color && Commons.Color.foreground)
        ? Commons.Color.foreground
        : root.themeForeground
    readonly property color iconAccentColor: (Commons.Color && Commons.Color.accent)
        ? Commons.Color.accent
        : root.themeAccent

    function t(key, vars) {
        return I18n.tr(root.localeName, key, vars)
    }

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function toggle() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.anchorItem = buttonHitbox
        panelLoader.item.hostWidget = root
    }

    implicitWidth: 26
    implicitHeight: 24

    function refreshStatus() {
        if (!statusProc.running) {
            statusProc.command = ["bash", root.scriptPath, "status"]
            statusProc.running = true
        }
    }

    Component.onCompleted: {
        refreshStatus()
        injectPanel()
    }

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
                    if (data.theme) {
                        if (data.theme.foreground) root.themeForeground = data.theme.foreground
                        if (data.theme.accent) root.themeAccent = data.theme.accent
                        else if (data.theme.color4) root.themeAccent = data.theme.color4
                    }
                    const sinks = Array.isArray(data.sinks) ? data.sinks : []
                    root.selectedCount = sinks.filter(s => s.selected).length
                } catch (e) {
                    // Ignoriere unvollstaendige Ausgaben beim Shell-Start
                }
            }
        }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    Item {
        id: buttonHitbox
        anchors.fill: parent

        Canvas {
            id: dualHeadphonesIcon
            width: 15
            height: 15
            anchors.centerIn: parent

            property color iconColor: root.virtualActive
                ? root.iconAccentColor
                : root.iconBaseColor

            onIconColorChanged: requestPaint()
            Component.onCompleted: requestPaint()

            function drawHeadphone(ctx, ox, oy, alpha) {
                ctx.save()
                ctx.globalAlpha = alpha
                ctx.strokeStyle = iconColor.toString()
                ctx.fillStyle = iconColor.toString()
                ctx.lineWidth = 1.35
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                // Kopfbuegel
                ctx.beginPath()
                ctx.arc(ox + 5.0, oy + 5.4, 4.0, Math.PI, 0, false)
                ctx.stroke()

                // Linke und rechte Ohrmuschel
                ctx.beginPath()
                ctx.roundedRect(ox + 0.8, oy + 5.2, 1.9, 3.4, 0.85, 0.85)
                ctx.roundedRect(ox + 7.3, oy + 5.2, 1.9, 3.4, 0.85, 0.85)
                ctx.fill()
                ctx.restore()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                // Hinterer Kopfhoerer (leicht nach rechts oben versetzt)
                drawHeadphone(ctx, 4.0, 1.0, 0.58)
                // Vorderer Kopfhoerer (leicht nach links unten versetzt)
                drawHeadphone(ctx, 1.0, 4.2, 1.0)
            }
        }

        ToolTip.visible: mouseArea.containsMouse && !root.opened
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
                root.toggle()
            }
        }
    }
}
