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

    PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { top: true; right: true }
        implicitWidth: Math.max(72, content.implicitWidth + 28)
        implicitHeight: 34
        margins.right: 190
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "network-widget"
        WlrLayershell.layer: WlrLayer.Overlay

        property string connType: ""
        property string connName: ""
        property string localIp: ""
        property string publicIp: ""
        property bool publicIpLoading: false
        property bool showPublicIp: false
        property bool hovering: false

        readonly property string icon: connType === "wifi" ? "" : connType === "ethernet" ? "󰈀" : "󰤭"
        readonly property string statusText: connType === "wifi" ? (connName || "WLAN") : connType === "ethernet" ? "LAN" : "offline"
        readonly property color statusColor: connType === "" ? "#565f89" : "#a6e3a1"

        Process {
            id: refreshProc
            command: ["bash", "-c", "conn=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\"{print $1; exit}'); if [ \"$conn\" = \"wifi\" ]; then name=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'); else name=\"LAN\"; fi; ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i==\"src\") print $(i+1)}'); echo \"${conn}|${name}|${ip}\""]
            stdout: StdioCollector { id: refreshCollector }
            onExited: {
                var parts = refreshCollector.text.trim().split("|")
                panel.connType = parts[0] || ""
                panel.connName = parts[1] || ""
                panel.localIp = parts[2] || ""
            }
        }

        Timer {
            interval: 100
            running: true
            repeat: false
            onTriggered: refreshProc.running = true
        }

        Timer {
            interval: 8000
            running: true
            repeat: true
            onTriggered: refreshProc.running = true
        }

        Process {
            id: publicIpProc
            command: ["bash", "-c", "curl -s -m 3 https://api.ipify.org"]
            stdout: StdioCollector { id: publicIpCollector }
            onExited: {
                var text = publicIpCollector.text.trim()
                panel.publicIp = text !== "" ? text : (root.isGerman ? "nicht verfügbar" : "unavailable")
                panel.publicIpLoading = false
            }
        }

        // Matches window#waybar's own backdrop tint so the widget blends into the bar.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.071, 0.075, 0.106, 0.18)
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            anchors.leftMargin: 4
            anchors.rightMargin: 2
            radius: 10
            color: netArea.containsMouse ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: panel.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: netArea.containsMouse ? "#0f111a" : panel.statusColor
                }

                Text {
                    text: panel.statusText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: netArea.containsMouse ? "#0f111a" : "#c0caf5"
                }
            }

            MouseArea {
                id: netArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: panel.hovering = true
                onExited: panel.hovering = false
                onClicked: {
                    panel.showPublicIp = !panel.showPublicIp
                    if (panel.showPublicIp) {
                        panel.publicIpLoading = true
                        publicIpProc.running = true
                    }
                }
            }
        }

        LazyLoader {
            active: panel.hovering

            PanelWindow {
                screen: panel.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: 190 }
                implicitWidth: 220
                implicitHeight: tooltipCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "network-tooltip"
                WlrLayershell.layer: WlrLayer.Overlay

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: tooltipCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: panel.connType === "" ? (root.isGerman ? "Nicht verbunden" : "Not connected") : (panel.connType === "wifi" ? (root.isGerman ? "WLAN: " : "Wi-Fi: ") + panel.connName : (root.isGerman ? "Kabelgebunden" : "Wired"))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#c0caf5"
                        }

                        Text {
                            text: (panel.showPublicIp ? (root.isGerman ? "Öffentliche IP: " : "Public IP: ") + (panel.publicIpLoading ? "…" : (panel.publicIp || "n/a")) : (root.isGerman ? "Lokale IP: " : "Local IP: ") + (panel.localIp || "n/a"))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }

                        Text {
                            text: root.isGerman ? "Klicken zum Wechseln" : "Click to toggle"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#565f89"
                        }
                    }
                }
            }
        }
    }
}
