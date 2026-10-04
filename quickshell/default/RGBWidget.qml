import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Standalone widget (independent of Bar.qml, same pattern as ThemeWidget.qml/
// MouseWidget.qml), top-left corner, right of MouseWidget's icon. Click opens RAM/GPU/
// mainboard RGB controls (mode per device, one-click sync to the palette's accent) via
// OpenRGB's SDK server - hidden entirely if that server isn't reachable, so it's a
// no-op on a machine without these devices or without openrgb/openrgb-python installed.
PanelWindow {
    id: widget
    screen: Quickshell.screens.find(function (s) { return s.name === "DP-1" }) || Quickshell.screens[0]
    anchors { top: true; left: true }
    // Same row as MouseWidget (own top:50), to its right - estimated past its icon +
    // up-to-3-digit percentage text (~80px) + a gap, not computed off it directly: two
    // independent top-level components, no built-in cross-file layout binding. Narrower
    // than MouseWidget's own content would leave a gap here instead of misaligning it.
    margins { top: 50; left: 76 }
    implicitWidth: visible ? 30 : 0
    implicitHeight: 34
    visible: available
    color: "transparent"
    WlrLayershell.namespace: "rgb-widget"
    WlrLayershell.layer: WlrLayer.Bottom

    readonly property bool isGerman: Qt.locale().name.startsWith("de")
    readonly property string scriptsDir: Quickshell.shellDir + "/scripts"
    readonly property string themeDir: Quickshell.env("HOME") + "/.config/theme"

    property bool settingsOpen: false
    property bool available: false
    property var devices: []
    // devices, but every DRAM entry (both RAM sticks, same model) collapsed into one -
    // one card, one set of controls, applied to both via set-*'s comma-separated ids.
    // Keyed by "ids" (always a list, even for a single device) instead of "id" from
    // here on, so the rest of the UI doesn't need two separate code paths.
    readonly property var groupedDevices: {
        var dram = devices.filter(function (d) { return d.type === "DRAM" })
        var rest = devices.filter(function (d) { return d.type !== "DRAM" })
        var out = rest.map(function (d) {
            var g = Object.assign({}, d); g.ids = [d.id]; return g
        })
        if (dram.length > 0) {
            var g = Object.assign({}, dram[0])
            g.ids = dram.map(function (d) { return d.id })
            if (dram.length > 1) g.name = g.name + " (×" + dram.length + ")"
            out.unshift(g)
        }
        return out
    }
    property string editingDeviceIds: ""
    property string hexInput: ""

    // Matches Bar.qml's root.palette defaults - kept separate on purpose, see
    // MouseWidget.qml's identical property for why.
    property var palette: ({ accent: "#1793d1", foreground: "#c0caf5", color8: "#565f89", popup_color: "#1a1b26" })
    property real popupOpacity: 0.90

    function argb(hex, alpha) {
        var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255).toString(16).padStart(2, "0")
        return "#" + a + hex.toString().replace("#", "")
    }

    function applyStatus(d) {
        available = !!d.available
        if (available) devices = d.devices
    }

    function refreshPalette() { paletteDump.running = true }

    Process {
        id: paletteDump
        command: ["python3", widget.themeDir + "/render.py", "--dump"]
        stdout: StdioCollector { id: paletteDumpCollector }
        onExited: {
            try {
                var c = JSON.parse(paletteDumpCollector.text)
                if ("popup_opacity" in c) widget.popupOpacity = c.popup_opacity
                var p = {}
                for (var key in widget.palette) p[key] = (key in c) ? c[key] : widget.palette[key]
                widget.palette = p
            } catch (e) {}
        }
    }

    Process {
        id: statusProc
        command: ["python3", widget.scriptsDir + "/rgb.py", "status"]
        stdout: StdioCollector { id: statusCollector }
        onExited: {
            try { widget.applyStatus(JSON.parse(statusCollector.text)) }
            catch (e) { widget.available = false }
        }
    }

    Process {
        id: setProc
        stdout: StdioCollector { id: setCollector }
        onExited: {
            try { widget.applyStatus(JSON.parse(setCollector.text)) }
            catch (e) {}
        }
    }

    function set(args) {
        setProc.command = ["python3", widget.scriptsDir + "/rgb.py"].concat(args)
        setProc.running = true
    }

    // 60s: these devices don't change state on their own, this just keeps the widget in
    // sync if something else (e.g. OpenRGB's own GUI) changes it in the meantime.
    Timer { interval: 300; running: true; repeat: false; onTriggered: { widget.refreshPalette(); statusProc.running = true } }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: statusProc.running = true }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: (mouseArea.containsMouse || widget.settingsOpen) ? widget.palette.accent : Qt.rgba(0.161, 0.204, 0.298, 0.14)
        border.width: 1
        border.color: Qt.rgba(0.478, 0.635, 0.969, 0.4)

        Text {
            anchors.centerIn: parent
            text: "󰌵"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: (mouseArea.containsMouse || widget.settingsOpen) ? "#0f111a" : widget.palette.accent
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                widget.settingsOpen = !widget.settingsOpen
                if (widget.settingsOpen) { widget.refreshPalette(); statusProc.running = true }
            }
        }
    }

    LazyLoader {
        active: widget.settingsOpen

        PanelWindow {
            id: settingsWindow
            screen: widget.screen
            anchors { top: true; left: true }
            margins { top: 88; left: 10 }
            implicitWidth: 300
            implicitHeight: Math.min(settingsCol.implicitHeight + 24, widget.screen.height - 80)
            color: "transparent"
            WlrLayershell.namespace: "rgb-widget-settings"
            WlrLayershell.layer: WlrLayer.Top

            HyprlandFocusGrab {
                windows: [ settingsWindow ]
                active: true
                onCleared: widget.settingsOpen = false
            }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: widget.argb(widget.palette.popup_color, widget.popupOpacity)
                border.width: 1
                border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    contentWidth: width
                    contentHeight: settingsCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: settingsCol
                        width: parent.width
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 8
                            color: syncAllArea.containsMouse ? Qt.lighter(widget.palette.accent, 1.15) : widget.palette.accent

                            Text {
                                anchors.centerIn: parent
                                text: widget.isGerman ? "Alle auf Accent synchronisieren" : "Sync all to accent"
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                                font.pixelSize: 13
                                color: "#0f111a"
                            }

                            MouseArea {
                                id: syncAllArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widget.set(["sync-accent"])
                            }
                        }

                        Repeater {
                            model: widget.groupedDevices

                            ColumnLayout {
                                id: deviceCol
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: widget.palette.foreground
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 20; height: 20
                                        radius: 6
                                        color: Qt.rgba(modelData.color[0] / 255, modelData.color[1] / 255, modelData.color[2] / 255, 1)
                                        border.width: widget.editingDeviceIds === modelData.ids.join(",") ? 2 : 1
                                        border.color: widget.editingDeviceIds === modelData.ids.join(",") ? widget.palette.accent : Qt.rgba(1, 1, 1, 0.3)

                                        MouseArea {
                                            id: swatchArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (widget.editingDeviceIds === modelData.ids.join(",")) {
                                                    widget.editingDeviceIds = ""
                                                } else {
                                                    widget.editingDeviceIds = modelData.ids.join(",")
                                                    widget.hexInput = "#" + modelData.color.map(function (v) {
                                                        return v.toString(16).padStart(2, "0")
                                                    }).join("")
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: widget.editingDeviceIds === deviceCol.modelData.ids.join(",")

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        radius: 6
                                        color: "#0f111a"
                                        border.width: 1
                                        border.color: Qt.rgba(0.478, 0.635, 0.969, 0.3)

                                        TextInput {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: widget.hexInput
                                            onTextEdited: widget.hexInput = text
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: widget.palette.foreground
                                            maximumLength: 7
                                            selectByMouse: true
                                            validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 28
                                        radius: 6
                                        readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(widget.hexInput)
                                        color: !valid ? Qt.rgba(1, 1, 1, 0.08) : (applyArea.containsMouse ? Qt.lighter(widget.palette.accent, 1.15) : widget.palette.accent)
                                        opacity: valid ? 1.0 : 0.5

                                        Text {
                                            anchors.centerIn: parent
                                            text: widget.isGerman ? "OK" : "OK"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: "#0f111a"
                                        }

                                        MouseArea {
                                            id: applyArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: parent.valid
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var h = widget.hexInput.replace("#", "")
                                                var r = parseInt(h.slice(0, 2), 16)
                                                var g = parseInt(h.slice(2, 4), 16)
                                                var b = parseInt(h.slice(4, 6), 16)
                                                widget.set(["set-color", deviceCol.modelData.ids.join(","), r.toString(), g.toString(), b.toString()])
                                                widget.editingDeviceIds = ""
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: modelData.modes

                                        Rectangle {
                                            // Named-id reference, not modelData.whatever: this delegate's own
                                            // `required property var modelData` (the mode) shadows the outer
                                            // ColumnLayout's identically-named one (the device) - deviceCol.modelData
                                            // reaches it by id instead, which shadowing doesn't affect.
                                            required property var modelData
                                            readonly property bool active: modelData.id === deviceCol.modelData.active_mode
                                            width: modeLabel.implicitWidth + 12
                                            height: 22
                                            radius: 7
                                            color: active ? widget.palette.accent : (modeArea.containsMouse ? widget.argb(widget.palette.color8, 0.35) : "transparent")
                                            border.width: 1
                                            border.color: active ? widget.palette.accent : widget.palette.color8

                                            Text {
                                                id: modeLabel
                                                anchors.centerIn: parent
                                                text: modelData.name
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                color: active ? "#0f111a" : widget.palette.foreground
                                            }

                                            MouseArea {
                                                id: modeArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: widget.set(["set-mode", deviceCol.modelData.ids.join(","), modelData.id.toString()])
                                            }
                                        }
                                    }
                                }

                                // Speed/brightness: only the device's *currently active* mode's
                                // own range matters (most modes have both, Direct never does on
                                // any of these three devices - see rgb.py's set_param()).
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: deviceCol.modelData.speed_min !== null && deviceCol.modelData.speed_max !== null

                                    Text {
                                        text: widget.isGerman ? "Tempo" : "Speed"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: widget.palette.color8
                                        Layout.preferredWidth: 42
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18

                                        readonly property int vmin: deviceCol.modelData.speed_min || 0
                                        readonly property int vmax: deviceCol.modelData.speed_max || 1
                                        readonly property real shownValue: speedTrack.pressed ? speedDragValue : (deviceCol.modelData.speed - vmin) / Math.max(1, vmax - vmin)
                                        property real speedDragValue: 0

                                        Rectangle {
                                            id: speedSliderTrack
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width; height: 5; radius: 2.5
                                            color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: speedSliderTrack.width * Math.max(0, Math.min(1, parent.shownValue))
                                            height: 5; radius: 2.5
                                            color: widget.palette.accent
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(speedSliderTrack.width, speedSliderTrack.width * parent.shownValue)) - width / 2
                                            width: 12; height: 12; radius: 6
                                            color: widget.palette.foreground
                                            border.width: speedTrack.pressed ? 2 : 0
                                            border.color: widget.palette.accent
                                        }

                                        MouseArea {
                                            id: speedTrack
                                            anchors.fill: parent
                                            preventStealing: true
                                            function valueAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
                                            onPressed: (mouse) => { parent.speedDragValue = valueAt(mouse.x) }
                                            onPositionChanged: (mouse) => { if (pressed) parent.speedDragValue = valueAt(mouse.x) }
                                            onReleased: {
                                                var v = Math.round(parent.vmin + parent.speedDragValue * (parent.vmax - parent.vmin))
                                                widget.set(["set-speed", deviceCol.modelData.ids.join(","), v.toString()])
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: deviceCol.modelData.brightness_min !== null && deviceCol.modelData.brightness_max !== null

                                    Text {
                                        text: widget.isGerman ? "Helligk." : "Bright."
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: widget.palette.color8
                                        Layout.preferredWidth: 42
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18

                                        readonly property int vmin: deviceCol.modelData.brightness_min || 0
                                        readonly property int vmax: deviceCol.modelData.brightness_max || 1
                                        readonly property real shownValue: brightTrack.pressed ? brightDragValue : (deviceCol.modelData.brightness - vmin) / Math.max(1, vmax - vmin)
                                        property real brightDragValue: 0

                                        Rectangle {
                                            id: brightSliderTrack
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width; height: 5; radius: 2.5
                                            color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: brightSliderTrack.width * Math.max(0, Math.min(1, parent.shownValue))
                                            height: 5; radius: 2.5
                                            color: widget.palette.accent
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(brightSliderTrack.width, brightSliderTrack.width * parent.shownValue)) - width / 2
                                            width: 12; height: 12; radius: 6
                                            color: widget.palette.foreground
                                            border.width: brightTrack.pressed ? 2 : 0
                                            border.color: widget.palette.accent
                                        }

                                        MouseArea {
                                            id: brightTrack
                                            anchors.fill: parent
                                            preventStealing: true
                                            function valueAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
                                            onPressed: (mouse) => { parent.brightDragValue = valueAt(mouse.x) }
                                            onPositionChanged: (mouse) => { if (pressed) parent.brightDragValue = valueAt(mouse.x) }
                                            onReleased: {
                                                var v = Math.round(parent.vmin + parent.brightDragValue * (parent.vmax - parent.vmin))
                                                widget.set(["set-brightness", deviceCol.modelData.ids.join(","), v.toString()])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
