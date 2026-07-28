import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Variants {
    id: root
    model: Quickshell.screens

    readonly property bool isGerman: Qt.locale().name.startsWith("de")
    readonly property string logoutLabel: isGerman ? "Abmelden" : "Logout"
    readonly property string restartLabel: isGerman ? "Neustart" : "Restart"
    readonly property string shutdownLabel: isGerman ? "Herunterfahren" : "Shutdown"

    property bool windowSwitcherOpen: false

    function isoWeek(d) {
        let date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        let day = (date.getUTCDay() + 6) % 7;
        date.setUTCDate(date.getUTCDate() - day + 3);
        let firstThursday = date.getTime();
        date.setUTCMonth(0, 1);
        if (date.getUTCDay() !== 4) {
            date.setUTCMonth(0, 1 + ((4 - date.getUTCDay()) + 7) % 7);
        }
        return 1 + Math.round((firstThursday - date.getTime()) / (7 * 86400000));
    }

    function buildCalendar(year, month, today) {
        const firstOfMonth = new Date(year, month, 1);
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const leading = (firstOfMonth.getDay() + 6) % 7;

        let cells = [];
        for (let i = 0; i < leading; i++) cells.push(null);
        for (let d = 1; d <= daysInMonth; d++) cells.push(d);
        while (cells.length % 7 !== 0) cells.push(null);

        let weeksArr = [];
        for (let i = 0; i < cells.length; i += 7) {
            let weekCells = cells.slice(i, i + 7);
            let refDay = weekCells.find(c => c !== null) || 1;
            let refDate = new Date(year, month, refDay);
            weeksArr.push({
                weekNum: root.isoWeek(refDate),
                days: weekCells.map(c => ({
                    day: c,
                    isToday: c !== null && year === today.getFullYear() && month === today.getMonth() && c === today.getDate()
                }))
            });
        }
        return weeksArr;
    }

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        anchors { top: true; left: true; right: true }
        implicitHeight: 34
        exclusionMode: ExclusionMode.Auto
        color: "transparent"
        WlrLayershell.namespace: "bar"
        WlrLayershell.layer: WlrLayer.Top

        readonly property var workspaceIds: modelData.name === "DP-1" ? [1, 2, 3, 4, 9] : [5, 6, 7, 8]
        readonly property var activeToplevel: Hyprland.activeToplevel
        readonly property string titleText: (activeToplevel && activeToplevel.monitor && activeToplevel.monitor.name === modelData.name) ? activeToplevel.title : ""

        Loader {
            active: modelData === Quickshell.screens[0]
            sourceComponent: IpcHandler {
                target: "windowswitcher"

                function toggle(): void {
                    root.windowSwitcherOpen = !root.windowSwitcherOpen
                }
            }
        }

        property string hovered: ""
        property bool menuOpen: false
        property bool calendarOpen: false
        property bool clockHovering: false
        property bool netHovering: false
        property bool showCpuTemp: false
        property bool showPublicIp: false

        // ---- stats ----
        property int cpuPct: 0
        property int memPct: 0
        property real memUsed: 0
        property real memTotal: 0
        property int diskPct: 0
        property real diskTotal: 0
        property real diskUsed: 0
        property real diskAvail: 0
        property string load1: "0.00"
        property string load5: "0.00"
        property string load15: "0.00"
        property string tempC: "NA"
        readonly property bool tempAvailable: tempC !== "NA"
        readonly property bool tempCritical: tempAvailable && parseInt(tempC) >= 80
        property var perCore: []
        property string gpuUtil: "NA"
        property string gpuTemp: "NA"
        property string gpuMemUsed: "NA"
        property string gpuMemTotal: "NA"
        readonly property bool gpuAvailable: gpuUtil !== "NA"

        // ---- network ----
        property string connType: ""
        property string connName: ""
        property string localIp: ""
        property string publicIp: ""
        property bool publicIpLoading: false

        // ---- volume ----
        property int volumePct: 0
        property bool volumeMuted: false

        // ---- clock ----
        property var now: new Date()
        property int viewYear: now.getFullYear()
        property int viewMonth: now.getMonth()
        property var weeks: root.buildCalendar(viewYear, viewMonth, now)

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: bar.now = new Date()
        }

        Process {
            id: statsProc
            command: ["bash", "/home/nico/.config/quickshell/default/scripts/stats.sh"]
            stdout: StdioCollector { id: statsCollector }
            onExited: {
                var p = statsCollector.text.trim().split("|")
                if (p.length < 12) return
                bar.cpuPct = parseInt(p[0]) || 0
                bar.memPct = parseInt(p[1]) || 0
                bar.memUsed = parseFloat(p[2]) || 0
                bar.memTotal = parseFloat(p[3]) || 0
                bar.diskPct = parseInt(p[4]) || 0
                bar.diskTotal = parseFloat(p[5]) || 0
                bar.diskUsed = parseFloat(p[6]) || 0
                bar.diskAvail = parseFloat(p[7]) || 0
                bar.load1 = p[8]
                bar.load5 = p[9]
                bar.load15 = p[10]
                bar.tempC = p[11]
                bar.perCore = p.length > 12 && p[12] !== "" ? p[12].split(",").map(Number) : []
                if (p.length > 16) {
                    bar.gpuUtil = p[13]
                    bar.gpuTemp = p[14]
                    bar.gpuMemUsed = p[15]
                    bar.gpuMemTotal = p[16]
                }
            }
        }

        Timer { interval: 100; running: true; repeat: false; onTriggered: statsProc.running = true }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: statsProc.running = true }

        Process {
            id: netProc
            command: ["bash", "-c", "conn=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\"{print $1; exit}'); if [ \"$conn\" = \"wifi\" ]; then name=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'); else name=\"LAN\"; fi; ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i==\"src\") print $(i+1)}'); echo \"${conn}|${name}|${ip}\""]
            stdout: StdioCollector { id: netCollector }
            onExited: {
                var parts = netCollector.text.trim().split("|")
                bar.connType = parts[0] || ""
                bar.connName = parts[1] || ""
                bar.localIp = parts[2] || ""
            }
        }

        Timer { interval: 300; running: true; repeat: false; onTriggered: netProc.running = true }
        Timer { interval: 8000; running: true; repeat: true; onTriggered: netProc.running = true }

        Process {
            id: publicIpProc
            command: ["bash", "-c", "curl -s -m 3 https://api.ipify.org"]
            stdout: StdioCollector { id: publicIpCollector }
            onExited: {
                var text = publicIpCollector.text.trim()
                bar.publicIp = text !== "" ? text : (root.isGerman ? "nicht verfügbar" : "unavailable")
                bar.publicIpLoading = false
            }
        }

        Process {
            id: volumeProc
            command: ["bash", "/home/nico/.config/quickshell/default/scripts/volume.sh"]
            stdout: StdioCollector { id: volumeCollector }
            onExited: {
                var parts = volumeCollector.text.trim().split("|")
                bar.volumePct = parseInt(parts[0]) || 0
                bar.volumeMuted = parts[1] === "1"
            }
        }

        Timer { interval: 500; running: true; repeat: false; onTriggered: volumeProc.running = true }
        Timer { interval: 5000; running: true; repeat: true; onTriggered: volumeProc.running = true }

        Process {
            id: volumeWatchProc
            command: ["pactl", "subscribe"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    if (data.indexOf("sink") !== -1) volumeProc.running = true
                }
            }
        }

        Process { id: pavucontrolProc; command: ["pavucontrol"] }
        Process { id: volUpProc; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"] }
        Process { id: volDownProc; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
        Process { id: volMuteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

        Process { id: logoutProc; command: ["hyprctl", "dispatch", "exit"] }
        Process { id: rebootProc; command: ["systemctl", "reboot"] }
        Process { id: shutdownProc; command: ["systemctl", "poweroff"] }

        FontMetrics {
            id: valueFont
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.071, 0.075, 0.106, 0.18)
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Qt.rgba(0.090, 0.576, 0.820, 0.45)
        }

        // ================= LEFT =================
        RowLayout {
            id: leftRow
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 6

            Rectangle {
                Layout.preferredWidth: logoText.implicitWidth + 28
                Layout.preferredHeight: 26
                radius: 10
                color: Qt.rgba(0.090, 0.576, 0.820, 0.12)

                Text {
                    id: logoText
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: "#1793d1"
                }
            }

            Rectangle {
                Layout.preferredWidth: wsRow.implicitWidth + 8
                Layout.preferredHeight: 26
                radius: 10
                color: Qt.rgba(0.102, 0.106, 0.149, 0.85)

                RowLayout {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: bar.workspaceIds

                        Rectangle {
                            id: wsBtn
                            required property int modelData
                            readonly property var hyprWs: {
                                for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                    if (Hyprland.workspaces.values[i].id === modelData) return Hyprland.workspaces.values[i]
                                }
                                return null
                            }
                            readonly property bool active: hyprWs !== null && hyprWs.active

                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 20
                            radius: 8
                            color: active ? "#1793d1" : (wsArea.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.22) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (wsBtn.active) return ""
                                    if (wsBtn.modelData === 5) return ""
                                    if (wsBtn.modelData === 6) return ""
                                    if (wsBtn.modelData === 7) return ""
                                    if (wsBtn.modelData === 8) return ""
                                    return wsBtn.modelData.toString()
                                }
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: wsBtn.active ? "#0f111a" : "#565f89"
                            }

                            MouseArea {
                                id: wsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Hyprland.dispatch("workspace " + wsBtn.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: winSwitchBtn
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 10
                color: (winSwitchArea.containsMouse || root.windowSwitcherOpen) ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: (winSwitchArea.containsMouse || root.windowSwitcherOpen) ? "#0f111a" : "#7aa2f7"
                }

                MouseArea {
                    id: winSwitchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.windowSwitcherOpen = !root.windowSwitcherOpen
                }
            }
        }

        // ================= CENTER =================
        Text {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 500)
            elide: Text.ElideRight
            text: bar.titleText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#c0caf5"
        }

        // ================= RIGHT =================
        RowLayout {
            id: rightRow
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 10

            Rectangle {
                id: trayPill
                readonly property int count: SystemTray.items.values.length
                visible: count > 0
                Layout.preferredWidth: count > 0 ? trayRow.implicitWidth + 16 : 0
                Layout.preferredHeight: 26
                radius: 10
                color: Qt.rgba(0.102, 0.106, 0.149, 0.85)

                RowLayout {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        Item {
                            required property var modelData
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18

                            Image {
                                anchors.fill: parent
                                source: modelData.icon
                                sourceSize: Qt.size(18, 18)
                                smooth: true
                            }

                            MouseArea {
                                id: trayItemArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                        var pos = trayItemArea.mapToItem(bar.contentItem, mouse.x, mouse.y)
                                        modelData.display(bar, pos.x, pos.y)
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: cpuPill
                Layout.preferredWidth: cpuRow.implicitWidth + 14
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "cpu" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Row {
                    id: cpuRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: bar.showCpuTemp ? "" : ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "cpu" ? "#0f111a" : (bar.showCpuTemp ? (bar.tempCritical ? "#f7768e" : "#f9e2af") : "#7aa2f7")
                    }
                    Text {
                        text: bar.showCpuTemp ? (bar.tempC + "°C") : (bar.cpuPct + "%")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        width: valueFont.advanceWidth("100%")
                        horizontalAlignment: Text.AlignRight
                        color: bar.hovered === "cpu" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hovered = "cpu"
                    onExited: bar.hovered = ""
                    onClicked: if (bar.tempAvailable) bar.showCpuTemp = !bar.showCpuTemp
                }
            }

            Rectangle {
                id: memPill
                Layout.preferredWidth: memRow.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "mem" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Row {
                    id: memRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "mem" ? "#0f111a" : "#89dceb"
                    }
                    Text {
                        text: bar.memPct + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        width: valueFont.advanceWidth("100%")
                        horizontalAlignment: Text.AlignRight
                        color: bar.hovered === "mem" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hovered = "mem"
                    onExited: bar.hovered = ""
                }
            }

            Rectangle {
                id: diskPill
                Layout.preferredWidth: diskRow.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "disk" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Row {
                    id: diskRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "disk" ? "#0f111a" : "#c0caf5"
                    }
                    Text {
                        text: bar.diskPct + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        width: valueFont.advanceWidth("100%")
                        horizontalAlignment: Text.AlignRight
                        color: bar.hovered === "disk" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hovered = "disk"
                    onExited: bar.hovered = ""
                }
            }

            Rectangle {
                id: gpuPill
                visible: bar.gpuAvailable
                Layout.preferredWidth: visible ? gpuRow.implicitWidth + 14 : 0
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "gpu" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Row {
                    id: gpuRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰢮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "gpu" ? "#0f111a" : "#a6e3a1"
                    }
                    Text {
                        text: bar.gpuUtil + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        width: valueFont.advanceWidth("100%")
                        horizontalAlignment: Text.AlignRight
                        color: bar.hovered === "gpu" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hovered = "gpu"
                    onExited: bar.hovered = ""
                }
            }

            Rectangle {
                id: volumePill
                Layout.preferredWidth: volRow.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "vol" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: bar.volumeMuted ? "" : ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "vol" ? "#0f111a" : (bar.volumeMuted ? "#565f89" : "#cba6f7")
                    }
                    Text {
                        text: (bar.volumeMuted ? (root.isGerman ? "muted" : "muted") : bar.volumePct + "%")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: bar.hovered === "vol" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: bar.hovered = "vol"
                    onExited: bar.hovered = ""
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            volMuteProc.running = true
                        } else {
                            pavucontrolProc.startDetached()
                        }
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) volUpProc.running = true
                        else volDownProc.running = true
                    }
                }
            }

            Rectangle {
                id: networkPill
                Layout.preferredWidth: netRow.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 10
                color: bar.hovered === "net" ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                readonly property string icon: bar.connType === "wifi" ? "" : bar.connType === "ethernet" ? "󰈀" : "󰤭"
                readonly property string statusText: bar.connType === "wifi" ? (bar.connName || "WLAN") : bar.connType === "ethernet" ? "LAN" : "offline"
                readonly property color statusColor: bar.connType === "" ? "#565f89" : "#a6e3a1"

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: networkPill.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: bar.hovered === "net" ? "#0f111a" : networkPill.statusColor
                    }
                    Text {
                        text: networkPill.statusText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 90)
                        color: bar.hovered === "net" ? "#0f111a" : "#c0caf5"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.hovered = "net"
                    onExited: bar.hovered = ""
                    onClicked: {
                        bar.showPublicIp = !bar.showPublicIp
                        if (bar.showPublicIp) {
                            bar.publicIpLoading = true
                            publicIpProc.running = true
                        }
                    }
                }
            }

            Rectangle {
                id: clockPill
                Layout.preferredWidth: 100
                Layout.preferredHeight: 26
                radius: 10
                color: (clockArea.containsMouse || bar.calendarOpen) ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(bar.now, "dd.MM. hh:mm")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: (clockArea.containsMouse || bar.calendarOpen) ? "#0f111a" : "#c0caf5"
                }

                MouseArea {
                    id: clockArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: bar.clockHovering = true
                    onExited: bar.clockHovering = false
                    onClicked: bar.calendarOpen = !bar.calendarOpen
                }
            }

            Rectangle {
                id: powerBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 26
                radius: 10
                color: (powerArea.containsMouse || bar.menuOpen) ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: (powerArea.containsMouse || bar.menuOpen) ? "#0f111a" : "#1793d1"
                }

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.menuOpen = !bar.menuOpen
                }
            }
        }

        // ================= POPUPS =================

        LazyLoader {
            active: bar.hovered !== "" && bar.hovered !== "net"

            PanelWindow {
                screen: bar.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: bar.width - (rightRow.x + statsPopupAnchor.x + statsPopupAnchor.width) }
                implicitWidth: (bar.hovered === "cpu" && bar.perCore.length > 0) ? 320 : (bar.hovered === "vol" ? 300 : 220)
                implicitHeight: tooltipCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "stats-tooltip"
                WlrLayershell.layer: WlrLayer.Top

                readonly property var statsPopupAnchor: bar.hovered === "cpu" ? cpuPill : bar.hovered === "mem" ? memPill : bar.hovered === "disk" ? diskPill : bar.hovered === "gpu" ? gpuPill : bar.hovered === "vol" ? volumePill : cpuPill

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
                            visible: bar.hovered === "cpu"
                            text: (root.isGerman ? "Last (1/5/15 Min): " : "Load (1/5/15 min): ") + bar.load1 + " / " + bar.load5 + " / " + bar.load15
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#c0caf5"
                        }
                        Text {
                            visible: bar.hovered === "cpu" && bar.tempAvailable
                            text: (root.isGerman ? "Temperatur (Tctl): " : "Temperature (Tctl): ") + bar.tempC + "°C"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }
                        GridLayout {
                            visible: bar.hovered === "cpu" && bar.perCore.length > 0
                            columns: 4
                            columnSpacing: 10
                            rowSpacing: 2

                            Repeater {
                                model: bar.perCore
                                Text {
                                    required property int index
                                    required property var modelData
                                    text: "C" + index + ": " + modelData + "%"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: "#565f89"
                                }
                            }
                        }
                        Text {
                            visible: bar.hovered === "cpu"
                            text: root.isGerman ? "Klicken zum Wechseln" : "Click to toggle"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#565f89"
                        }
                        Text {
                            visible: bar.hovered === "mem"
                            text: (root.isGerman ? "Belegt: " : "Used: ") + bar.memUsed.toFixed(1) + " / " + bar.memTotal.toFixed(1) + " GiB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#c0caf5"
                        }
                        Text {
                            visible: bar.hovered === "disk"
                            text: "/"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#c0caf5"
                        }
                        Text {
                            visible: bar.hovered === "disk"
                            text: (root.isGerman ? "Belegt: " : "Used: ") + bar.diskUsed.toFixed(0) + " GiB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }
                        Text {
                            visible: bar.hovered === "disk"
                            text: (root.isGerman ? "Frei: " : "Free: ") + bar.diskAvail.toFixed(0) + " GiB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }
                        Text {
                            visible: bar.hovered === "disk"
                            text: (root.isGerman ? "Gesamt: " : "Total: ") + bar.diskTotal.toFixed(0) + " GiB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }
                        Text {
                            visible: bar.hovered === "gpu"
                            text: (root.isGerman ? "Temperatur: " : "Temperature: ") + bar.gpuTemp + "°C"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }
                        Text {
                            visible: bar.hovered === "gpu"
                            text: "VRAM: " + bar.gpuMemUsed + " / " + bar.gpuMemTotal + " MiB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }
                        Text {
                            visible: bar.hovered === "vol"
                            Layout.preferredWidth: 280
                            wrapMode: Text.WordWrap
                            text: root.isGerman ? "Klick: Mixer  ·  Rechtsklick: Stumm  ·  Scroll: Lautstärke" : "Click: Mixer  ·  Right-click: Mute  ·  Scroll: Volume"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#565f89"
                        }
                    }
                }
            }
        }

        LazyLoader {
            active: bar.hovered === "net"

            PanelWindow {
                screen: bar.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: bar.width - (rightRow.x + networkPill.x + networkPill.width) }
                implicitWidth: 220
                implicitHeight: netTooltipCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "net-tooltip"
                WlrLayershell.layer: WlrLayer.Top

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: netTooltipCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: bar.connType === "" ? (root.isGerman ? "Nicht verbunden" : "Not connected") : (bar.connType === "wifi" ? (root.isGerman ? "WLAN: " : "Wi-Fi: ") + bar.connName : (root.isGerman ? "Kabelgebunden" : "Wired"))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#c0caf5"
                        }
                        Text {
                            text: (bar.showPublicIp ? (root.isGerman ? "Öffentliche IP: " : "Public IP: ") + (bar.publicIpLoading ? "…" : (bar.publicIp || "n/a")) : (root.isGerman ? "Lokale IP: " : "Local IP: ") + (bar.localIp || "n/a"))
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

        LazyLoader {
            active: bar.clockHovering && !bar.calendarOpen

            PanelWindow {
                screen: bar.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: bar.width - (rightRow.x + clockPill.x + clockPill.width) }
                implicitWidth: 230
                implicitHeight: clockTooltipCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "clock-tooltip"
                WlrLayershell.layer: WlrLayer.Top

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: clockTooltipCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: Qt.formatDateTime(bar.now, "dddd, dd. MMMM yyyy")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#c0caf5"
                        }
                        Text {
                            text: (root.isGerman ? "KW " : "Week ") + root.isoWeek(bar.now)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }
                        Text {
                            text: Qt.formatDateTime(bar.now, "hh:mm:ss")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }
                    }
                }
            }
        }

        LazyLoader {
            active: bar.calendarOpen

            PanelWindow {
                id: calendarWindow
                screen: bar.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: bar.width - (rightRow.x + clockPill.x + clockPill.width) }
                implicitWidth: 250
                implicitHeight: calCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "clock-calendar"
                WlrLayershell.layer: WlrLayer.Top

                HyprlandFocusGrab {
                    windows: [ calendarWindow ]
                    active: true
                    onCleared: bar.calendarOpen = false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: calCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "‹"
                                font.pixelSize: 16
                                color: "#7aa2f7"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: {
                                        if (bar.viewMonth === 0) {
                                            bar.viewMonth = 11
                                            bar.viewYear -= 1
                                        } else {
                                            bar.viewMonth -= 1
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDateTime(new Date(bar.viewYear, bar.viewMonth, 1), "MMMM yyyy")
                                font.bold: true
                                font.pixelSize: 13
                                color: "#c0caf5"
                            }

                            Text {
                                text: "›"
                                font.pixelSize: 16
                                color: "#7aa2f7"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: {
                                        if (bar.viewMonth === 11) {
                                            bar.viewMonth = 0
                                            bar.viewYear += 1
                                        } else {
                                            bar.viewMonth += 1
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text { Layout.preferredWidth: 22; text: "" }

                            Repeater {
                                model: 7
                                Text {
                                    Layout.preferredWidth: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Qt.locale().dayName(index + 1, Locale.ShortFormat)
                                    font.pixelSize: 11
                                    color: "#565f89"
                                }
                            }
                        }

                        Repeater {
                            model: root.buildCalendar(bar.viewYear, bar.viewMonth, bar.now)

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.preferredWidth: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.weekNum
                                    font.pixelSize: 10
                                    color: "#565f89"
                                }

                                Repeater {
                                    model: modelData.days

                                    Rectangle {
                                        required property var modelData
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 22
                                        radius: 6
                                        color: modelData.isToday ? "#1793d1" : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.day ?? ""
                                            font.pixelSize: 11
                                            color: modelData.isToday ? "#0f111a" : (modelData.day ? "#c0caf5" : "transparent")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        LazyLoader {
            active: bar.menuOpen

            PanelWindow {
                id: menu
                screen: bar.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: bar.width - (rightRow.x + powerBtn.x + powerBtn.width) }
                implicitWidth: 170
                implicitHeight: col.implicitHeight + 16
                color: "transparent"
                WlrLayershell.namespace: "power-menu"
                WlrLayershell.layer: WlrLayer.Top

                HyprlandFocusGrab {
                    windows: [ menu ]
                    active: true
                    onCleared: bar.menuOpen = false
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
                                bar.menuOpen = false
                                logoutProc.startDetached()
                            }
                        }

                        MenuEntry {
                            label: root.restartLabel
                            icon: ""
                            onTriggered: {
                                bar.menuOpen = false
                                rebootProc.startDetached()
                            }
                        }

                        MenuEntry {
                            label: root.shutdownLabel
                            icon: ""
                            onTriggered: {
                                bar.menuOpen = false
                                shutdownProc.startDetached()
                            }
                        }
                    }
                }
            }
        }

        LazyLoader {
            active: root.windowSwitcherOpen && Hyprland.focusedMonitor !== null && bar.modelData.name === Hyprland.focusedMonitor.name

            PanelWindow {
                id: winSwitchPopup
                screen: bar.modelData
                anchors { top: true; left: true }
                margins { top: 34; left: leftRow.x + winSwitchBtn.x }
                implicitWidth: 320
                implicitHeight: winSwitchCol.implicitHeight + 16
                color: "transparent"
                WlrLayershell.namespace: "window-switcher"
                WlrLayershell.layer: WlrLayer.Top

                HyprlandFocusGrab {
                    windows: [ winSwitchPopup ]
                    active: true
                    onCleared: root.windowSwitcherOpen = false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#e61a1b26"
                    border.width: 1
                    border.color: Qt.rgba(0.478, 0.635, 0.969, 0.35)

                    ColumnLayout {
                        id: winSwitchCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        Text {
                            visible: Hyprland.toplevels.values.length === 0
                            text: root.isGerman ? "Keine Fenster ge\u00f6ffnet" : "No open windows"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }

                        Repeater {
                            model: Hyprland.toplevels

                            Rectangle {
                                id: winRow
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 8
                                color: winRowArea.containsMouse ? "#1793d1" : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 22
                                        text: winRow.modelData.workspace ? winRow.modelData.workspace.name : ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: winRowArea.containsMouse ? "#0f111a" : "#565f89"
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: winRow.modelData.title
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: winRowArea.containsMouse ? "#0f111a" : "#c0caf5"
                                    }
                                }

                                MouseArea {
                                    id: winRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var addr = winRow.modelData.address
                                        if (!addr.startsWith("0x")) addr = "0x" + addr
                                        Hyprland.dispatch("focuswindow address:" + addr)
                                        root.windowSwitcherOpen = false
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
