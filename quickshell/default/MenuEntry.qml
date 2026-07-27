import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property string label
    required property string icon
    signal triggered()

    Layout.fillWidth: true
    implicitHeight: 32
    radius: 8
    color: ma.containsMouse ? "#1793d1" : "transparent"

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: ma.containsMouse ? "#0f111a" : "#7aa2f7"
        }

        Text {
            text: root.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: ma.containsMouse ? "#0f111a" : "#c0caf5"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.triggered()
    }
}
