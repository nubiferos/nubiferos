/* === This file is part of Calamares - <https://calamares.io> ===
 *
 *   SPDX-FileCopyrightText: 2015 Teo Mrnjavac <teo@kde.org>
 *   SPDX-FileCopyrightText: 2018 Adriaan de Groot <groot@kde.org>
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *
 *   Calamares is Free Software: see the License-Identifier above.
 *
 *
 *   NubiferOS Custom Slideshow
 *   Simple text-based slideshow without complex QML animations
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        console.log("QML Component (default slideshow) Next slide");
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 35000  // 35 seconds per slide
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "☁️ Welcome to NubiferOS"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "The Cloud Engineer's Workstation"
                    font.pixelSize: 20
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Built for managing multiple cloud accounts securely, without the complexity."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🔒 Workspace Isolation"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Each cloud account gets its own isolated workspace."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "NubiferOS uses Firejail namespaces - your AWS prod credentials can never leak to your dev environment."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "👁️ Visual Context"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Always know which account you're in."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "The context indicator shows your active cloud provider, account, and region in real-time. No more 'wrong account' disasters."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🔐 Triple-Layer Encryption"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Your credentials are encrypted three times:"
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "LUKS disk encryption + GPG encryption + GNOME Keyring. We take security seriously."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🛡️ Read-Only Mode"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Production accounts should be read-only by default."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "NubiferOS enforces read-only mode at the system level - destructive commands are blocked until you explicitly enable writes."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "⚡ Zero Configuration"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "All major cloud tools come pre-installed."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "AWS CLI, Azure CLI, gcloud, Terraform, kubectl, Helm, and more. Start working immediately."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "✅ Battle-Tested Security"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "We don't build custom crypto - we use proven tools."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "GPG for encryption (30+ years), pass for credential storage (audited by security professionals), Wayland for display isolation."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "💰 Prevent Disasters"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e67e22"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "The average cost of a wrong-account mistake: $50,000+"
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Workspace isolation makes it physically impossible to run 'terraform destroy' in the wrong AWS account."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🔒 Privacy First"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#9b59b6"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Your credentials never leave your machine."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "No telemetry, no cloud sync, no data collection. Your cloud keys stay on your disk, encrypted."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🐧 Built on Debian"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#c0392b"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "NubiferOS is built on Debian 12 (Bookworm)."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Stable, secure, and backed by decades of community expertise. Security updates are automatic."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🖥️ Wayland Security"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "GNOME with Wayland prevents keylogging between applications."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Unlike X11, apps can't spy on each other's keyboard input or screenshots. Critical for credential security."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "📦 Firejail Isolation"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#16a085"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Each workspace runs in isolated Linux namespaces."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Mount, PID, IPC, and UTS namespaces ensure complete separation. Think lightweight containers, but faster."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "📖 Open Source"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "NubiferOS is fully open source."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Audit the code, contribute improvements, or fork it. Security through transparency."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "🔧 CLI Wrappers"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Cloud CLI tools are wrapped for security."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Credentials are injected securely without environment variable exposure. Read-only enforcement happens at the wrapper level."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        
        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.8
                
                Text {
                    text: "✨ Almost Done!"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Installation complete in moments..."
                    font.pixelSize: 18
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: "Next step: Create your first workspace and add your cloud credentials. Welcome to secure cloud management."
                    font.pixelSize: 16
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    function onActivate() {
        console.log("QML Component (default slideshow) activated");
        presentation.currentSlide = 0;
    }

    function onLeave() {
        console.log("QML Component (default slideshow) deactivated");
    }
}
