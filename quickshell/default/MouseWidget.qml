import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Standalone widget (independent of Bar.qml, same pattern as ThemeWidget.qml), top-left
// corner of the primary screen, right of ThemeWidget's icon row. Click opens Razer mouse
// controls (DPI/poll rate/idle time/low-battery threshold) via openrazer - hidden
// entirely if no Razer device is found, so it's a no-op for anyone without one.
PanelWindow {
    id: widget
    screen: Quickshell.screens.find(function (s) { return s.name === "DP-1" }) || Quickshell.screens[0]
    anchors { top: true; left: true }
    // Stacked below ThemeWidget (own top:10, height 34) instead of next to it: these are
    // independent top-level components with no built-in cross-file layout binding, so a
    // side-by-side left offset would have to guess ThemeWidget's width instead of just
    // its height - which is fixed, so stacking by row is the one that stays aligned
    // regardless of how wide any of these ever get.
    margins { top: 50; left: 10 }
    implicitWidth: visible ? row.implicitWidth + 16 : 0
    implicitHeight: 34
    visible: available
    color: "transparent"
    WlrLayershell.namespace: "mouse-widget"
    WlrLayershell.layer: WlrLayer.Bottom

    readonly property bool isGerman: Qt.locale().name.startsWith("de")
    readonly property string scriptsDir: Quickshell.shellDir + "/scripts"
    readonly property string themeDir: Quickshell.env("HOME") + "/.config/theme"

    property bool settingsOpen: false

    property bool available: false
    property string mouseName: ""
    property int batteryPct: 0
    property bool charging: false
    readonly property bool batteryLow: available && !charging && batteryPct <= 20
    property int dpi: 0
    property int dpiStage: 0
    property var dpiStages: []
    property int pollRate: 0
    property var supportedPollRates: []
    property int idleTime: 0
    // Hardware-capped at 25 regardless of what's asked for - confirmed by testing every
    // value 0-100 against the real device, not documented anywhere.
    property int lowBatteryThreshold: 0

    // Matches Bar.qml's root.palette defaults - kept separate on purpose, these are two
    // independent top-level components (see margins comment above).
    property var palette: ({
        accent: "#1793d1", foreground: "#c0caf5", color1: "#f7768e", color2: "#a6e3a1",
        color8: "#565f89", popup_color: "#1a1b26",
    })
    property real popupOpacity: 0.90

    function argb(hex, alpha) {
        var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255).toString(16).padStart(2, "0")
        return "#" + a + hex.toString().replace("#", "")
    }

    function applyStatus(d) {
        available = !!d.available
        if (!available) return
        mouseName = d.name
        batteryPct = d.pct
        charging = !!d.charging
        dpi = d.dpi
        dpiStage = d.dpi_stage
        dpiStages = d.dpi_stages
        pollRate = d.poll_rate
        supportedPollRates = d.supported_poll_rates
        idleTime = d.idle_time
        lowBatteryThreshold = d.low_battery_threshold
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
        command: ["python3", widget.scriptsDir + "/mouse.py", "status"]
        stdout: StdioCollector { id: statusCollector }
        onExited: {
            try { widget.applyStatus(JSON.parse(statusCollector.text)) }
            catch (e) { widget.available = false }
        }
    }

    // Re-run statusProc, then apply the fresh state - shared by every set-* control in
    // the popup, so each one's write is followed by a real read instead of just
    // assuming it took.
    Process {
        id: setProc
        stdout: StdioCollector { id: setCollector }
        onExited: {
            try { widget.applyStatus(JSON.parse(setCollector.text)) }
            catch (e) {}
        }
    }

    function set(args) {
        setProc.command = ["python3", widget.scriptsDir + "/mouse.py"].concat(args)
        setProc.running = true
    }

    // 60s, not 1s: querying openrazer's daemon over D-Bus is much heavier than reading
    // /proc, and a mouse's battery doesn't change fast enough to need more than that.
    Timer { interval: 300; running: true; repeat: false; onTriggered: { widget.refreshPalette(); statusProc.running = true } }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: statusProc.running = true }

    Rectangle {
        anchors.fill: parent
        radius: 10
        // Same resting look as ThemeWidget's own icon row (subtle fill + border, not
        // just transparent-until-hover) - all these corner widgets should read as one
        // family at a glance, not as one themed button next to one plain-looking one.
        color: (mouseArea.containsMouse || widget.settingsOpen) ? widget.palette.accent : Qt.rgba(0.161, 0.204, 0.298, 0.14)
        border.width: 1
        border.color: Qt.rgba(0.478, 0.635, 0.969, 0.4)

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4
            leftPadding: 4
            rightPadding: 4

            Text {
                text: "󰍽"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: (mouseArea.containsMouse || widget.settingsOpen) ? "#0f111a" : (widget.batteryLow ? widget.palette.color1 : widget.palette.color2)
            }
            Text {
                text: widget.batteryPct + "%" + (widget.charging ? "" : "")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: (mouseArea.containsMouse || widget.settingsOpen) ? "#0f111a" : widget.palette.foreground
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                widget.settingsOpen = !widget.settingsOpen
                if (widget.settingsOpen) widget.refreshPalette()
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
            implicitWidth: 280
            implicitHeight: settingsCol.implicitHeight + 24
            color: "transparent"
            WlrLayershell.namespace: "mouse-widget-settings"
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

                ColumnLayout {
                    id: settingsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: widget.mouseName
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        color: widget.palette.foreground
                        elide: Text.ElideRight
                    }

                    // ---- DPI stages ----
                    Text {
                        text: "DPI (" + widget.dpi + ")"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: widget.palette.color8
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: widget.dpiStages

                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool active: index === widget.dpiStage
                                width: dpiLabel.implicitWidth + 14
                                height: 24
                                radius: 8
                                color: active ? widget.palette.accent : (dpiArea.containsMouse ? widget.argb(widget.palette.color8, 0.35) : "transparent")
                                border.width: 1
                                border.color: active ? widget.palette.accent : widget.palette.color8

                                Text {
                                    id: dpiLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: active ? "#0f111a" : widget.palette.foreground
                                }

                                MouseArea {
                                    id: dpiArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: widget.set(["set-dpi-stage", index.toString()])
                                }
                            }
                        }
                    }

                    // ---- poll rate ----
                    Text {
                        text: (widget.isGerman ? "Abfragerate" : "Poll rate") + " (" + widget.pollRate + " Hz)"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: widget.palette.color8
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: widget.supportedPollRates

                            Rectangle {
                                required property var modelData
                                readonly property bool active: modelData === widget.pollRate
                                width: pollLabel.implicitWidth + 14
                                height: 24
                                radius: 8
                                color: active ? widget.palette.accent : (pollArea.containsMouse ? widget.argb(widget.palette.color8, 0.35) : "transparent")
                                border.width: 1
                                border.color: active ? widget.palette.accent : widget.palette.color8

                                Text {
                                    id: pollLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: active ? "#0f111a" : widget.palette.foreground
                                }

                                MouseArea {
                                    id: pollArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: widget.set(["set-poll-rate", modelData.toString()])
                                }
                            }
                        }
                    }

                    // ---- idle time (wireless sleep timeout, 60-900s) ----
                    Text {
                        text: (widget.isGerman ? "Ruhezustand nach" : "Sleep after") + " " + widget.idleTime + "s"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: widget.palette.color8
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        readonly property real shownValue: idleTrack.pressed ? idleDragValue : (widget.idleTime - 60) / (900 - 60)
                        property real idleDragValue: 0

                        Rectangle {
                            id: idleSliderTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: idleSliderTrack.width * Math.max(0, Math.min(1, parent.shownValue))
                            height: 6
                            radius: 3
                            color: widget.palette.accent
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(idleSliderTrack.width, idleSliderTrack.width * parent.shownValue)) - width / 2
                            width: 14; height: 14
                            radius: 7
                            color: widget.palette.foreground
                            border.width: idleTrack.pressed ? 2 : 0
                            border.color: widget.palette.accent
                        }

                        MouseArea {
                            id: idleTrack
                            anchors.fill: parent
                            preventStealing: true

                            function valueAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
                            onPressed: (mouse) => { parent.idleDragValue = valueAt(mouse.x) }
                            onPositionChanged: (mouse) => { if (pressed) parent.idleDragValue = valueAt(mouse.x) }
                            onReleased: {
                                var seconds = Math.round(60 + parent.idleDragValue * (900 - 60))
                                widget.set(["set-idle-time", seconds.toString()])
                            }
                        }
                    }

                    // ---- low battery threshold (hardware-capped at 25%) ----
                    Text {
                        text: (widget.isGerman ? "Akku-Warnung bei" : "Low battery warning at") + " " + widget.lowBatteryThreshold + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: widget.palette.color8
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        readonly property real shownValue: battTrack.pressed ? battDragValue : widget.lowBatteryThreshold / 25
                        property real battDragValue: 0

                        Rectangle {
                            id: battSliderTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: battSliderTrack.width * Math.max(0, Math.min(1, parent.shownValue))
                            height: 6
                            radius: 3
                            color: widget.palette.accent
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(battSliderTrack.width, battSliderTrack.width * parent.shownValue)) - width / 2
                            width: 14; height: 14
                            radius: 7
                            color: widget.palette.foreground
                            border.width: battTrack.pressed ? 2 : 0
                            border.color: widget.palette.accent
                        }

                        MouseArea {
                            id: battTrack
                            anchors.fill: parent
                            preventStealing: true

                            function valueAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
                            onPressed: (mouse) => { parent.battDragValue = valueAt(mouse.x) }
                            onPositionChanged: (mouse) => { if (pressed) parent.battDragValue = valueAt(mouse.x) }
                            onReleased: {
                                var pct = Math.round(parent.battDragValue * 25)
                                widget.set(["set-low-battery-threshold", pct.toString()])
                            }
                        }
                    }
                }
            }
        }
    }
}
