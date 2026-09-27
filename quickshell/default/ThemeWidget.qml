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
    property var wallpapers: []

    // ---- color roles: key -> current hex, kept in sync with theme/colors.toml ----
    property var colorValues: ({})
    property string editingKey: ""
    property string hexInput: ""

    readonly property var roleOrder: ["accent", "cursor", "foreground", "background",
        "selection_foreground", "selection_background",
        "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7",
        "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"]

    readonly property var roleLabels: ({
        accent: "Accent", cursor: "Cursor", foreground: "Foreground", background: "Background",
        selection_foreground: isGerman ? "Auswahl (Text)" : "Selection (fg)",
        selection_background: isGerman ? "Auswahl (Hintergrund)" : "Selection (bg)",
        color0: "Color 0", color1: "Color 1", color2: "Color 2", color3: "Color 3",
        color4: "Color 4", color5: "Color 5", color6: "Color 6", color7: "Color 7",
        color8: "Color 8", color9: "Color 9", color10: "Color 10", color11: "Color 11",
        color12: "Color 12", color13: "Color 13", color14: "Color 14", color15: "Color 15",
    })

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

    Component.onCompleted: {
        refreshColors()
        refreshWallpapers()
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
                        widget.colorsOpen = !widget.colorsOpen
                        if (widget.colorsOpen) {
                            widget.editingKey = ""
                            widget.refreshColors()
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
                color: "#f01a1b26"
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
            implicitWidth: 340
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
                color: "#f01a1b26"
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
}
