import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Standalone widget (independent of Bar.qml), top-left corner of the primary screen.
// Replaces the "aether" GUI app: two buttons open a wallpaper picker and a color-role
// editor that write straight into theme/colors.toml and theme/wallpaper.py's archive,
// then theme/render.py re-renders every themed app's config and reloads it.
PanelWindow {
    id: widget
    // DP-1 is the main monitor in this rice (see Bar.qml's workspaceIds); fall back to
    // whatever's first so the widget still shows up on a single-monitor setup.
    screen: Quickshell.screens.find(function (s) { return s.name === "DP-1" }) || Quickshell.screens[0]
    anchors { top: true; left: true }
    margins { top: 10; left: 10 }
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 34
    color: "transparent"
    WlrLayershell.namespace: "theme-widget"
    // Bottom, not Top: this sits on the desktop, not over normal windows. The popups below
    // stay on Top since they only show up while the widget itself is visibly reachable.
    WlrLayershell.layer: WlrLayer.Bottom

    readonly property bool isGerman: Qt.locale().name.startsWith("de")
    readonly property string themeDir: "/home/nico/.config/theme"

    property bool wallpaperOpen: false
    property bool colorsOpen: false
    property bool presetsOpen: false
    property var wallpapers: []

    // ---- presets: named snapshots of the whole palette (theme/presets.py) ----
    property var presetsDefault: ({ name: "Default", current: true })
    property var presetsList: []
    property string presetNameInput: ""

    // ---- color roles: key -> current hex, kept in sync with theme/colors.toml ----
    property var colorValues: ({})
    readonly property real popupOpacity: colorValues.popup_opacity !== undefined ? colorValues.popup_opacity : 0.90
    readonly property string popupColor: colorValues.popup_color !== undefined ? colorValues.popup_color : "#1a1b26"

    function argb(hex, alpha) {
        var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255).toString(16).padStart(2, "0")
        return "#" + a + hex.slice(1)
    }
    property string editingKey: ""
    property string hexInput: ""

    readonly property var roleOrder: ["accent", "cursor", "foreground", "background",
        "selection_foreground", "selection_background",
        "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7",
        "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"]

    // What each role actually paints, verified against theme/templates/ (border/urgency/accent
    // colors) and the literal hex values hardcoded in Bar.qml (the bar isn't template-driven,
    // its colors were hand-matched to the palette - see the Theming section of README.md).
    // Several ANSI slots aren't wired up to anything yet (background, selection, color0/15) or
    // currently equal their "bright" sibling 1:1 - labelled as such rather than guessed at.
    readonly property var roleLabels: ({
        accent: isGerman ? "Akzent (Hervorhebung)" : "Accent (highlights)",
        cursor: isGerman ? "Cursor (Terminal)" : "Cursor (terminal)",
        foreground: isGerman ? "Vordergrund (Text)" : "Foreground (text)",
        background: isGerman ? "Hintergrund (Terminal, mako)" : "Background (terminal, mako)",
        selection_foreground: isGerman ? "Auswahltext (ungenutzt)" : "Selection text (unused)",
        selection_background: isGerman ? "Auswahlhintergrund (ungenutzt)" : "Selection bg (unused)",
        color0: isGerman ? "Schwarz (ungenutzt)" : "Black (unused)",
        color1: isGerman ? "Rot (kritisch, Badges)" : "Red (critical, badges)",
        color2: isGerman ? "Grün (GPU-Icon, verbunden)" : "Green (GPU icon, connected)",
        color3: isGerman ? "Gelb (Temp-Warnung)" : "Yellow (temp warning)",
        color4: isGerman ? "Blau (Rahmenfarben)" : "Blue (border colors)",
        color5: isGerman ? "Magenta (Lautstärke-Icon)" : "Magenta (volume icon)",
        color6: isGerman ? "Cyan (RAM-Icon)" : "Cyan (RAM icon)",
        color7: isGerman ? "Weiß (= Vordergrund)" : "White (= Foreground)",
        color8: isGerman ? "Gedämpft (inaktiv, Hinweise)" : "Muted (inactive, hints)",
        color9: isGerman ? "Hellrot (= Rot)" : "Bright red (= Red)",
        color10: isGerman ? "Hellgrün (= Grün)" : "Bright green (= Green)",
        color11: isGerman ? "Hellgelb (= Gelb)" : "Bright yellow (= Yellow)",
        color12: isGerman ? "Hellblau (Detailtext, Hilfe)" : "Bright blue (detail text, help)",
        color13: isGerman ? "Hellmagenta (= Magenta)" : "Bright magenta (= Magenta)",
        color14: isGerman ? "Hellcyan (= Cyan)" : "Bright cyan (= Cyan)",
        color15: isGerman ? "Hellweiß (ungenutzt)" : "Bright white (unused)",
        bar_color: isGerman ? "Bar-Hintergrund" : "Bar background",
        pill_color: isGerman ? "Pill-Hintergrund" : "Pill background",
        popup_color: isGerman ? "Popup-Hintergrund" : "Popup background",
    })

    // colorKey pairs each opacity with the color it fades - clicking its swatch jumps into
    // the same role editor (step 2 below) used for every other color.
    readonly property var opacityFields: [
        { key: "bar_opacity", colorKey: "bar_color", label: isGerman ? "Bar" : "Bar" },
        { key: "pill_opacity", colorKey: "pill_color", label: isGerman ? "Pills" : "Pills" },
        { key: "popup_opacity", colorKey: "popup_color", label: isGerman ? "Popups" : "Popups" },
        { key: "terminal_opacity", colorKey: "background", label: isGerman ? "Terminal" : "Terminal" },
    ]

    // A curated set of preset swatches for the color picker - independent of the current
    // theme, so it always offers real alternatives instead of just the colors already in use.
    readonly property var presetPalette: [
        "#f7768e", "#ff9e64", "#f9e2af", "#a6e3a1", "#73daca", "#89dceb",
        "#7aa2f7", "#1793d1", "#7dcfff", "#bb9af7", "#cba6f7", "#f5c2e7",
        "#e0af68", "#9ece6a", "#4fd6be", "#41a6b5", "#3d59a1", "#c0caf5",
        "#565f89", "#414868", "#24283b", "#1a1b26", "#ffffff", "#e6e6e6",
    ]

    function refreshColors() { colorsDump.running = true }
    function refreshWallpapers() { wallpaperList.running = true }
    function refreshPresets() {
        presetsDefaultProc.running = true
        presetsListProc.running = true
    }

    Process {
        id: colorsDump
        command: ["python3", widget.themeDir + "/render.py", "--dump"]
        stdout: StdioCollector { id: colorsDumpCollector }
        onExited: {
            try { widget.colorValues = JSON.parse(colorsDumpCollector.text) } catch (e) {}
        }
    }

    Process {
        id: colorsSet
        stdout: StdioCollector {}
        onExited: widget.refreshColors()
    }

    Process {
        id: opacitySet
        stdout: StdioCollector {}
        onExited: widget.refreshColors()
    }

    Process {
        id: presetsDefaultProc
        command: ["python3", widget.themeDir + "/presets.py", "default"]
        stdout: StdioCollector { id: presetsDefaultCollector }
        onExited: {
            try { widget.presetsDefault = JSON.parse(presetsDefaultCollector.text) } catch (e) {}
        }
    }

    Process {
        id: presetsListProc
        command: ["python3", widget.themeDir + "/presets.py", "list"]
        stdout: StdioCollector { id: presetsListCollector }
        onExited: {
            try { widget.presetsList = JSON.parse(presetsListCollector.text) } catch (e) {}
        }
    }

    Process {
        id: presetsSave
        stdout: StdioCollector {}
        onExited: widget.refreshPresets()
    }

    Process {
        id: presetsLoad
        stdout: StdioCollector {}
        onExited: {
            widget.refreshPresets()
            widget.refreshColors()
        }
    }

    Process {
        id: presetsDelete
        stdout: StdioCollector {}
        onExited: widget.refreshPresets()
    }

    Process {
        id: wallpaperList
        command: ["python3", widget.themeDir + "/wallpaper.py", "list"]
        stdout: StdioCollector { id: wallpaperListCollector }
        onExited: {
            try { widget.wallpapers = JSON.parse(wallpaperListCollector.text) } catch (e) {}
        }
    }

    Process {
        id: wallpaperApply
        stdout: StdioCollector {}
        onExited: widget.refreshWallpapers()
    }

    Process {
        id: wallpaperPick
        command: ["python3", widget.themeDir + "/wallpaper.py", "pick"]
        stdout: StdioCollector {}
        onExited: widget.refreshWallpapers()
    }

    IpcHandler {
        target: "theme-widget"

        function changed(): void {
            widget.refreshColors()
            widget.refreshPresets()
        }
    }

    Component.onCompleted: {
        refreshColors()
        refreshWallpapers()
        refreshPresets()
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.rgba(0.161, 0.204, 0.298, 0.14)
        border.width: 1
        border.color: Qt.rgba(0.478, 0.635, 0.969, 0.4)

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            leftPadding: 2
            rightPadding: 2

            Rectangle {
                width: 30; height: 26
                radius: 8
                color: (wallArea.containsMouse || widget.wallpaperOpen) ? "#1793d1" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: (wallArea.containsMouse || widget.wallpaperOpen) ? "#0f111a" : "#7aa2f7"
                }

                MouseArea {
                    id: wallArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        widget.colorsOpen = false
                        widget.presetsOpen = false
                        widget.wallpaperOpen = !widget.wallpaperOpen
                        if (widget.wallpaperOpen) widget.refreshWallpapers()
                    }
                }
            }

            Rectangle {
                width: 30; height: 26
                radius: 8
                color: (colorArea.containsMouse || widget.colorsOpen) ? "#1793d1" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: (colorArea.containsMouse || widget.colorsOpen) ? "#0f111a" : "#cba6f7"
                }

                MouseArea {
                    id: colorArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        widget.wallpaperOpen = false
                        widget.presetsOpen = false
                        widget.colorsOpen = !widget.colorsOpen
                        if (widget.colorsOpen) {
                            widget.editingKey = ""
                            widget.refreshColors()
                        }
                    }
                }
            }

            Rectangle {
                width: 30; height: 26
                radius: 8
                color: (presetArea.containsMouse || widget.presetsOpen) ? "#1793d1" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: (presetArea.containsMouse || widget.presetsOpen) ? "#0f111a" : "#a6e3a1"
                }

                MouseArea {
                    id: presetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        widget.wallpaperOpen = false
                        widget.colorsOpen = false
                        widget.presetsOpen = !widget.presetsOpen
                        if (widget.presetsOpen) {
                            widget.presetNameInput = ""
                            widget.refreshPresets()
                        }
                    }
                }
            }
        }
    }

    // ================= WALLPAPER POPUP =================
    LazyLoader {
        active: widget.wallpaperOpen

        PanelWindow {
            id: wallWindow
            screen: widget.screen
            anchors { top: true; left: true }
            margins { top: 48; left: 10 }
            implicitWidth: 420
            implicitHeight: wallCol.implicitHeight + 24
            color: "transparent"
            WlrLayershell.namespace: "theme-widget-wallpaper"
            WlrLayershell.layer: WlrLayer.Top

            HyprlandFocusGrab {
                windows: [ wallWindow ]
                active: true
                onCleared: widget.wallpaperOpen = false
            }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: widget.argb(widget.popupColor, widget.popupOpacity)
                border.width: 1
                border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                ColumnLayout {
                    id: wallCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: widget.isGerman ? "Hintergrundbild" : "Wallpaper"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#c0caf5"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 8
                        color: pickArea.containsMouse ? "#1793d1" : Qt.rgba(0.478, 0.635, 0.969, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "  " + (widget.isGerman ? "Neues Bild wählen…" : "Choose new file…")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: pickArea.containsMouse ? "#0f111a" : "#c0caf5"
                        }

                        MouseArea {
                            id: pickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                wallpaperPick.running = true
                                widget.wallpaperOpen = false
                            }
                        }
                    }

                    Text {
                        visible: widget.wallpapers.length > 0
                        text: widget.isGerman ? "Zuletzt verwendet" : "Recently used"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#565f89"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: widget.wallpapers

                            Rectangle {
                                required property var modelData
                                Layout.preferredWidth: 128
                                Layout.preferredHeight: 72
                                radius: 8
                                color: "#0f111a"
                                border.width: modelData.current ? 2 : 0
                                border.color: "#1793d1"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: modelData.current ? 2 : 0
                                    source: "file://" + modelData.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 256
                                }

                                Rectangle {
                                    visible: modelData.current
                                    anchors { bottom: parent.bottom; right: parent.right; margins: 4 }
                                    width: 16; height: 16
                                    radius: 8
                                    color: "#1793d1"
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: "#0f111a"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (!modelData.current) {
                                            wallpaperApply.command = ["python3", widget.themeDir + "/wallpaper.py", "apply", modelData.path]
                                            wallpaperApply.running = true
                                        }
                                        widget.wallpaperOpen = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= COLORS POPUP =================
    LazyLoader {
        active: widget.colorsOpen

        PanelWindow {
            id: colorsWindow
            screen: widget.screen
            anchors { top: true; left: true }
            margins { top: 48; left: 10 }
            implicitWidth: 460
            implicitHeight: colorsCol.implicitHeight + 24
            color: "transparent"
            WlrLayershell.namespace: "theme-widget-colors"
            WlrLayershell.layer: WlrLayer.Top

            HyprlandFocusGrab {
                windows: [ colorsWindow ]
                active: true
                onCleared: widget.colorsOpen = false
            }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: widget.argb(widget.popupColor, widget.popupOpacity)
                border.width: 1
                border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                ColumnLayout {
                    id: colorsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // ---- step 1: pick which role to edit ----
                    ColumnLayout {
                        visible: widget.editingKey === ""
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: widget.isGerman ? "Farbe wählen" : "Choose a color"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            font.bold: true
                            color: "#c0caf5"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 4
                            columnSpacing: 8

                            Repeater {
                                model: widget.roleOrder

                                Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: 6
                                    color: roleArea.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.18) : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 6

                                        Rectangle {
                                            width: 16; height: 16
                                            radius: 4
                                            color: widget.colorValues[modelData] || "#000000"
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.2)
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: widget.roleLabels[modelData]
                                            elide: Text.ElideRight
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: "#c0caf5"
                                        }
                                    }

                                    MouseArea {
                                        id: roleArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            widget.editingKey = modelData
                                            widget.hexInput = widget.colorValues[modelData] || ""
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.topMargin: 2
                            color: Qt.rgba(0.478, 0.635, 0.969, 0.2)
                        }

                        Text {
                            text: widget.isGerman ? "Transparenz" : "Opacity"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#565f89"
                        }

                        Repeater {
                            model: widget.opacityFields

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                readonly property real liveValue: widget.colorValues[modelData.key] !== undefined ? widget.colorValues[modelData.key] : 1
                                property real dragValue: liveValue
                                readonly property real shownValue: track.pressed ? dragValue : liveValue

                                Text {
                                    Layout.preferredWidth: 52
                                    text: modelData.label
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: "#c0caf5"
                                }

                                Rectangle {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    radius: 4
                                    color: widget.colorValues[modelData.colorKey] || "#000000"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.2)

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            widget.editingKey = modelData.colorKey
                                            widget.hexInput = widget.colorValues[modelData.colorKey] || ""
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20

                                    Rectangle {
                                        id: sliderTrack
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: sliderTrack.width * Math.max(0, Math.min(1, shownValue))
                                        height: 6
                                        radius: 3
                                        color: "#1793d1"
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(sliderTrack.width, sliderTrack.width * shownValue)) - width / 2
                                        width: 14; height: 14
                                        radius: 7
                                        color: "#c0caf5"
                                        border.width: track.pressed ? 2 : 0
                                        border.color: "#1793d1"
                                    }

                                    MouseArea {
                                        id: track
                                        anchors.fill: parent
                                        preventStealing: true

                                        function valueAt(mx) {
                                            return Math.max(0, Math.min(1, mx / width))
                                        }
                                        onPressed: (mouse) => { dragValue = valueAt(mouse.x) }
                                        onPositionChanged: (mouse) => { if (pressed) dragValue = valueAt(mouse.x) }
                                        onReleased: {
                                            opacitySet.command = ["python3", widget.themeDir + "/render.py", "--set", modelData.key, dragValue.toFixed(2)]
                                            opacitySet.running = true
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 34
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(shownValue * 100) + "%"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: "#565f89"
                                }
                            }
                        }
                    }

                    // ---- step 2: pick a new color for widget.editingKey ----
                    ColumnLayout {
                        visible: widget.editingKey !== ""
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                width: 22; height: 22
                                radius: 6
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: "#7aa2f7"
                                }
                                MouseArea { anchors.fill: parent; onClicked: widget.editingKey = "" }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: widget.roleLabels[widget.editingKey] || ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                font.bold: true
                                color: "#c0caf5"
                            }
                            Rectangle {
                                width: 28; height: 28
                                radius: 6
                                color: previewValid ? widget.hexInput : "#000000"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.25)
                                readonly property bool previewValid: /^#[0-9a-fA-F]{6}$/.test(widget.hexInput)
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: widget.presetPalette

                                Rectangle {
                                    required property string modelData
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    color: modelData
                                    border.width: widget.hexInput.toLowerCase() === modelData ? 2 : 1
                                    border.color: widget.hexInput.toLowerCase() === modelData ? "#ffffff" : Qt.rgba(1, 1, 1, 0.2)

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: widget.hexInput = modelData
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
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
                                    color: "#c0caf5"
                                    selectByMouse: true
                                    maximumLength: 7
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 30
                                radius: 6
                                readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(widget.hexInput)
                                color: !valid ? Qt.rgba(0.478, 0.635, 0.969, 0.1) : (applyArea.containsMouse ? "#1793d1" : Qt.rgba(0.478, 0.635, 0.969, 0.25))
                                opacity: valid ? 1.0 : 0.5

                                Text {
                                    anchors.centerIn: parent
                                    text: widget.isGerman ? "Übernehmen" : "Apply"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: applyArea.containsMouse ? "#0f111a" : "#c0caf5"
                                }

                                MouseArea {
                                    id: applyArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: parent.valid
                                    onClicked: {
                                        colorsSet.command = ["python3", widget.themeDir + "/render.py", "--set", widget.editingKey, widget.hexInput]
                                        colorsSet.running = true
                                        widget.editingKey = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= PRESETS POPUP =================
    LazyLoader {
        active: widget.presetsOpen

        PanelWindow {
            id: presetsWindow
            screen: widget.screen
            anchors { top: true; left: true }
            margins { top: 48; left: 10 }
            implicitWidth: 320
            implicitHeight: presetsCol.implicitHeight + 24
            color: "transparent"
            WlrLayershell.namespace: "theme-widget-presets"
            WlrLayershell.layer: WlrLayer.Top

            HyprlandFocusGrab {
                windows: [ presetsWindow ]
                active: true
                onCleared: widget.presetsOpen = false
            }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: widget.argb(widget.popupColor, widget.popupOpacity)
                border.width: 1
                border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                ColumnLayout {
                    id: presetsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: widget.isGerman ? "Gespeicherte Profile" : "Saved presets"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#c0caf5"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 6
                            color: "#0f111a"
                            border.width: 1
                            border.color: Qt.rgba(0.478, 0.635, 0.969, 0.3)

                            TextInput {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: widget.presetNameInput
                                onTextEdited: widget.presetNameInput = text
                                maximumLength: 40
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: "#c0caf5"
                                selectByMouse: true
                                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9 _-]*/ }

                                Text {
                                    visible: parent.text === ""
                                    text: "Name…"
                                    font: parent.font
                                    color: "#565f89"
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 30
                            radius: 6
                            readonly property bool valid: widget.presetNameInput.trim().length > 0
                            color: !valid ? Qt.rgba(0.478, 0.635, 0.969, 0.1) : (saveArea.containsMouse ? "#1793d1" : Qt.rgba(0.478, 0.635, 0.969, 0.25))
                            opacity: valid ? 1.0 : 0.5

                            Text {
                                anchors.centerIn: parent
                                text: widget.isGerman ? "Speichern" : "Save"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: saveArea.containsMouse ? "#0f111a" : "#c0caf5"
                            }

                            MouseArea {
                                id: saveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.valid
                                onClicked: {
                                    presetsSave.command = ["python3", widget.themeDir + "/presets.py", "save", widget.presetNameInput.trim()]
                                    presetsSave.running = true
                                    widget.presetNameInput = ""
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(0.478, 0.635, 0.969, 0.2)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 8
                            color: defaultArea.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.18) : (widget.presetsDefault.current ? Qt.rgba(0.478, 0.635, 0.969, 0.1) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: widget.isGerman ? "Standard" : "Default"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: "#c0caf5"
                                }
                                Text {
                                    visible: widget.presetsDefault.current
                                    text: ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: "#1793d1"
                                }
                            }

                            MouseArea {
                                id: defaultArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    presetsLoad.command = ["python3", widget.themeDir + "/presets.py", "load", "Default"]
                                    presetsLoad.running = true
                                }
                            }
                        }

                        Repeater {
                            model: widget.presetsList

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: 8
                                color: rowArea.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.18) : (modelData.current ? Qt.rgba(0.478, 0.635, 0.969, 0.1) : "transparent")

                                // Declared before the row content below, so the trash icon's own
                                // MouseArea (a descendant of a later sibling) sits on top of this
                                // one and claims its clicks first; this one gets the rest of the row.
                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        presetsLoad.command = ["python3", widget.themeDir + "/presets.py", "load", modelData.name]
                                        presetsLoad.running = true
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: "#c0caf5"
                                    }
                                    Text {
                                        visible: modelData.current
                                        text: ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: "#1793d1"
                                    }
                                    Rectangle {
                                        width: 20; height: 20
                                        radius: 5
                                        color: deleteArea.containsMouse ? "#f7768e" : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            color: deleteArea.containsMouse ? "#0f111a" : "#565f89"
                                        }

                                        MouseArea {
                                            id: deleteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                presetsDelete.command = ["python3", widget.themeDir + "/presets.py", "delete", modelData.name]
                                                presetsDelete.running = true
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
