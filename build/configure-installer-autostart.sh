#!/bin/bash
# Configure auto-login and Calamares auto-launch for installer environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Configuring auto-login and Calamares auto-launch..."

# Create installer user
log "INFO" "Creating installer user..."
chroot_exec "useradd -m -s /bin/bash -G sudo installer || true"
chroot_exec "echo 'installer:installer' | chpasswd"

# Configure getty for auto-login on tty1
log "INFO" "Configuring auto-login..."
mkdir -p "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d"
cat > "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin installer --noclear %I $TERM
Type=idle
EOF

# Create systemd service to launch Calamares
log "INFO" "Creating Calamares launcher service..."
cat > "${CHROOT_DIR}/etc/systemd/system/calamares-autostart.service" << 'EOF'
[Unit]
Description=Calamares Installer Auto-Start
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=installer
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/calamares -d
Restart=on-failure
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

# Enable the Calamares autostart service
log "INFO" "Enabling Calamares autostart..."
chroot_exec "systemctl enable calamares-autostart.service"

# Configure GDM for auto-login (if using GDM)
log "INFO" "Configuring GDM auto-login..."
mkdir -p "${CHROOT_DIR}/etc/gdm3"
cat > "${CHROOT_DIR}/etc/gdm3/custom.conf" << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=installer

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Create .xinitrc for installer user to launch Calamares
log "INFO" "Creating .xinitrc for installer user..."
cat > "${CHROOT_DIR}/home/installer/.xinitrc" << 'EOF'
#!/bin/bash
# Start Calamares installer
exec calamares -d
EOF
chmod +x "${CHROOT_DIR}/home/installer/.xinitrc"
chroot_exec "chown installer:installer /home/installer/.xinitrc"

# Create desktop autostart entry as backup
log "INFO" "Creating desktop autostart entry..."
mkdir -p "${CHROOT_DIR}/home/installer/.config/autostart"
cat > "${CHROOT_DIR}/home/installer/.config/autostart/calamares.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Calamares Installer
Exec=calamares -d
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
chroot_exec "chown -R installer:installer /home/installer/.config"

# Configure Calamares exit behavior
log "INFO" "Configuring exit behavior..."
cat > "${CHROOT_DIR}/usr/local/bin/calamares-exit-handler" << 'EOF'
#!/bin/bash
# Handle Calamares exit - reboot or shutdown

if [ -f /tmp/calamares-install-success ]; then
    echo "Installation completed successfully. Rebooting..."
    systemctl reboot
else
    echo "Installation cancelled or failed. Shutting down..."
    systemctl poweroff
fi
EOF
chmod +x "${CHROOT_DIR}/usr/local/bin/calamares-exit-handler"

log "INFO" "✓ Auto-login and Calamares auto-launch configured"
