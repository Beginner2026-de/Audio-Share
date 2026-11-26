import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons as Commons
import "i18n.js" as I18n

PopupWindow {
    id: popupWin

    property var anchorItem: null
    property var hostWidget: null
    property bool opened: false
    property double lastClosedAt: 0

    property string localeName: Qt.locale().name
    property bool virtualActive: false
    property int virtualVolume: 100
    property bool virtualMute: false
    property var sinks: []
    property bool busy: false
    property string statusMessage: ""
    property string scriptPath: Qt.resolvedUrl("scripts/audio-share.sh").toString().replace("file://", "")

    // Fallback-Farben aus ~/.config/omarchy/current/theme/colors.toml
    property string tomlBg: "#1a1b26"
    property string tomlFg: "#c0caf5"
    property string tomlAccent: "#7aa2f7"
    property string tomlError: "#f7768e"

    // Echte Omarchy-Theme-Farben (qs.Commons.Color + colors.toml Fallback)
    readonly property color themeBg: (Commons.Color && Commons.Color.popups && Commons.Color.popups.background)
        ? Commons.Color.popups.background
        : ((Commons.Color && Commons.Color.background)
            ? Commons.Color.background
            : popupWin.tomlBg)

    readonly property color themeFg: (Commons.Color && Commons.Color.popups && Commons.Color.popups.foreground)
        ? Commons.Color.popups.foreground
        : ((Commons.Color && Commons.Color.foreground)
            ? Commons.Color.foreground
            : popupWin.tomlFg)

    readonly property color themeAccent: (Commons.Color && Commons.Color.accent)
        ? Commons.Color.accent
        : popupWin.tomlAccent

    readonly property color themeBorder: (Commons.Color && Commons.Color.popups && Commons.Color.popups.border)
        ? Commons.Color.popups.border
        : Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.16)

    readonly property color themeCardBg: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.05)
    readonly property color themeCardSelectedBg: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.12)
    readonly property color themeMutedFg: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.65)
    readonly property color themeTrackBg: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.18)
    readonly property color themeError: popupWin.tomlError

    function t(key, vars) {
        return I18n.tr(popupWin.localeName, key, vars)
    }

    function open() {
        popupWin.opened = true
        popupWin.anchor.updateAnchor()
        popupWin.runAction(["status"])
    }

    function close() {
        if (!popupWin.opened) return
        popupWin.lastClosedAt = Date.now()
        popupWin.opened = false
    }

    function toggle() {
        if (popupWin.opened) {
            popupWin.close()
        } else if (Date.now() - popupWin.lastClosedAt > 220) {
            popupWin.open()
        }
    }

    anchor.item: popupWin.anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6

    visible: popupWin.opened && popupWin.anchorItem !== null
    color: "transparent"
    implicitWidth: 420
    implicitHeight: Math.min(580, contentCol.implicitHeight + 32)

    HyprlandFocusGrab {
        active: popupWin.visible
        windows: [popupWin]
        onCleared: popupWin.close()
    }

    function runAction(args) {
        if (actionProc.running) return
        popupWin.busy = true
        actionProc.command = ["bash", popupWin.scriptPath].concat(args)
        actionProc.running = true
    }

    function applyState(rawJson) {
        try {
            const data = JSON.parse(rawJson)
            if (data.error) {
                popupWin.statusMessage = data.error
                return
            }
            popupWin.virtualActive = Boolean(data.virtualActive)
            popupWin.virtualVolume = Number(data.virtualVolume ?? 100)
            popupWin.virtualMute = Boolean(data.virtualMute)
            if (data.theme) {
                if (data.theme.background) popupWin.tomlBg = data.theme.background
                if (data.theme.foreground) popupWin.tomlFg = data.theme.foreground
                if (data.theme.accent) popupWin.tomlAccent = data.theme.accent
                else if (data.theme.color4) popupWin.tomlAccent = data.theme.color4
                if (data.theme.color1) popupWin.tomlError = data.theme.color1
            }
            popupWin.sinks = Array.isArray(data.sinks) ? data.sinks : []
            popupWin.statusMessage = ""
            if (popupWin.hostWidget && popupWin.hostWidget.refreshStatus) {
                popupWin.hostWidget.refreshStatus()
            }
        } catch (e) {
            popupWin.statusMessage = popupWin.t("statusReadError")
        }
    }

    function selectedSinkNames() {
        return popupWin.sinks.filter(s => s.selected).map(s => s.name)
    }

    function toggleSinkSelection(sinkName) {
        const updated = popupWin.sinks.map(s => {
            if (s.name === sinkName) {
                return Object.assign({}, s, { selected: !s.selected })
            }
            return s
        })
        popupWin.sinks = updated

        const chosen = updated.filter(s => s.selected).map(s => s.name)
        if (popupWin.virtualActive) {
            if (chosen.length >= 2) {
                popupWin.runAction(["enable", chosen.join(",")])
            } else {
                popupWin.runAction(["disable"])
            }
        }
    }

    function toggleVirtualOutput() {
        if (popupWin.virtualActive) {
            popupWin.runAction(["disable"])
            return
        }
        const chosen = popupWin.selectedSinkNames()
        if (chosen.length < 2) {
            popupWin.statusMessage = popupWin.t("needTwoDevices")
            return
        }
        popupWin.runAction(["enable", chosen.join(",")])
    }

    function iconGlyph(kind) {
        switch (kind) {
            case "bluetooth": return "󰂯"
            case "headphones": return "󰋋"
            case "usb": return "󰕓"
            case "hdmi": return "󰍹"
            default: return "󰓃"
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                popupWin.busy = false
                popupWin.applyState(this.text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                popupWin.busy = false
                if (this.text && this.text.trim().length > 0) {
                    popupWin.statusMessage = this.text.trim()
                }
            }
        }
    }

    // Wiederverwendbarer Slider im System-Theme
    component ThemeSlider: Item {
        id: sliderRoot
        property int value: 100
        property int maximum: 150
        property bool enabledControl: true
        signal valueChangedByUser(int newValue)
        signal valueCommitted(int newValue)

        implicitHeight: 22

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: popupWin.themeTrackBg
            opacity: sliderRoot.enabledControl ? 1.0 : 0.4

            Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * (sliderRoot.value / sliderRoot.maximum)))
                height: parent.height
                radius: 3
                color: popupWin.themeAccent
            }
        }

        Rectangle {
            id: thumb
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * (sliderRoot.value / sliderRoot.maximum)))
            color: popupWin.themeAccent
            border.width: 2
            border.color: popupWin.themeBg
            opacity: sliderRoot.enabledControl ? 1.0 : 0.45
        }

        MouseArea {
            anchors.fill: parent
            enabled: sliderRoot.enabledControl
            cursorShape: Qt.PointingHandCursor
            function updateFromX(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / Math.max(1, width)))
                var nextVal = Math.round(ratio * sliderRoot.maximum)
                sliderRoot.valueChangedByUser(nextVal)
                return nextVal
            }
            onPressed: (mouse) => updateFromX(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed) updateFromX(mouse.x)
            }
            onReleased: (mouse) => {
                var val = updateFromX(mouse.x)
                sliderRoot.valueCommitted(val)
            }
        }
    }

    Rectangle {
        id: cardRoot
        anchors.fill: parent
        radius: 14
        color: popupWin.themeBg
        border.width: 1
        border.color: popupWin.themeBorder
        focus: popupWin.opened

        Keys.onEscapePressed: popupWin.close()

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Kopfzeile: Titel + Aktualisieren + Master-Switch
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: popupWin.t("widgetTitle")
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: popupWin.themeFg
                    }

                    Text {
                        text: popupWin.virtualActive
                            ? popupWin.t("widgetSubtitleActive", { count: popupWin.selectedSinkNames().length })
                            : popupWin.t("widgetSubtitleIdle")
                        font.pixelSize: 12
                        color: popupWin.virtualActive ? popupWin.themeAccent : popupWin.themeMutedFg
                    }
                }

                // Aktualisieren-Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 7
                    color: refreshMouse.containsMouse ? popupWin.themeCardBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        font.pixelSize: 15
                        color: popupWin.themeMutedFg
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popupWin.runAction(["status"])
                    }
                }

                // Custom Theme Switch
                Rectangle {
                    id: masterSwitch
                    property bool canToggle: popupWin.virtualActive || popupWin.selectedSinkNames().length >= 2
                    width: 44
                    height: 24
                    radius: 12
                    opacity: canToggle ? 1.0 : 0.4
                    color: popupWin.virtualActive ? popupWin.themeAccent : popupWin.themeTrackBg

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: popupWin.virtualActive ? parent.width - width - 3 : 3
                        color: popupWin.virtualActive ? popupWin.themeBg : popupWin.themeFg

                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: masterSwitch.canToggle
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popupWin.toggleVirtualOutput()
                    }
                }
            }

            // Master-Lautstaerke fuer den virtuellen Ausgang
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: masterCol.implicitHeight + 20
                radius: 10
                color: popupWin.virtualActive ? popupWin.themeCardSelectedBg : popupWin.themeCardBg
                border.width: 1
                border.color: popupWin.virtualActive ? popupWin.themeAccent : popupWin.themeBorder

                ColumnLayout {
                    id: masterCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: popupWin.t("masterVolume")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: popupWin.themeFg
                        }

                        Text {
                            text: popupWin.virtualMute ? popupWin.t("mute") : (popupWin.virtualVolume + " %")
                            font.pixelSize: 12
                            font.family: "JetBrains Mono"
                            color: popupWin.themeMutedFg
                        }

                        Rectangle {
                            width: 28
                            height: 26
                            radius: 6
                            color: masterMuteMouse.containsMouse ? popupWin.themeTrackBg : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: popupWin.virtualMute ? "󰖁" : "󰕾"
                                font.pixelSize: 14
                                color: popupWin.virtualMute ? popupWin.themeError : popupWin.themeFg
                            }

                            MouseArea {
                                id: masterMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popupWin.runAction(["toggle-master-mute"])
                            }
                        }
                    }

                    ThemeSlider {
                        Layout.fillWidth: true
                        value: popupWin.virtualVolume
                        enabledControl: !popupWin.virtualMute
                        onValueChangedByUser: (val) => {
                            popupWin.virtualVolume = val
                        }
                        onValueCommitted: (val) => {
                            popupWin.runAction(["set-master-volume", String(val)])
                        }
                    }
                }
            }

            Text {
                text: popupWin.t("outputsHeading")
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: popupWin.themeMutedFg
            }

            // Liste aller Ausgabegeraete mit Auswahl + eigenem Lautstaerke-Slider
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(280, Math.max(120, popupWin.sinks.length * 88))
                clip: true
                model: popupWin.sinks
                spacing: 8

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: deviceCol.implicitHeight + 18
                    radius: 10
                    color: modelData.selected ? popupWin.themeCardSelectedBg : popupWin.themeCardBg
                    border.width: 1
                    border.color: modelData.selected ? popupWin.themeAccent : popupWin.themeBorder

                    ColumnLayout {
                        id: deviceCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Custom Theme CheckBox
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 5
                                color: modelData.selected ? popupWin.themeAccent : "transparent"
                                border.width: 1.5
                                border.color: modelData.selected ? popupWin.themeAccent : popupWin.themeMutedFg

                                Text {
                                    visible: Boolean(modelData.selected)
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: popupWin.themeBg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popupWin.toggleSinkSelection(modelData.name)
                                }
                            }

                            Text {
                                text: popupWin.iconGlyph(modelData.icon)
                                font.pixelSize: 15
                                color: modelData.selected ? popupWin.themeAccent : popupWin.themeMutedFg
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.weight: modelData.selected ? Font.DemiBold : Font.Normal
                                color: popupWin.themeFg
                            }

                            Text {
                                text: modelData.mute ? popupWin.t("mute") : (modelData.volume + " %")
                                font.pixelSize: 12
                                font.family: "JetBrains Mono"
                                color: popupWin.themeMutedFg
                            }

                            Rectangle {
                                width: 28
                                height: 26
                                radius: 6
                                color: devMuteMouse.containsMouse ? popupWin.themeTrackBg : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.mute ? "󰖁" : "󰕾"
                                    font.pixelSize: 14
                                    color: modelData.mute ? popupWin.themeError : popupWin.themeFg
                                }

                                MouseArea {
                                    id: devMuteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popupWin.runAction(["toggle-mute", modelData.name])
                                }
                            }
                        }

                        ThemeSlider {
                            Layout.fillWidth: true
                            value: modelData.volume
                            enabledControl: !modelData.mute
                            onValueChangedByUser: (val) => {
                                popupWin.sinks = popupWin.sinks.map(s =>
                                    s.name === modelData.name ? Object.assign({}, s, { volume: val }) : s
                                )
                            }
                            onValueCommitted: (val) => {
                                popupWin.runAction(["set-volume", modelData.name, String(val)])
                            }
                        }
                    }
                }
            }

            // Status / Hinweiszeile
            Text {
                visible: popupWin.statusMessage.length > 0 || popupWin.selectedSinkNames().length < 2
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: popupWin.statusMessage.length > 0 ? popupWin.themeError : popupWin.themeMutedFg
                text: popupWin.statusMessage.length > 0
                    ? popupWin.statusMessage
                    : popupWin.t("hintMinTwo")
            }
        }
    }
}
