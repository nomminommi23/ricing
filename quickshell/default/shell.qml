import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
	color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        
        // KORREKTUR: Qt.rgba nutzt Werte von 0.0 bis 1.0 statt 0-255
        // 30/255 ≈ 0.11, 46/255 ≈ 0.18, Transparenz 0.85
        color: Qt.rgba(0.11, 0.11, 0.18, 0.25) 
        
        // KORREKTUR: Auch hier das ältere Format für den Rahmen nutzen
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.1)
        border.width: 1

        Text {
            id: clockText
            anchors.centerIn: parent
            color: "#cdd6f4" // Hex-Codes funktionieren weiterhin einwandfrei
            font.pixelSize: 15
            font.bold: true
            
            text: Qt.formatDateTime(new Date(), "hh:mm:ss")
        }

        Timer {
            interval: 1000 
            running: true
            repeat: true
            onTriggered: {
                clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            }
        }
    }
}
