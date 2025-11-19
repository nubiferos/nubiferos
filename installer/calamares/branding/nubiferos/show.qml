import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Welcome to NubiferOS"
                    font.pixelSize: 32
                    font.bold: true
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Cloud Development Made Secure"
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#34495e"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "Installing Your System"
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "• Secure by default with full disk encryption\n• Cloud tools ready to use\n• Workspace isolation with Firejail"
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Almost Done!"
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Your secure cloud development environment\nis being configured..."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
