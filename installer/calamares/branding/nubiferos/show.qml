/* === This file is part of Calamares - <https://calamares.io> ===
 *
 *   SPDX-FileCopyrightText: 2015 Teo Mrnjavac <teo@kde.org>
 *   SPDX-FileCopyrightText: 2018 Adriaan de Groot <groot@kde.org>
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *
 *   Calamares is Free Software: see the License-Identifier above.
 *
 *
 *   NubiferOS Custom Slideshow - Three-Part Format
 *   Headline / Technical / Plain English
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

    // SLIDE 1 - WELCOME
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Welcome to NubiferOS - The Cloud Engineer's Workstation"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Built on Debian 12 with GNOME/Wayland. Workspace isolation via Firejail. Credentials encrypted with GPG + pass."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "A Linux distro specifically designed for managing multiple cloud accounts securely. Everything you need is already configured."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 2 - WORKSPACE ISOLATION
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Each cloud account gets its own isolated workspace."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Firejail creates isolated Linux namespaces - separate filesystems, processes, and memory for each environment."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Your production credentials stay in production, dev stays in dev. Complete separation at the kernel level."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 3 - VISUAL CONTEXT
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "GNOME Shell extension displays current workspace context in the system tray."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Updates via D-Bus signals when switching workspaces. Color-coded by provider: AWS=Orange, Azure=Blue, GCP=Multi-color."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "You always know which cloud account you're working in. The indicator changes instantly when you switch workspaces."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 4 - CREDENTIAL SECURITY
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Three-layer credential encryption stack."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "LUKS2 (disk) -> GPG via pass (storage) -> GNOME Keyring (runtime). Credentials never touch disk in plaintext."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "If someone steals your laptop, your cloud provider keys are protected by three layers of encryption. They'd need your disk passphrase, your GPG key, AND your keyring password."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 5 - READ-ONLY MODE
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Read-only mode enforcement at the CLI wrapper level."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Commands like `terraform destroy`, `aws ec2 terminate-instances`, `az vm delete` return errors unless workspace.read_only=false."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Destructive commands are blocked by default in production workspaces. You have to explicitly enable write operations first."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 6 - ZERO CONFIGURATION
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Pre-installed cloud toolchain: AWS CLI v2, Azure CLI, gcloud SDK, Terraform, kubectl, Helm, k9s, eksctl."
                    font.pixelSize: 24
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Also included: Docker, Ansible, CDK, SAM CLI. No manual installation or PATH configuration needed."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Install once, start working immediately. No spending days setting up and configuring cloud tools."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 7 - BATTLE-TESTED SECURITY
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Security stack uses audited, battle-tested tools - no custom crypto."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "GPG (GNU Privacy Guard, est. 1999), pass (Unix password manager), Wayland compositor (app isolation), AppArmor (mandatory access control)."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "We use tools that have been security-audited for decades instead of writing our own encryption. Proven technology you can trust."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 8 - PREVENT DISASTERS
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Workspace isolation prevents cross-account command execution."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#e67e22"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Each workspace uses separate mount, PID, IPC, and UTS namespaces. Commands in workspace A cannot affect resources in workspace B."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Running `terraform destroy` in your dev workspace can't accidentally touch production. Physically separate environments."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 9 - PRIVACY FIRST
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Zero telemetry. All credential operations are local-only."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#9b59b6"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Pass stores credentials in ~/.password-store/ encrypted with your GPG key. No network operations, no external services, no data collection."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Your cloud provider credentials stay on your machine, encrypted. Nothing phones home, nothing gets uploaded."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 10 - BUILT ON DEBIAN
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Built on Debian 12 (Bookworm) stable base."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#c0392b"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Unattended-upgrades enabled for automatic security patches. AppArmor profiles enforced. Firewall (ufw) deny-by-default."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Security updates happen automatically. The system is hardened by default. Solid, stable foundation you can rely on."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 11 - WAYLAND SECURITY
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Wayland compositor isolates application input/output."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e74c3c"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Unlike X11, Wayland prevents applications from reading other apps' keyboard input or capturing screenshots without permission."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Wayland protects against common keylogging attacks where malicious apps spy on your keyboard input."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 12 - FIREJAIL ISOLATION
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Firejail provides namespace isolation without container overhead."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#16a085"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Mount namespace: separate filesystem views. PID namespace: isolated process trees. IPC namespace: no shared memory between workspaces."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Think lightweight containers but faster. About 10ms startup overhead compared to 100ms+ for Docker. Same isolation, less weight."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 13 - OPEN SOURCE
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Fully open source. All code auditable on GitHub."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Components: credential-manager (Python + libsecret), context-manager (D-Bus service), CLI wrappers, GNOME Shell extension."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "You can audit every line of code. Contribute improvements. Fork it if you want. Security through transparency."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 14 - CLI WRAPPERS
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "CLI wrappers in /usr/local/bin/ intercept cloud commands."
                    font.pixelSize: 26
                    font.bold: true
                    color: "#3498db"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Inject credentials via D-Bus from credential-manager. Enforce read-only mode by blocking write operations (create*, delete*, terminate*)."
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "When you type cloud commands, NubiferOS securely injects the right credentials and checks read-only mode first. Automatic safety checks."
                    font.pixelSize: 15
                    color: "#bdc3c7"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // SLIDE 15 - ALMOST DONE
    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#2c3e50"

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.85

                Text {
                    text: "Installation finishing. Post-install steps:"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#27ae60"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "1. Generate GPG key (gpg --generate-key)\n2. Initialize pass (pass init <gpg-id>)\n3. Create first workspace (nubifer-workspace create)\n4. Add credentials (nubifer-creds add)"
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "What's that really mean?:"
                    font.pixelSize: 15
                    font.italic: true
                    color: "#f39c12"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Four commands and you're managing cloud accounts securely. Quick start guide will walk you through it."
                    font.pixelSize: 15
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
