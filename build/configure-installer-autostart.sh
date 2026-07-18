#!/bin/bash
# Configure auto-login and Calamares auto-launch for installer environment
# This script is only needed for live ISOs with a live user

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Determine which user to use (live for live ISO, installer for installer-only)
if [ -d "${CHROOT_DIR}/home/live" ]; then
    BOOT_USER="live"
    log "INFO" "Configuring auto-login for live user..."
elif [ -d "${CHROOT_DIR}/home/installer" ]; then
    BOOT_USER="installer"
    log "INFO" "Configuring auto-login for installer user..."
else
    log "ERROR" "No boot user found (neither 'live' nor 'installer')"
    exit 1
fi

log "INFO" "Configuring auto-login and Calamares auto-launch for user: ${BOOT_USER}..."

# Configure getty for auto-login on tty1 (backup method)
log "INFO" "Configuring auto-login..."
mkdir -p "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d"
cat > "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${BOOT_USER} --noclear %I \$TERM
Type=idle
EOF

# Create systemd service to launch Calamares
log "INFO" "Creating Calamares launcher service..."
# Get UID for the boot user
BOOT_USER_UID=$(chroot_exec "id -u ${BOOT_USER}")
cat > "${CHROOT_DIR}/etc/systemd/system/calamares-autostart.service" << EOF
[Unit]
Description=Calamares Installer Auto-Start
After=graphical.target gdm.service
Wants=graphical.target

[Service]
Type=simple
User=${BOOT_USER}
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/${BOOT_USER_UID}
# Ensure XDG_RUNTIME_DIR exists before launching
ExecStartPre=/bin/mkdir -p /run/user/${BOOT_USER_UID}
ExecStartPre=/bin/chown ${BOOT_USER}:${BOOT_USER} /run/user/${BOOT_USER_UID}
ExecStartPre=/bin/chmod 700 /run/user/${BOOT_USER_UID}
ExecStartPre=/bin/sleep 5
ExecStartPre=/usr/bin/sudo /usr/local/bin/calamares-detect-tpm.sh
ExecStart=/usr/bin/sudo /usr/bin/calamares -d
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

# Create autologin group if it doesn't exist
log "INFO" "Creating autologin group..."
chroot_exec "getent group autologin || groupadd -r autologin"

# Add boot user to autologin group
log "INFO" "Adding ${BOOT_USER} to autologin group..."
chroot_exec "usermod -aG autologin ${BOOT_USER}"

# Debian GDM3 uses daemon.conf, NOT custom.conf
cat > "${CHROOT_DIR}/etc/gdm3/daemon.conf" << EOF
[daemon]
# Enable Wayland
WaylandEnable=true

# Auto-login for boot user
AutomaticLoginEnable=true
AutomaticLogin=${BOOT_USER}

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Also write to custom.conf as fallback (some systems check both)
cat > "${CHROOT_DIR}/etc/gdm3/custom.conf" << EOF
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=${BOOT_USER}

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Ensure PAM is configured for gdm-autologin
log "INFO" "Configuring PAM for gdm-autologin..."
if [ ! -f "${CHROOT_DIR}/etc/pam.d/gdm-autologin" ]; then
    cat > "${CHROOT_DIR}/etc/pam.d/gdm-autologin" << 'EOF'
#%PAM-1.0
auth    requisite       pam_nologin.so
auth    required        pam_succeed_if.so user ingroup autologin
auth    optional        pam_gnome_keyring.so
auth    optional        pam_kwallet5.so
auth    required        pam_permit.so
account include         gdm
password include        gdm
session include         gdm
EOF
fi

# Create .xinitrc for boot user to launch Calamares
log "INFO" "Creating .xinitrc for ${BOOT_USER}..."
if [ -d "${CHROOT_DIR}/home/${BOOT_USER}" ]; then
    cat > "${CHROOT_DIR}/home/${BOOT_USER}/.xinitrc" << 'EOF'
#!/bin/bash
# Start Calamares installer
exec sudo calamares -d
EOF
    chmod +x "${CHROOT_DIR}/home/${BOOT_USER}/.xinitrc"
    chroot_exec "chown ${BOOT_USER}:${BOOT_USER} /home/${BOOT_USER}/.xinitrc"
else
    log "WARN" "Boot user home directory not found, skipping .xinitrc creation"
fi

# Create desktop autostart entry as backup - launches Calamares maximized
log "INFO" "Creating desktop autostart entry..."
if [ -d "${CHROOT_DIR}/home/${BOOT_USER}" ]; then
    mkdir -p "${CHROOT_DIR}/home/${BOOT_USER}/.config/autostart"
    cat > "${CHROOT_DIR}/home/${BOOT_USER}/.config/autostart/calamares.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Install NubiferOS
Exec=sudo calamares -d
Icon=calamares
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
StartupWMClass=calamares
EOF
    chroot_exec "chown -R ${BOOT_USER}:${BOOT_USER} /home/${BOOT_USER}/.config"
else
    log "WARN" "Boot user home directory not found, skipping desktop autostart creation"
fi

# Window sizing: Calamares runs fullscreen via branding.desc windowSize.
# (The old wmctrl autostart maximizer was removed — wmctrl is a no-op on
# the Wayland session, and title-based matching was fragile.)

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

# Create simple launcher script for manual restart
log "INFO" "Creating manual launcher script..."
cat > "${CHROOT_DIR}/usr/local/bin/install-nubiferos" << 'EOF'
#!/bin/bash
# Simple script to launch Calamares installer
echo "Starting NubiferOS installer..."
sudo calamares -d
EOF
chmod +x "${CHROOT_DIR}/usr/local/bin/install-nubiferos"

# Create desktop shortcut
mkdir -p "${CHROOT_DIR}/home/${BOOT_USER}/Desktop"
cat > "${CHROOT_DIR}/home/${BOOT_USER}/Desktop/Install NubiferOS.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Install NubiferOS
Comment=Install NubiferOS to hard drive
Exec=install-nubiferos
Icon=calamares
Terminal=false
Categories=System;
EOF
chmod +x "${CHROOT_DIR}/home/${BOOT_USER}/Desktop/Install NubiferOS.desktop"
chroot_exec "chown ${BOOT_USER}:${BOOT_USER} '/home/${BOOT_USER}/Desktop/Install NubiferOS.desktop'"

log "INFO" "✓ Auto-login and Calamares auto-launch configured for ${BOOT_USER}"

# Disable screen lock and timeout for installer user
# This prevents the screen from locking during installation
log "INFO" "Disabling screen lock and timeout for installer..."

# Create dconf settings for the installer user to disable screen lock AND hide panel
mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d"
cat > "${CHROOT_DIR}/etc/dconf/db/local.d/00-installer-no-lock" << 'EOF'
# Disable screen lock and timeout during installation
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false
lock-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=0
sleep-inactive-battery-type='nothing'
idle-dim=false

# Hide the top panel during installation (GNOME Shell)
[org/gnome/shell]
disable-user-extensions=true
enabled-extensions=@as []

# Disable Activities hot corner
[org/gnome/desktop/interface]
enable-hot-corners=false

# Disable overview on startup
[org/gnome/shell]
welcome-dialog-last-shown-version='999.0'
EOF

# Create GNOME Shell extension to hide the panel during installation
log "INFO" "Creating panel-hiding extension for installer..."
mkdir -p "${CHROOT_DIR}/usr/share/gnome-shell/extensions/installer-mode@nubiferos"
cat > "${CHROOT_DIR}/usr/share/gnome-shell/extensions/installer-mode@nubiferos/metadata.json" << 'EOF'
{
    "uuid": "installer-mode@nubiferos",
    "name": "NubiferOS Installer Mode",
    "description": "Hides panel and disables desktop during installation",
    "shell-version": ["43", "44", "45", "46"],
    "version": 1
}
EOF

cat > "${CHROOT_DIR}/usr/share/gnome-shell/extensions/installer-mode@nubiferos/extension.js" << 'EOF'
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class InstallerModeExtension {
    enable() {
        // Hide the top panel
        Main.panel.hide();
        
        // Disable hot corners
        Main.layoutManager._startingUp = true;
    }
    
    disable() {
        // Show the panel again
        Main.panel.show();
        Main.layoutManager._startingUp = false;
    }
}
EOF

# Enable the installer-mode extension for the boot user
cat >> "${CHROOT_DIR}/etc/dconf/db/local.d/00-installer-no-lock" << 'EOF'

# Enable installer mode extension to hide panel
[org/gnome/shell]
enabled-extensions=['installer-mode@nubiferos']
disable-user-extensions=false
EOF

# Update dconf database
chroot_exec "dconf update 2>/dev/null || true"

# Lock the dconf settings so they can't be changed by the installer user
mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d/locks"
cat > "${CHROOT_DIR}/etc/dconf/db/local.d/locks/00-installer-locks" << 'EOF'
# Lock installer settings
/org/gnome/shell/enabled-extensions
/org/gnome/desktop/interface/enable-hot-corners
/org/gnome/desktop/session/idle-delay
/org/gnome/desktop/screensaver/lock-enabled
EOF

# Update dconf again with locks
chroot_exec "dconf update 2>/dev/null || true"

# Also set gsettings directly for the installer user as backup
if [ -d "${CHROOT_DIR}/home/${BOOT_USER}" ]; then
    cat > "${CHROOT_DIR}/home/${BOOT_USER}/.config/autostart/disable-screensaver.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Disable Screensaver
Exec=sh -c "gsettings set org.gnome.desktop.session idle-delay 0; gsettings set org.gnome.desktop.screensaver lock-enabled false; gsettings set org.gnome.desktop.screensaver idle-activation-enabled false"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Initialization
EOF
    chroot_exec "chown ${BOOT_USER}:${BOOT_USER} /home/${BOOT_USER}/.config/autostart/disable-screensaver.desktop"
fi

log "INFO" "✓ Screen lock and timeout disabled for installer"
