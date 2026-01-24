#!/bin/bash
# Install the NubiferOS first-boot welcome wizard
# Part of NubiferOS build system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "Installing NubiferOS first-boot wizard..."

# Install Python dependencies for GTK4
log "INFO" "Installing Python GTK4 dependencies..."
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1 \
    libadwaita-1-0"

# Copy the welcome wizard script
log "INFO" "Installing welcome wizard..."
cp "${PROJECT_ROOT}/components/first-boot-wizard/nubifer-welcome" "${CHROOT_DIR}/usr/local/bin/"
chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-welcome"

# Copy the autostart desktop file for all users
log "INFO" "Installing autostart entry..."
mkdir -p "${CHROOT_DIR}/etc/xdg/autostart"
cp "${PROJECT_ROOT}/components/first-boot-wizard/nubifer-welcome.desktop" "${CHROOT_DIR}/etc/xdg/autostart/"

# Create application desktop entry (for manual launch from app menu)
mkdir -p "${CHROOT_DIR}/usr/share/applications"
cat > "${CHROOT_DIR}/usr/share/applications/nubifer-welcome.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferOS Setup
Comment=Run the NubiferOS first-boot setup wizard
Exec=/usr/local/bin/nubifer-welcome --force
Icon=computer
Terminal=false
Categories=System;Settings;
Keywords=setup;welcome;wizard;configure;
EOF

log "INFO" "First-boot wizard installed"
