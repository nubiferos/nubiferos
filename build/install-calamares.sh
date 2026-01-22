#!/bin/bash
# Install and configure Calamares installer for NubiferOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Installing Calamares installer..."

# Enable bookworm-backports for newer Calamares
log "INFO" "Enabling bookworm-backports for Calamares 3.3.8..."
cat >> "${CHROOT_DIR}/etc/apt/sources.list" << 'EOF'

# Bookworm Backports for Calamares 3.3.8
deb http://deb.debian.org/debian bookworm-backports main contrib non-free
EOF

# Update package lists
chroot_exec "apt-get update"

# Install Calamares 3.3.8 from backports
log "INFO" "Installing Calamares 3.3.8 from backports..."
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y -t bookworm-backports \
    calamares \
    qml-module-qtquick2 \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2 \
    qml-module-qtquick-dialogs \
    qml-module-qtgraphicaleffects \
    libkf5config-bin \
    libkf5coreaddons5 \
    libkpmcore12 \
    libpolkit-qt5-1-1"

# Note: calamares-settings-debian is not needed for 3.3.x
log "INFO" "Calamares 3.3.8 installed from backports"

# Create Calamares configuration directory
log "INFO" "Creating Calamares configuration..."
mkdir -p "${CHROOT_DIR}/etc/calamares"
mkdir -p "${CHROOT_DIR}/etc/calamares/modules"
mkdir -p "${CHROOT_DIR}/etc/calamares/branding/nubiferos"

# Copy Calamares configuration files
log "INFO" "Copying configuration files..."
cp -r "${PROJECT_ROOT}/installer/calamares/"* "${CHROOT_DIR}/etc/calamares/" || true

# Copy Calamares helper scripts to /usr/local/bin
log "INFO" "Installing Calamares helper scripts..."
mkdir -p "${CHROOT_DIR}/usr/local/bin"
for script in "${PROJECT_ROOT}/scripts/calamares-"*.sh; do
    if [ -f "$script" ]; then
        cp "$script" "${CHROOT_DIR}/usr/local/bin/"
        chmod +x "${CHROOT_DIR}/usr/local/bin/$(basename "$script")"
        log "INFO" "  Installed: $(basename "$script")"
    fi
done

# Also copy other helper scripts needed by Calamares
for script in calamares-config-logger.sh grub-install-luks-wrapper.sh grub-install-safe-wrapper.sh grub-mkconfig-safe-wrapper.sh; do
    if [ -f "${PROJECT_ROOT}/scripts/$script" ]; then
        cp "${PROJECT_ROOT}/scripts/$script" "${CHROOT_DIR}/usr/local/bin/"
        chmod +x "${CHROOT_DIR}/usr/local/bin/$script"
        log "INFO" "  Installed: $script"
    fi
done

# Fix sudoers permissions issue
log "INFO" "Fixing sudoers permissions..."
chroot_exec "chmod 755 /etc/sudoers.d || true"
chroot_exec "chmod 440 /etc/sudoers.d/* || true"

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
