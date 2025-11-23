#!/bin/bash
# Install and configure Calamares installer for NubiferOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Installing Calamares installer..."

# Install Calamares and dependencies
log "INFO" "Installing Calamares packages..."
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    calamares \
    calamares-settings-debian \
    qml-module-qtquick2 \
    qml-module-qtquick-controls \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2"

# Create Calamares configuration directory
log "INFO" "Creating Calamares configuration..."
mkdir -p "${CHROOT_DIR}/etc/calamares"
mkdir -p "${CHROOT_DIR}/etc/calamares/modules"
mkdir -p "${CHROOT_DIR}/etc/calamares/branding/nubiferos"

# Copy Calamares configuration files
log "INFO" "Copying configuration files..."
cp -r "${PROJECT_ROOT}/installer/calamares/"* "${CHROOT_DIR}/etc/calamares/" || true

# Create autostart entry for installer user
log "INFO" "Creating autostart configuration..."
mkdir -p "${CHROOT_DIR}/etc/skel/.config/autostart"

cat > "${CHROOT_DIR}/etc/skel/.config/autostart/calamares.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Install NubiferOS
Comment=System Installer
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF

# Also create it for the live user if it exists
if [ -d "${CHROOT_DIR}/home/live" ]; then
    mkdir -p "${CHROOT_DIR}/home/live/.config/autostart"
    cp "${CHROOT_DIR}/etc/skel/.config/autostart/calamares.desktop" \
       "${CHROOT_DIR}/home/live/.config/autostart/"
    chroot_exec "chown -R live:live /home/live/.config"
fi

# Create it for installer user if it exists
if [ -d "${CHROOT_DIR}/home/installer" ]; then
    mkdir -p "${CHROOT_DIR}/home/installer/.config/autostart"
    cp "${CHROOT_DIR}/etc/skel/.config/autostart/calamares.desktop" \
       "${CHROOT_DIR}/home/installer/.config/autostart/"
    chroot_exec "chown -R installer:installer /home/installer/.config"
fi

log "INFO" "✓ Calamares installed and configured"
