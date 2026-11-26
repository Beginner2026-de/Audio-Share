import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "i18n.js" as I18n

Rectangle {
    id: panelRoot

    property var pluginApi: null

    property string localeName: Qt.locale().name
    property bool virtualActive: false
    property int virtualVolume: 100
    property bool virtualMute: false
    property var sinks: []
    property bool busy: false
    property string statusMessage: ""
    property string scriptPath: Qt.resolvedUrl("scripts/audio-share.sh").toString().replace("file://", "")

    function t(key, vars) {
        return I18n.tr(panelRoot.localeName, key, vars)
    }

    implicitWidth: 420
    implicitHeight: Math.min(580, contentCol.implicitHeight + 32)
    radius: 14
    color: Commons.Color.surface
    border.width: 1
    border.color: Commons.Color.outline

    function runAction(args) {
        if (actionProc.running) return
        panelRoot.busy = true
        actionProc.command = ["bash", panelRoot.scriptPath].concat(args)
        actionProc.running = true
    }

    function applyState(rawJson) {
        try {
            const data = JSON.parse(rawJson)
            if (data.error) {
                panelRoot.statusMessage = data.error
                return
            }
            panelRoot.virtualActive = Boolean(data.virtualActive)
            panelRoot.virtualVolume = Number(data.virtualVolume ?? 100)
            panelRoot.virtualMute = Boolean(data.virtualMute)
            panelRoot.sinks = Array.isArray(data.sinks) ? data.sinks : []
            panelRoot.statusMessage = ""
        } catch (e) {
            panelRoot.statusMessage = panelRoot.t("statusReadError")
        }
    }

    function selectedSinkNames() {
        return panelRoot.sinks.filter(s => s.selected).map(s => s.name)
    }

    function toggleSinkSelection(sinkName) {
        const updated = panelRoot.sinks.map(s => {
            if (s.name === sinkName) {
                return Object.assign({}, s, { selected: !s.selected })
            }
            return s
        })
        panelRoot.sinks = updated

        const chosen = updated.filter(s => s.selected).map(s => s.name)
        if (panelRoot.virtualActive) {
            if (chosen.length >= 2) {
                panelRoot.runAction(["enable", chosen.join(",")])
            } else {
                panelRoot.runAction(["disable"])
            }
        }
    }

    function toggleVirtualOutput() {
        if (panelRoot.virtualActive) {
            panelRoot.runAction(["disable"])
            return
        }
        const chosen = panelRoot.selectedSinkNames()
        if (chosen.length < 2) {
            panelRoot.statusMessage = panelRoot.t("needTwoDevices")
            return
        }
        panelRoot.runAction(["enable", chosen.join(",")])
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

    Component.onCompleted: runAction(["status"])

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                panelRoot.busy = false
                panelRoot.applyState(this.text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                panelRoot.busy = false
                if (this.text && this.text.trim().length > 0) {
                    panelRoot.statusMessage = this.text.trim()
                }
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Kopfzeile: Titel + Master-Switch fuer den virtuellen Ausgang
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: panelRoot.t("widgetTitle")
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: Commons.Color.onSurface
                }

                Text {
                    text: panelRoot.virtualActive
                        ? panelRoot.t("widgetSubtitleActive", { count: panelRoot.selectedSinkNames().length })
                        : panelRoot.t("widgetSubtitleIdle")
                    font.pixelSize: 12
                    color: panelRoot.virtualActive ? Commons.Color.primary : Commons.Color.onSurfaceVariant
                }
            }

            Button {
                text: panelRoot.t("refresh")
                flat: true
                font.pixelSize: 12
                onClicked: panelRoot.runAction(["status"])
            }

            Switch {
                checked: panelRoot.virtualActive
                enabled: panelRoot.virtualActive || panelRoot.selectedSinkNames().length >= 2
                onToggled: panelRoot.toggleVirtualOutput()
            }
        }

        // Master-Lautstaerke fuer den virtuellen Ausgang
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: masterCol.implicitHeight + 20
            radius: 10
            color: Commons.Color.surfaceVariant
            border.width: 1
            border.color: panelRoot.virtualActive ? Commons.Color.primary : Commons.Color.outline

            ColumnLayout {
                id: masterCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: panelRoot.t("masterVolume")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Commons.Color.onSurface
                    }

                    Text {
                        text: panelRoot.virtualMute ? panelRoot.t("mute") : (panelRoot.virtualVolume + " %")
                        font.pixelSize: 12
                        font.family: "JetBrains Mono"
                        color: Commons.Color.onSurfaceVariant
                    }

                    Button {
                        text: panelRoot.virtualMute ? "󰖁" : "󰕾"
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 28
                        onClicked: panelRoot.runAction(["toggle-master-mute"])
                    }
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 150
                    stepSize: 1
                    value: panelRoot.virtualVolume
                    onMoved: {
                        panelRoot.virtualVolume = Math.round(value)
                    }
                    onPressedChanged: {
                        if (!pressed) {
                            panelRoot.runAction(["set-master-volume", String(Math.round(value))])
                        }
                    }
                }
            }
        }

        Text {
            text: panelRoot.t("outputsHeading")
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Commons.Color.onSurfaceVariant
        }

        // Liste aller Ausgabegeraete mit Auswahl + eigenem Lautstaerke-Slider
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(280, Math.max(120, panelRoot.sinks.length * 88))
            clip: true

            ListView {
                model: panelRoot.sinks
                spacing: 8

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: deviceCol.implicitHeight + 18
                    radius: 10
                    color: modelData.selected ? Commons.Color.surfaceContainerHigh : Commons.Color.surfaceVariant
                    border.width: 1
                    border.color: modelData.selected ? Commons.Color.primary : Commons.Color.outline

                    ColumnLayout {
                        id: deviceCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            CheckBox {
                                checked: Boolean(modelData.selected)
                                onToggled: panelRoot.toggleSinkSelection(modelData.name)
                            }

                            Text {
                                text: panelRoot.iconGlyph(modelData.icon)
                                font.pixelSize: 15
                                color: modelData.selected ? Commons.Color.primary : Commons.Color.onSurfaceVariant
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.weight: modelData.selected ? Font.DemiBold : Font.Normal
                                color: Commons.Color.onSurface
                            }

                            Text {
                                text: modelData.mute ? panelRoot.t("mute") : (modelData.volume + " %")
                                font.pixelSize: 12
                                font.family: "JetBrains Mono"
                                color: Commons.Color.onSurfaceVariant
                            }

                            Button {
                                text: modelData.mute ? "󰖁" : "󰕾"
                                flat: true
                                implicitWidth: 32
                                implicitHeight: 28
                                onClicked: panelRoot.runAction(["toggle-mute", modelData.name])
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: 150
                            stepSize: 1
                            value: modelData.volume
                            enabled: !modelData.mute
                            onPressedChanged: {
                                if (!pressed) {
                                    panelRoot.runAction(["set-volume", modelData.name, String(Math.round(value))])
                                }
                            }
                        }
                    }
                }
            }
        }

        // Status / Hinweiszeile
        Text {
            visible: panelRoot.statusMessage.length > 0 || panelRoot.selectedSinkNames().length < 2
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: panelRoot.statusMessage.length > 0 ? Commons.Color.error : Commons.Color.onSurfaceVariant
            text: panelRoot.statusMessage.length > 0
                ? panelRoot.statusMessage
                : panelRoot.t("hintMinTwo")
        }
    }
}
