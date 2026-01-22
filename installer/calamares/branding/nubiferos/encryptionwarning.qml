/* NubiferOS Encryption Warning Page
 * Displayed after partition selection to remind users about encryption requirement
 */

import QtQuick 2.10
import QtQuick.Controls 2.10
import QtQuick.Layouts 1.3
import io.calamares.core 1.0
import io.calamares.ui 1.0

Page {
    id: encryptionWarningPage

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.85
            spacing: 25

            // Warning header
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15

                Text {
                    text: "\u26A0"
                    font.pixelSize: 52
                    color: "#f39c12"
                }

                Text {
                    text: "Encryption Reminder"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                }
            }

            // Main warning box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: warningText.implicitHeight + 40
                color: "#16213e"
                radius: 10
                border.color: "#e74c3c"
                border.width: 3

                Text {
                    id: warningText
                    anchors.fill: parent
                    anchors.margins: 20
                    wrapMode: Text.WordWrap
                    color: "#ecf0f1"
                    font.pixelSize: 16
                    lineHeight: 1.5
                    horizontalAlignment: Text.AlignHCenter
                    text: "NubiferOS requires full disk encryption to protect your cloud credentials.\n\n" +
                          "Did you enable 'Encrypt system' on the partition page?\n\n" +
                          "If NOT, click 'Back' now to enable encryption."
                }
            }

            // Why it matters
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: whyColumn.implicitHeight + 30
                color: "#0f3460"
                radius: 10

                Column {
                    id: whyColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "Why is encryption required?"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#f39c12"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#bdc3c7"
                        font.pixelSize: 14
                        lineHeight: 1.4
                        text: "\u2022 Your AWS, Azure, and GCP credentials will be stored on this system\n" +
                              "\u2022 Without encryption, a stolen laptop = stolen cloud credentials\n" +
                              "\u2022 Encryption is the foundation of NubiferOS's security model\n" +
                              "\u2022 There is no way to enable encryption after installation"
                    }
                }
            }

            // Confirmation
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: confirmText.implicitHeight + 20
                color: "#1e5128"
                radius: 8

                Text {
                    id: confirmText
                    anchors.centerIn: parent
                    width: parent.width - 40
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    text: "If you have enabled encryption, click 'Next' to continue."
                }
            }
        }
    }
}
