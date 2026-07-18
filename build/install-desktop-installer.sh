#!/bin/bash
# Install and configure desktop environment for INSTALLER-ONLY ISO
# Part of NubiferOS build system - Production/Alpha builds
#
# This script:
# 1. Installs GNOME, GDM, kernel, fonts (for the installed system)
# 2. Installs xinit/startx (for the locked-down installer session)
# 3. Locks down the live ISO: no GDM, no desktop access, bare X + Calamares only
# 4. Post-install cleanup (calamares-post-install-cleanup.sh) reverses the lockdown

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "Starting desktop installation (INSTALLER-ONLY, locked down)"

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

# Install Linux kernel
install_kernel() {
    log "INFO" "=========================================="
    log "INFO" "Installing Linux Kernel (Installer-Only)"
    log "INFO" "=========================================="

    # Install live-boot packages FIRST (before kernel generates initramfs)
    log "INFO" "Installing live-boot packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        initramfs-tools \
        live-boot \
        live-boot-initramfs-tools"

    # Now install kernel (initramfs will include live-boot hooks)
    log "INFO" "Installing kernel packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        linux-image-amd64 \
        linux-headers-amd64"

    # Install GRUB binaries (not the full packages to avoid conflicts)
    # We need both for hybrid BIOS/UEFI support
    log "INFO" "Installing GRUB binaries..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        grub-pc-bin \
        grub-efi-amd64-bin \
        grub-common \
        grub2-common"

    # Verify initramfs has live-boot hooks
    log "INFO" "Verifying initramfs contents..."
    chroot_exec "lsinitramfs /boot/initrd.img-* | grep -i live || echo 'WARNING: No live-boot hooks found in initramfs'"

    log "INFO" "✓ Kernel installed with live-boot for ISO boot"
}

# Install GNOME desktop (for installed system) + xinit (for installer kiosk)
install_gnome() {
    log "INFO" "=========================================="
    log "INFO" "Installing GNOME Desktop Environment"
    log "INFO" "=========================================="

    # Install GNOME core (minimal installation)
    log "INFO" "Installing GNOME core packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-core \
        gnome-shell \
        gnome-session \
        gnome-terminal \
        gnome-control-center \
        nautilus \
        gdm3 \
        wmctrl \
        gnome-shell-extension-desktop-icons-ng"

    # Install xinit/startx for locked-down installer session
    # (GDM is disabled on the live ISO - we use bare X + Calamares)
    log "INFO" "Installing X11 packages for installer session..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xinit \
        x11-xserver-utils \
        x11-utils \
        xserver-xorg-video-fbdev \
        xserver-xorg-video-vesa"

    log "INFO" "Skipping guest agents (installer-only mode)"

    # Enable GDM3 (will be disabled by lockdown below, re-enabled by post-install cleanup)
    chroot_exec "systemctl enable gdm3"

    log "INFO" "✓ GNOME + X11 installed"
}

# Configure GNOME settings (minimal)
configure_gnome_settings() {
    log "INFO" "=========================================="
    log "INFO" "Configuring GNOME Settings (Minimal)"
    log "INFO" "=========================================="

    # Create dconf profile directory
    mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
    mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d"

    # Create user profile
    cat > "${CHROOT_DIR}/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF

    # Configure GNOME settings (minimal)
    cat > "${CHROOT_DIR}/etc/dconf/db/local.d/00-nubiferos-settings" << 'EOF'
# NubiferOS GNOME Settings (Installer-Only)

[org/gnome/desktop/interface]
# Enable dark theme
gtk-theme='Adwaita-dark'
color-scheme='prefer-dark'

[org/gnome/desktop/screensaver]
# Auto-lock after 5 minutes
lock-enabled=true
lock-delay=uint32 300

[org/gnome/desktop/session]
# Idle delay (5 minutes)
idle-delay=uint32 300

[org/gnome/desktop/privacy]
# Privacy settings
remember-recent-files=false
remove-old-temp-files=true
remove-old-trash-files=true
EOF

    # Update dconf database
    chroot_exec "dconf update"

    log "INFO" "✓ GNOME settings configured (minimal)"
}

# Install fonts (minimal set)
install_fonts() {
    log "INFO" "=========================================="
    log "INFO" "Installing Essential Fonts Only"
    log "INFO" "=========================================="

    # Install only essential fonts (saves space)
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fonts-dejavu-core \
        fonts-liberation2 \
        fonts-noto-core"

    log "INFO" "✓ Essential fonts installed"
}

# Cleanup unnecessary locales (deterministic method)
cleanup_locales() {
    log "INFO" "=========================================="
    log "INFO" "Cleaning Up Unnecessary Locales (CI-Safe)"
    log "INFO" "=========================================="

    log "INFO" "Keeping only English locales (saves space)"

    # Use deterministic file removal instead of localepurge
    # This is more reliable in CI environments
    chroot_exec "find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    chroot_exec "find /usr/share/man -mindepth 1 -maxdepth 1 ! -name 'man[1-9]' ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    chroot_exec "find /usr/share/doc -name '*.txt' -o -name '*.html' | grep -v '/en/' | head -1000 | xargs rm -f 2>/dev/null || true"

    log "INFO" "✓ Unnecessary locales removed (CI-safe method)"
}

# Create installer user with restricted sudo
create_installer_user() {
    log "INFO" "=========================================="
    log "INFO" "Creating Installer User"
    log "INFO" "=========================================="

    # Create installer user (temporary, for running Calamares)
    log "INFO" "Creating installer user..."
    chroot_exec "useradd -m -s /bin/bash -c 'Installer User' installer"
    chroot_exec "echo 'installer:installer' | chpasswd"

    # Add to necessary groups
    chroot_exec "usermod -aG audio,video,plugdev,netdev installer"

    # Restricted sudo - ONLY calamares and reboot (no full sudo)
    cat > "${CHROOT_DIR}/etc/sudoers.d/installer-kiosk" << 'EOF'
# Installer user can ONLY run these specific commands without password
installer ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot
installer ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot --force
installer ALL=(ALL) NOPASSWD: /usr/sbin/reboot
installer ALL=(ALL) NOPASSWD: /usr/bin/calamares
EOF
    chmod 0440 "${CHROOT_DIR}/etc/sudoers.d/installer-kiosk"

    log "INFO" "✓ Installer user created (restricted sudo: calamares + reboot only)"
}

# ==========================================
# Installer Lockdown
# These settings apply to the LIVE ISO only.
# Post-install cleanup reverses them for the installed system.
# ==========================================

# Configure getty auto-login on tty1 (no GDM on live ISO)
configure_getty_autologin() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Getty Auto-Login"
    log "INFO" "=========================================="

    mkdir -p "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d"
    cat > "${CHROOT_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin installer --noclear %I $TERM
Type=idle
EOF

    log "INFO" "✓ Getty auto-login configured for tty1"
}

# Disable GDM and set multi-user target (bare X, no desktop on live ISO)
configure_systemd_target() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Systemd Default Target"
    log "INFO" "=========================================="

    chroot_exec "systemctl set-default multi-user.target"
    chroot_exec "systemctl disable gdm3.service 2>/dev/null || true"
    chroot_exec "systemctl disable lightdm.service 2>/dev/null || true"
    chroot_exec "systemctl disable sddm.service 2>/dev/null || true"

    log "INFO" "✓ Default target set to multi-user.target (no GDM on live ISO)"
}

# Mask getty tty2-6 and ctrl-alt-del (prevent escape)
mask_getty_services() {
    log "INFO" "=========================================="
    log "INFO" "Masking Getty Services (tty2-6)"
    log "INFO" "=========================================="

    for tty in tty2 tty3 tty4 tty5 tty6; do
        chroot_exec "systemctl mask getty@${tty}.service"
    done

    chroot_exec "systemctl mask ctrl-alt-del.target"

    log "INFO" "✓ Getty services masked for tty2-6, ctrl-alt-del masked"
}

# Disable VT switching and Zap via X11 config
configure_xorg_lockdown() {
    log "INFO" "=========================================="
    log "INFO" "Configuring X Server VT Lockdown"
    log "INFO" "=========================================="

    mkdir -p "${CHROOT_DIR}/etc/X11/xorg.conf.d"
    cat > "${CHROOT_DIR}/etc/X11/xorg.conf.d/10-no-vt-switch.conf" << 'EOF'
# Disable virtual terminal switching for installer mode
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZap" "true"
EndSection
EOF

    log "INFO" "✓ X server VT lockdown configured"
}

# Disable SysRq key
configure_sysctl_lockdown() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Sysctl Lockdown"
    log "INFO" "=========================================="

    mkdir -p "${CHROOT_DIR}/etc/sysctl.d"
    cat > "${CHROOT_DIR}/etc/sysctl.d/99-kiosk-lockdown.conf" << 'EOF'
# Disable SysRq key for installer security
kernel.sysrq = 0
EOF

    log "INFO" "✓ SysRq disabled via sysctl"
}

# Create .bash_profile that auto-starts X with Calamares
create_installer_session_files() {
    log "INFO" "=========================================="
    log "INFO" "Creating Installer Session Files"
    log "INFO" "=========================================="

    # .bash_profile - auto-starts X on tty1 login
    cat > "${CHROOT_DIR}/home/installer/.bash_profile" << 'EOF'
#!/bin/bash
# NubiferOS Installer - Auto-start X session
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    echo "Starting NubiferOS Installer..."
    if ! startx -- -keeptty > /tmp/startx.log 2>&1; then
        echo ""
        echo "=========================================="
        echo "ERROR: X session failed to start"
        echo "=========================================="
        echo "Check /tmp/startx.log for details"
        # No auto-reboot here: GDM is the primary session path and this
        # console fallback must never take the machine down with it
    fi
fi
EOF
    chroot_exec "chown installer:installer /home/installer/.bash_profile"
    chmod 644 "${CHROOT_DIR}/home/installer/.bash_profile"

    # .xinitrc - launches ONLY Calamares in bare X
    cat > "${CHROOT_DIR}/home/installer/.xinitrc" << 'EOF'
#!/bin/bash
# NubiferOS Installer - Minimal X Session (Calamares only)
xset s off
xset s noblank
xset -dpms
setxkbmap -option srvrkeys:none 2>/dev/null || true
xsetroot -solid "#2e3440"

echo "$(date): Starting Calamares installer" >> /tmp/kiosk-session.log
sudo calamares -d
echo "$(date): Calamares exited with code $?" >> /tmp/kiosk-session.log

echo "Installation complete or cancelled. Rebooting..."
sleep 2
sudo systemctl reboot --force
EOF
    chroot_exec "chown installer:installer /home/installer/.xinitrc"
    chmod 755 "${CHROOT_DIR}/home/installer/.xinitrc"

    # No .bash_logout reboot trap: a forced reboot on any console logout
    # took down live sessions whenever a stray login shell exited

    log "INFO" "✓ Installer session files created (.bash_profile, .xinitrc)"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Desktop Installation (Installer-Only + Lockdown)"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "=========================================="

    # Install packages
    install_kernel
    install_gnome
    configure_gnome_settings
    install_fonts
    create_installer_user
    cleanup_locales

    # Lock down for installer-only ISO
    configure_getty_autologin
    configure_systemd_target
    mask_getty_services
    configure_xorg_lockdown
    configure_sysctl_lockdown
    create_installer_session_files

    log "INFO" "=========================================="
    log "INFO" "Desktop installation + lockdown complete!"
    log "INFO" "=========================================="
    log "INFO" "Installed: GNOME, GDM, kernel, X11"
    log "INFO" "Lockdown: No GDM, getty autologin, VT masked, bare X + Calamares"
    log "INFO" "Boot flow: getty → .bash_profile → startx → .xinitrc → Calamares → reboot"
    log "INFO" "=========================================="
}

main "$@"
