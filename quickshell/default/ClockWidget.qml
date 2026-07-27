import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    id: root
    model: Quickshell.screens

    readonly property bool isGerman: Qt.locale().name.startsWith("de")

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
        id: panel
        required property var modelData
        screen: modelData

        anchors { top: true; right: true }
        implicitWidth: 130
        implicitHeight: 34
        margins.right: 54
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "clock-widget"
        WlrLayershell.layer: WlrLayer.Overlay

        property bool calendarOpen: false
        property bool hovering: false
        property var now: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: panel.now = new Date()
        }

        // Matches window#waybar's own backdrop tint so the widget blends into the bar.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.071, 0.075, 0.106, 0.18)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 10
            color: clockArea.containsMouse ? "#1793d1" : Qt.rgba(0.102, 0.106, 0.149, 0.85)

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(panel.now, "dd.MM. hh:mm")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: clockArea.containsMouse ? "#0f111a" : "#c0caf5"
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: panel.hovering = true
                onExited: panel.hovering = false
                onClicked: panel.calendarOpen = !panel.calendarOpen
            }
        }

        LazyLoader {
            active: panel.hovering && !panel.calendarOpen

            PanelWindow {
                screen: panel.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: 54 }
                implicitWidth: 230
                implicitHeight: tooltipCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "clock-tooltip"
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
                            text: Qt.formatDateTime(panel.now, "dddd, dd. MMMM yyyy")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#c0caf5"
                        }
                        Text {
                            text: (root.isGerman ? "KW " : "Week ") + root.isoWeek(panel.now)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#7aa2f7"
                        }
                        Text {
                            text: Qt.formatDateTime(panel.now, "hh:mm:ss")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#565f89"
                        }
                    }
                }
            }
        }

        LazyLoader {
            active: panel.calendarOpen

            PanelWindow {
                id: calendarWindow
                screen: panel.modelData
                anchors { top: true; right: true }
                margins { top: 34; right: 54 }
                implicitWidth: 250
                implicitHeight: calCol.implicitHeight + 20
                color: "transparent"
                WlrLayershell.namespace: "clock-calendar"
                WlrLayershell.layer: WlrLayer.Overlay

                property int viewYear: panel.now.getFullYear()
                property int viewMonth: panel.now.getMonth()
                property var weeks: root.buildCalendar(viewYear, viewMonth, panel.now)

                HyprlandFocusGrab {
                    windows: [ calendarWindow ]
                    active: true
                    onCleared: panel.calendarOpen = false
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
                                        if (calendarWindow.viewMonth === 0) {
                                            calendarWindow.viewMonth = 11
                                            calendarWindow.viewYear -= 1
                                        } else {
                                            calendarWindow.viewMonth -= 1
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDateTime(new Date(calendarWindow.viewYear, calendarWindow.viewMonth, 1), "MMMM yyyy")
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
                                        if (calendarWindow.viewMonth === 11) {
                                            calendarWindow.viewMonth = 0
                                            calendarWindow.viewYear += 1
                                        } else {
                                            calendarWindow.viewMonth += 1
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.preferredWidth: 22
                                text: ""
                            }

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
                            model: calendarWindow.weeks

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
    }
}
