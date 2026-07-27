import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    id: root
    model: Quickshell.screens

    readonly property bool isGerman: Qt.locale().name.startsWith("de")
    readonly property string logoutLabel: isGerman ? "Abmelden" : "Logout"
    readonly property string restartLabel: isGerman ? "Neustart" : "Restart"
    readonly property string shutdownLabel: isGerman ? "Herunterfahren" : "Shutdown"

    PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { top: true; right: true }
        implicitWidth: 40
        implicitHeight: 34
        margins.right: 8
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "power-button"
        WlrLayershell.layer: WlrLayer.Overlay

        property bool menuOpen: false

        Process { id: logoutProc; command: ["hyprctl", "dispatch", "exit"] }
        Process { id: rebootProc; command: ["systemctl", "reboot"] }
        Process { id: shutdownProc; command: ["systemctl", "poweroff"] }

        // Matches window#waybar's own backdrop tint so the button blends into the bar
        // instead of floating over the wallpaper on its own transparent surface.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.071, 0.075, 0.106, 0.18)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 10
            color: btnArea.containsMouse ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: btnArea.containsMouse ? "#0f111a" : "#1793d1"
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: panel.menuOpen = !panel.menuOpen
            }
        }

        LazyLoader {
            active: panel.menuOpen

            PanelWindow {
                id: menu
                screen: panel.modelData

                anchors { top: true; right: true }
                margins { top: 34; right: 8 }

                implicitWidth: 170
                implicitHeight: col.implicitHeight + 16
                color: "transparent"
                WlrLayershell.namespace: "power-menu"
                WlrLayershell.layer: WlrLayer.Overlay

                HyprlandFocusGrab {
                    windows: [ menu ]
                    active: true
                    onCleared: panel.menuOpen = false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: col
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        MenuEntry {
                            label: root.logoutLabel
                            icon: ""
                            onTriggered: {
                                panel.menuOpen = false
                                logoutProc.startDetached()
                            }
                        }

                        MenuEntry {
                            label: root.restartLabel
                            icon: ""
                            onTriggered: {
                                panel.menuOpen = false
                                rebootProc.startDetached()
                            }
                        }

                        MenuEntry {
                            label: root.shutdownLabel
                            icon: ""
                            onTriggered: {
                                panel.menuOpen = false
                                shutdownProc.startDetached()
                            }
                        }
                    }
                }
            }
        }
    }
}
