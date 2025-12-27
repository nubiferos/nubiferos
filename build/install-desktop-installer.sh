#!/bin/bash
# Install and configure GNOME desktop environment for INSTALLER-ONLY ISO
# Part of NubiferOS build system - Production/Alpha builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "Starting GNOME desktop installation (INSTALLER-ONLY)"

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

# Install Linux kernel (NO LIVE BOOT)
install_kernel() {
    log "INFO" "=========================================="
    log "INFO" "Installing Linux Kernel (Installer-Only)"
    log "INFO" "=========================================="
    
    # Install kernel and required packages (NO live-boot packages)
    log "INFO" "Installing kernel packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        linux-image-amd64 \
        linux-headers-amd64 \
        initramfs-tools"
    
    # Install GRUB binaries (not the full packages to avoid conflicts)
    # We need both for hybrid BIOS/UEFI support
    log "INFO" "Installing GRUB binaries..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        grub-pc-bin \
        grub-efi-amd64-bin \
        grub-common \
        grub2-common"
    
    # Update initramfs (no live-boot support needed)
    log "INFO" "Updating initramfs..."
    chroot_exec "update-initramfs -u -k all"
    
    log "INFO" "✓ Kernel installed (installer-only mode)"
}

# Install GNOME desktop (minimal for installer)
install_gnome() {
    log "INFO" "=========================================="
    log "INFO" "Installing GNOME Desktop Environment (Minimal)"
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
        gdm3"
    
    # Install SPICE guest agent for VM clipboard support
    log "INFO" "Installing SPICE guest agent for VM support..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        spice-vdagent \
        qemu-guest-agent"
    
    # Set GDM3 as default display manager
    chroot_exec "systemctl enable gdm3"
    
    # Enable SPICE and QEMU guest agents
    chroot_exec "systemctl enable spice-vdagent"
    chroot_exec "systemctl enable qemu-guest-agent"
    
    log "INFO" "✓ GNOME installed (minimal for installer)"
}

# Configure Wayland
configure_wayland() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Wayland"
    log "INFO" "=========================================="
    
    # Enable Wayland, disable X11 fallback for security
    cat > "${CHROOT_DIR}/etc/gdm3/custom.conf" << 'EOF'
# GDM configuration storage

[daemon]
# Enable Wayland
WaylandEnable=true
# Disable X11 for security (Wayland only)
# Uncomment to force Wayland only:
# XorgEnable=false

# NO AUTO-LOGIN - Installer-only ISO

[security]

[xdmcp]

[chooser]

[debug]
EOF
    
    log "INFO" "✓ Wayland configured (no auto-login)"
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

# Cleanup unnecessary locales (keep only English)
cleanup_locales() {
    log "INFO" "=========================================="
    log "INFO" "Cleaning Up Unnecessary Locales"
    log "INFO" "=========================================="
    
    log "INFO" "Keeping only English locales (saves space)"
    
    # Install localepurge to remove unnecessary locales
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y localepurge"
    
    # Configure localepurge to keep only English
    cat > "${CHROOT_DIR}/etc/locale.nopurge" << 'EOF'
# Keep only English locales
en
en_US
en_US.UTF-8
MANDELETE
DONTBOTHERNEWLOCALE
SHOWFREEDSPACE
EOF
    
    # Run localepurge
    chroot_exec "localepurge"
    
    # Remove locale files manually for additional space savings
    chroot_exec "find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} +"
    
    log "INFO" "✓ Unnecessary locales removed"
}

# NO LIVE USER CREATION - Installer-only ISO

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "GNOME Desktop Installation (Installer-Only)"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "Type: Production installer-only ISO"
    log "INFO" "Security: Minimal attack surface"
    log "INFO" "=========================================="
    
    install_kernel
    install_gnome
    configure_wayland
    configure_gnome_settings
    install_fonts
    cleanup_locales
    
    log "INFO" "=========================================="
    log "INFO" "GNOME desktop installation complete (installer-only)!"
    log "INFO" "=========================================="
    log "INFO" "Desktop: GNOME with Wayland"
    log "INFO" "Security: No live user, no auto-login"
    log "INFO" "Boot: Direct to installer"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run ./build/build-iso.sh --installer-only"
}

main "$@"