import QtQuick 2.0

// Empty slideshow - prevents QML threading segfault
// Just shows a blank area during installation

Rectangle {
    width: 800
    height: 600
    color: "#2c3e50"
    
    Text {
        anchors.centerIn: parent
        text: "Installing NubiferOS..."
        color: "#ffffff"
        font.pixelSize: 24
    }
}
