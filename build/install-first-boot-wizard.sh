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

# Terminal shortcut (essential for CLI tools)
cat > "${CHROOT_DIR}/etc/skel/Desktop/terminal.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
Comment=Open a terminal for cloud CLI tools
Exec=gnome-terminal
Icon=utilities-terminal
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/terminal.desktop"

# Firefox shortcut (for cloud consoles)
cat > "${CHROOT_DIR}/etc/skel/Desktop/firefox.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web Browser for Cloud Consoles
Exec=firefox %u
Icon=firefox-esr
Terminal=false
MimeType=text/html;text/xml;application/xhtml+xml;
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/firefox.desktop"

# Cloud Bookmarks shortcut (opens HTML bookmarks page, also can import into Firefox)
cat > "${CHROOT_DIR}/etc/skel/Desktop/cloud-bookmarks.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Cloud Bookmarks
Comment=Browse or import NubiferOS cloud bookmarks
Exec=/usr/local/bin/nubifer-bookmarks
Icon=user-bookmarks
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/cloud-bookmarks.desktop"

# Files (Nautilus) shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/files.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Files
Comment=Access and organize files
Exec=nautilus --new-window %U
Icon=org.gnome.Nautilus
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/files.desktop"

# VS Code shortcut (if installed)
cat > "${CHROOT_DIR}/etc/skel/Desktop/vscode.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=VS Code
Comment=Code Editor
Exec=/usr/bin/code --no-sandbox %F
Icon=visual-studio-code
Terminal=false
StartupWMClass=Code
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/vscode.desktop"

# Software Center shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/software-center.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Software Center
Comment=Install cloud development tools
Exec=/usr/bin/nubifer-software
Icon=system-software-install
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/software-center.desktop"

# Security Dashboard shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/security-dashboard.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Security Dashboard
Comment=View system security status and NubiferOS health
Exec=/usr/local/bin/nubifer-dashboard
Icon=security-high
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/security-dashboard.desktop"

# NubiferAI shortcut
cat > "${CHROOT_DIR}/etc/skel/Desktop/nubiferai.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferAI
Comment=AI-native cloud operations
Exec=/usr/local/bin/nubiferai-gtk
Icon=weather-overcast-symbolic
Terminal=false
EOF
chmod +x "${CHROOT_DIR}/etc/skel/Desktop/nubiferai.desktop"

# Create a script to clean up shortcuts for apps that aren't installed
cat > "${CHROOT_DIR}/etc/profile.d/cleanup-desktop-shortcuts.sh" << 'CLEANUP_EOF'
#!/bin/bash
# Remove desktop shortcuts for apps that aren't installed
# Runs once on first login

DESKTOP_DIR="$HOME/Desktop"
CLEANUP_FLAG="$HOME/.config/desktop-shortcuts-cleaned"

if [ -f "$CLEANUP_FLAG" ]; then
    return 0
fi

if [ -d "$DESKTOP_DIR" ]; then
    # Remove VS Code shortcut if not installed
    if [ ! -f /usr/bin/code ] && [ -f "$DESKTOP_DIR/vscode.desktop" ]; then
        rm -f "$DESKTOP_DIR/vscode.desktop"
    fi

    # Remove NubiferAI shortcut if not installed
    if [ ! -f /usr/local/bin/nubiferai-gtk ] && [ -f "$DESKTOP_DIR/nubiferai.desktop" ]; then
        rm -f "$DESKTOP_DIR/nubiferai.desktop"
    fi

    # Trust all desktop files (GNOME requires this)
    for desktop_file in "$DESKTOP_DIR"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            gio set "$desktop_file" metadata::trusted true 2>/dev/null || true
        fi
    done
fi

# Mark as done
mkdir -p "$(dirname "$CLEANUP_FLAG")"
touch "$CLEANUP_FLAG"
CLEANUP_EOF
chmod +x "${CHROOT_DIR}/etc/profile.d/cleanup-desktop-shortcuts.sh"

log "INFO" "First-boot wizard and documentation installed"
log "INFO" "Desktop shortcuts added: Setup, Docs, Terminal, Firefox, Cloud Bookmarks, Files, VS Code, Software Center, NubiferAI"
