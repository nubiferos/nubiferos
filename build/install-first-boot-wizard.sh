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
Icon=preferences-system
Terminal=false
Categories=System;Settings;
Keywords=setup;welcome;wizard;configure;
EOF

# Install HTML documentation
log "INFO" "Installing documentation..."
mkdir -p "${CHROOT_DIR}/usr/share/nubifer/docs"
cp "${PROJECT_ROOT}/components/first-boot-wizard/docs/"*.html "${CHROOT_DIR}/usr/share/nubifer/docs/"

# Create desktop documentation link desktop file
cat > "${CHROOT_DIR}/usr/share/applications/nubifer-docs.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferOS Docs
Comment=NubiferOS Documentation and Guides
Exec=xdg-open /usr/share/nubifer/docs/index.html
Icon=help-browser
Terminal=false
Categories=Documentation;
Keywords=help;documentation;guide;nubifer;
EOF

# Create skeleton desktop entries for new users
log "INFO" "Setting up desktop shortcuts for new users..."
mkdir -p "${CHROOT_DIR}/etc/skel/Desktop"

# NubiferOS Setup shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/nubifer-setup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferOS Setup
Comment=Run the NubiferOS setup wizard
Exec=/usr/local/bin/nubifer-welcome --force
Icon=preferences-system
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/nubifer-setup.desktop"

# NubiferOS Docs shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/nubifer-docs.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferOS Docs
Comment=Documentation and Guides
Exec=xdg-open /usr/share/nubifer/docs/index.html
Icon=help-browser
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/nubifer-docs.desktop"

log "INFO" "First-boot wizard and documentation installed"
