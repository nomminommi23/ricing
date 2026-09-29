import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#000000"

    property color accent: config.accent ? config.accent : "#1793d1"
    property color foreground: config.foreground ? config.foreground : "#c0caf5"
    property color background: config.background ? config.background : "#1a1b26"
    property color popupColor: config.popup_color ? config.popup_color : "#1a1b26"
    property real popupOpacity: config.popup_opacity ? parseFloat(config.popup_opacity) : 0.9
    property color pillColor: config.pill_color ? config.pill_color : "#1a1b26"
    property real pillOpacity: config.pill_opacity ? parseFloat(config.pill_opacity) : 0.85
    property color mutedColor: config.color8 ? config.color8 : "#565f89"

    // Same trick as Bar.qml/ThemeWidget.qml: turns a #rrggbb + 0-1 alpha into #aarrggbb,
    // since theme.conf hands us plain hex strings and a separate opacity float, not a
    // pre-blended color.
    function argb(hex, alpha) {
        var h = hex.toString().replace("#", "")
        var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255)
        var aHex = a.toString(16).padStart(2, "0")
        return "#" + aHex + h
    }

    TextConstants { id: textConstants }

    signal tryLogin()
    onTryLogin: sddm.login(userField.text, passwordField.text, sessionCombo.index)

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordField.text = ""
            statusText.text = textConstants.loginFailed
        }
        function onLoginSucceeded() {
            statusText.text = textConstants.loginSucceeded
        }
    }

    // Background: wallpaper.png is a plain copy of the active rice wallpaper, refreshed
    // by theme/render.py on every render (see theme/templates/sddm/) - not templated
    // itself, just kept in sync as a file. anchors.fill, not a screenModel Repeater with
    // manual geometry offsets: SDDM gives each screen its own Main.qml instance already
    // sized and locally-coordinated to just that screen (confirmed via test-mode with two
    // monitors - a geometry-offset approach would push the image out of view).
    Image {
        anchors.fill: parent
        source: "wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45
    }

    // Clock pill, top right - shown on every screen, same look as the bar's pills
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        width: clockText.implicitWidth + 28
        height: 40
        radius: height / 2
        color: root.argb(pillColor, pillOpacity)
        border.width: 1
        border.color: root.argb(accent, 0.25)

        Text {
            id: clockText
            anchors.centerIn: parent
            color: foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15

            property date now: new Date()
            text: Qt.formatDateTime(now, "hh:mm  ddd, d MMM")

            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clockText.now = new Date()
            }
        }
    }

    // Login card - only on the primary screen, so a multi-monitor setup gets exactly
    // one, not one duplicated per screen.
    Rectangle {
        id: card
        visible: primaryScreen
        anchors.centerIn: parent
        width: 400
        height: cardColumn.implicitHeight + 48
        radius: 14
        color: root.argb(popupColor, popupOpacity)
        border.width: 1
        border.color: root.argb(accent, 0.35)

        Column {
            id: cardColumn
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 14

            Text {
                width: parent.width
                text: textConstants.welcomeText.arg(sddm.hostName)
                color: accent
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            TextBox {
                id: userField
                width: parent.width
                height: 40
                radius: 8
                color: background
                borderColor: mutedColor
                hoverColor: accent
                focusColor: accent
                textColor: foreground
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                text: userModel.lastUser

                KeyNavigation.tab: passwordField
                Keys.onReturnPressed: passwordField.forceActiveFocus()
            }

            PasswordBox {
                id: passwordField
                width: parent.width
                height: 40
                radius: 8
                color: background
                borderColor: mutedColor
                hoverColor: accent
                focusColor: accent
                textColor: foreground
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14

                KeyNavigation.tab: loginButton
                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.tryLogin()
                        event.accepted = true
                    }
                }
            }

            // Login button: plain Rectangle + MouseArea, not SddmComponents' Button.
            // That component's background can get stuck on its pressed/hover color
            // instead of reverting to idle, because it drives color through named
            // `states` while also assigning it as a plain (non-bound) property - once
            // something sets it outside the state machine, the "idle" state has nothing
            // to revert to. Binding color straight to containsMouse here has no such
            // intermediate state to get stuck in.
            Rectangle {
                id: loginButton
                width: parent.width
                height: 40
                radius: 8
                color: loginArea.containsMouse ? Qt.lighter(accent, 1.15) : accent

                Text {
                    anchors.centerIn: parent
                    text: textConstants.login
                    color: "#0f111a"
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    font.pixelSize: 14
                }

                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tryLogin()
                }

                Keys.onReturnPressed: root.tryLogin()
                KeyNavigation.tab: shutdownButton
            }

            Text {
                id: statusText
                width: parent.width
                height: 16
                horizontalAlignment: Text.AlignHCenter
                color: "#e88388"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    id: shutdownButton
                    width: (parent.width - 10) / 2
                    height: 36
                    radius: 8
                    color: shutdownArea.containsMouse ? root.argb(mutedColor, 0.35) : "transparent"
                    border.width: 1
                    border.color: shutdownArea.containsMouse ? accent : mutedColor

                    Text {
                        anchors.centerIn: parent
                        text: textConstants.shutdown
                        color: shutdownArea.containsMouse ? accent : foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: shutdownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.powerOff()
                    }

                    KeyNavigation.tab: rebootButton
                }

                Rectangle {
                    id: rebootButton
                    width: (parent.width - 10) / 2
                    height: 36
                    radius: 8
                    color: rebootArea.containsMouse ? root.argb(mutedColor, 0.35) : "transparent"
                    border.width: 1
                    border.color: rebootArea.containsMouse ? accent : mutedColor

                    Text {
                        anchors.centerIn: parent
                        text: textConstants.reboot
                        color: rebootArea.containsMouse ? accent : foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: rebootArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.reboot()
                    }

                    KeyNavigation.tab: sessionCombo
                }
            }

            // Session/layout row last, not between the password field and the login
            // button: SddmComponents' ComboBox/LayoutBox open their dropdown as a plain
            // child Rectangle anchored below themselves, not a top-level popup - it
            // paints under whatever comes after it in the Column (it did, right under
            // the login/shutdown/reboot buttons, when this row was above them). Nothing
            // else in the card comes after this row now, so there's nothing left to
            // paint over it.
            Row {
                width: parent.width
                spacing: 10

                ComboBox {
                    id: sessionCombo
                    width: (parent.width - 10) / 2
                    height: 36
                    model: sessionModel
                    index: sessionModel.lastIndex
                    color: background
                    borderColor: mutedColor
                    hoverColor: accent
                    focusColor: accent
                    textColor: foreground
                    menuColor: background
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12

                    KeyNavigation.tab: layoutBox
                }

                LayoutBox {
                    id: layoutBox
                    width: (parent.width - 10) / 2
                    height: 36
                    color: background
                    borderColor: mutedColor
                    hoverColor: accent
                    focusColor: accent
                    textColor: foreground
                    menuColor: background
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12

                    KeyNavigation.tab: userField
                }
            }
        }
    }

    // Note: the keyboard layout showing/defaulting to the wrong thing until the first
    // keypress (github.com/sddm/sddm#1845) is a confirmed, still-open upstream SDDM 0.21
    // bug, reproducible with every theme including SDDM's own bundled ones - not
    // something fixable from a theme's QML. Two different property-reassignment
    // workarounds were tried here and removed again; neither helped, which tracks with
    // this being a backend issue, not a frontend one.

    Component.onCompleted: {
        if (primaryScreen) {
            if (userField.text === "")
                userField.forceActiveFocus()
            else
                passwordField.forceActiveFocus()
        }
    }
}
