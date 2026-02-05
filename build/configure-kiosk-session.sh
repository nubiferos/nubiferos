#!/bin/bash
# Configure kiosk session for NubiferOS installer
# Part of NubiferOS build system - Kiosk Mode Implementation
#
# This script configures:
# - Getty auto-login on tty1 (no graphical login manager)
# - Virtual terminal lockdown (mask tty2-6)
# - X server VT switching disabled
# - Installer user session files (.bash_profile, .xinitrc, .bash_logout)
# - Automatic reboot when Calamares exits

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "=========================================="
log "INFO" "Configuring Kiosk Session"
log "INFO" "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Directories
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

# Verify chroot exists
if [ ! -d "${CHROOT_DIR}/bin" ]; then
    log "ERROR" "Chroot directory not found. Run extract-debian.sh first."
    exit 1
fi

# Function to run commands in chroot
chroot_exec() {
    chroot "${CHROOT_DIR}" /bin/bash -c "$*"
}

# Create installer user (if not exists)
create_installer_user() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Installer User for Kiosk Mode"
    log "INFO" "=========================================="
    
    # Check if user already exists (created by install-desktop-installer.sh)
    if chroot_exec "id installer" &>/dev/null; then
        log "INFO" "Installer user already exists"
    else
        log "INFO" "Creating installer user..."
        chroot_exec "useradd -m -s /bin/bash -c 'Installer User' installer"
        chroot_exec "echo 'installer:installer' | chpasswd"
    fi
    
    # Add to minimal groups (audio, video for Calamares)
    chroot_exec "usermod -aG audio,video,plugdev,netdev installer"
    
    # Replace the full sudo access with restricted kiosk sudo
    # (install-desktop-installer.sh gives full sudo, we restrict it for kiosk)
    log "INFO" "Configuring restricted sudo access for kiosk mode..."
    rm -f "${CHROOT_DIR}/etc/sudoers.d/installer" 2>/dev/null || true
    cat > "${CHROOT_DIR}/etc/sudoers.d/installer-kiosk" << 'EOF'
# Installer user can ONLY run these specific commands without password
# This is for kiosk mode - reboot when Calamares exits
installer ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot
installer ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot --force
installer ALL=(ALL) NOPASSWD: /usr/sbin/reboot
installer ALL=(ALL) NOPASSWD: /usr/bin/calamares
EOF
    chmod 0440 "${CHROOT_DIR}/etc/sudoers.d/installer-kiosk"
    
    log "INFO" "✓ Installer user configured for kiosk mode"
}

# Configure getty auto-login on tty1
configure_getty_autologin() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Getty Auto-Login"
    log "INFO" "=========================================="
    
    # Create override directory for getty@tty1
    mkdir -p "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d"
    
    # Configure auto-login for installer user on tty1
    cat > "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin installer --noclear %I $TERM
Type=idle
EOF
    
    log "INFO" "✓ Getty auto-login configured for tty1"
}

# Mask getty services for tty2-6 (prevent VT switching)
mask_getty_services() {
    log "INFO" "=========================================="
    log "INFO" "Masking Getty Services (tty2-6)"
    log "INFO" "=========================================="
    
    # Mask getty services for tty2-6
    for tty in tty2 tty3 tty4 tty5 tty6; do
        log "INFO" "Masking getty@${tty}.service..."
        chroot_exec "systemctl mask getty@${tty}.service"
    done
    
    # Also mask ctrl-alt-del.target to prevent Ctrl+Alt+Delete reboot
    log "INFO" "Masking ctrl-alt-del.target..."
    chroot_exec "systemctl mask ctrl-alt-del.target"
    
    log "INFO" "✓ Getty services masked for tty2-6"
}

# Set default systemd target to multi-user (no graphical.target)
configure_systemd_target() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Systemd Default Target"
    log "INFO" "=========================================="
    
    # Set default target to multi-user (no graphical login manager)
    chroot_exec "systemctl set-default multi-user.target"
    
    # Disable any display managers that might be installed
    chroot_exec "systemctl disable gdm3.service 2>/dev/null || true"
    chroot_exec "systemctl disable lightdm.service 2>/dev/null || true"
    chroot_exec "systemctl disable sddm.service 2>/dev/null || true"
    
    log "INFO" "✓ Default target set to multi-user.target"
}

# Configure X server to disable VT switching
configure_xorg_lockdown() {
    log "INFO" "=========================================="
    log "INFO" "Configuring X Server VT Lockdown"
    log "INFO" "=========================================="
    
    # Create xorg.conf.d directory
    mkdir -p "${CHROOT_DIR}/etc/X11/xorg.conf.d"
    
    # Disable VT switching and Zap (Ctrl+Alt+Backspace)
    cat > "${CHROOT_DIR}/etc/X11/xorg.conf.d/10-no-vt-switch.conf" << 'EOF'
# Disable virtual terminal switching for kiosk mode
# This prevents Ctrl+Alt+F1-F6 from switching to other terminals

Section "ServerFlags"
    # Disable VT switching (Ctrl+Alt+Fn)
    Option "DontVTSwitch" "true"
    
    # Disable Zap (Ctrl+Alt+Backspace to kill X)
    Option "DontZap" "true"
EndSection
EOF
    
    log "INFO" "✓ X server VT lockdown configured"
}

# Configure sysctl to disable SysRq
configure_sysctl_lockdown() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Sysctl Lockdown"
    log "INFO" "=========================================="
    
    # Create sysctl configuration to disable SysRq
    mkdir -p "${CHROOT_DIR}/etc/sysctl.d"
    cat > "${CHROOT_DIR}/etc/sysctl.d/99-kiosk-lockdown.conf" << 'EOF'
# Disable SysRq key for kiosk mode security
# This prevents Alt+SysRq+key combinations
kernel.sysrq = 0
EOF
    
    log "INFO" "✓ SysRq disabled via sysctl"
}

# Create .bash_profile for auto-starting X
create_bash_profile() {
    log "INFO" "=========================================="
    log "INFO" "Creating .bash_profile (Auto-Start X)"
    log "INFO" "=========================================="
    
    # Create .bash_profile that auto-starts X on tty1
    cat > "${CHROOT_DIR}/home/installer/.bash_profile" << 'EOF'
#!/bin/bash
# NubiferOS Kiosk Mode - Auto-start X session
# This script runs when the installer user logs in on tty1

# Only start X if:
# 1. We're on tty1
# 2. DISPLAY is not already set (X not running)
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    echo "Starting NubiferOS Installer..."
    
    # Start X with error handling
    if ! startx -- -keeptty > /tmp/startx.log 2>&1; then
        echo ""
        echo "=========================================="
        echo "ERROR: X session failed to start"
        echo "=========================================="
        echo "Check /tmp/startx.log for details"
        echo ""
        echo "System will reboot in 30 seconds..."
        echo "Press Ctrl+C to cancel (if available)"
        sleep 30
        sudo systemctl reboot --force
    fi
fi
EOF
    
    chroot_exec "chown installer:installer /home/installer/.bash_profile"
    chmod 644 "${CHROOT_DIR}/home/installer/.bash_profile"
    
    log "INFO" "✓ .bash_profile created"
}

# Create .xinitrc for minimal X session
create_xinitrc() {
    log "INFO" "=========================================="
    log "INFO" "Creating .xinitrc (Minimal X Session)"
    log "INFO" "=========================================="
    
    # Create .xinitrc that launches only Calamares
    cat > "${CHROOT_DIR}/home/installer/.xinitrc" << 'EOF'
#!/bin/bash
# NubiferOS Kiosk Mode - Minimal X Session
# This script configures X and launches ONLY Calamares

# Disable screen blanking
xset s off
xset s noblank

# Disable DPMS (Display Power Management)
xset -dpms

# Disable VT switching via keyboard
setxkbmap -option srvrkeys:none 2>/dev/null || true

# Set solid background color (NubiferOS dark theme)
xsetroot -solid "#2e3440"

# Log session start
echo "$(date): Starting Calamares installer" >> /tmp/kiosk-session.log

# Launch Calamares as the ONLY application
# The -d flag enables debug mode for troubleshooting
sudo calamares -d

# Log session end
echo "$(date): Calamares exited with code $?" >> /tmp/kiosk-session.log

# When Calamares exits (for ANY reason), reboot the system
# This ensures no shell access is possible
echo "Installation complete or cancelled. Rebooting..."
sleep 2
sudo systemctl reboot --force
EOF
    
    chroot_exec "chown installer:installer /home/installer/.xinitrc"
    chmod 755 "${CHROOT_DIR}/home/installer/.xinitrc"
    
    log "INFO" "✓ .xinitrc created"
}

# Create .bash_logout for fallback reboot
create_bash_logout() {
    log "INFO" "=========================================="
    log "INFO" "Creating .bash_logout (Fallback Reboot)"
    log "INFO" "=========================================="
    
    # Create .bash_logout as a fallback reboot mechanism
    cat > "${CHROOT_DIR}/home/installer/.bash_logout" << 'EOF'
#!/bin/bash
# NubiferOS Kiosk Mode - Fallback Reboot
# This script runs when the installer user logs out
# It ensures the system reboots even if X exits unexpectedly

echo "Session ended. Rebooting system..."

# Small delay to allow any cleanup
sleep 1

# Try multiple methods to ensure reboot happens
sudo systemctl reboot --force 2>/dev/null || \
    sudo reboot -f 2>/dev/null || \
    echo b > /proc/sysrq-trigger 2>/dev/null || \
    true
EOF
    
    chroot_exec "chown installer:installer /home/installer/.bash_logout"
    chmod 755 "${CHROOT_DIR}/home/installer/.bash_logout"
    
    log "INFO" "✓ .bash_logout created"
}

# Validate all kiosk configuration files exist
validate_kiosk_config() {
    log "INFO" "=========================================="
    log "INFO" "Validating Kiosk Configuration"
    log "INFO" "=========================================="
    
    local required_files=(
        "${CHROOT_DIR}/home/installer/.bash_profile"
        "${CHROOT_DIR}/home/installer/.xinitrc"
        "${CHROOT_DIR}/home/installer/.bash_logout"
        "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf"
        "${CHROOT_DIR}/etc/X11/xorg.conf.d/10-no-vt-switch.conf"
        "${CHROOT_DIR}/etc/sysctl.d/99-kiosk-lockdown.conf"
        "${CHROOT_DIR}/etc/sudoers.d/installer-kiosk"
    )
    
    local missing=false
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log "ERROR" "Missing required file: $file"
            missing=true
        else
            log "INFO" "  ✓ $(basename $file)"
        fi
    done
    
    if [ "$missing" = true ]; then
        log "ERROR" "Kiosk configuration validation FAILED"
        exit 1
    fi
    
    log "INFO" "✓ All kiosk configuration files validated"
}

# Install X11 packages needed for kiosk startx session
# (install-desktop-installer.sh installs GNOME/GDM but not xinit)
install_kiosk_x11() {
    log "INFO" "=========================================="
    log "INFO" "Installing X11 Packages for Kiosk Session"
    log "INFO" "=========================================="

    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xinit \
        x11-xserver-utils \
        x11-utils \
        xserver-xorg-video-fbdev \
        xserver-xorg-video-vesa"

    log "INFO" "✓ X11 kiosk packages installed (xinit/startx)"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Kiosk Session Configuration"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "=========================================="

    install_kiosk_x11
    create_installer_user
    configure_getty_autologin
    mask_getty_services
    configure_systemd_target
    configure_xorg_lockdown
    configure_sysctl_lockdown
    create_bash_profile
    create_xinitrc
    create_bash_logout
    validate_kiosk_config
    
    log "INFO" "=========================================="
    log "INFO" "Kiosk session configuration complete!"
    log "INFO" "=========================================="
    log "INFO" "Boot flow: getty auto-login → .bash_profile → startx → .xinitrc → Calamares → reboot"
    log "INFO" "Security: VT switching disabled, no shell access, auto-reboot on exit"
    log "INFO" "=========================================="
}

main "$@"
