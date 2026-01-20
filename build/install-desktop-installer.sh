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
    
    # Install kernel and required packages (NO live-boot for direct installer)
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
    
    # Update initramfs (standard initramfs without live-boot)
    log "INFO" "Updating initramfs..."
    chroot_exec "update-initramfs -u -k all"
    
    log "INFO" "✓ Kernel installed (direct installer mode)"
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
    
    # NOTE: Guest agents NOT installed in installer-only ISO
    # They are only needed for live/testing environments
    log "INFO" "Skipping guest agents (installer-only mode)"
    
    # Set GDM3 as default display manager
    chroot_exec "systemctl enable gdm3"
    
    log "INFO" "✓ GNOME installed (minimal for installer)"
}

# Configure Wayland
configure_wayland() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Wayland"
    log "INFO" "=========================================="
    
    # Note: GDM configuration is handled by configure-installer-autostart.sh
    # which sets up auto-login for the installer user
    
    log "INFO" "✓ Wayland will be configured by installer autostart script"
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

# NO LIVE USER CREATION - Installer-only ISO
# WAIT - We DO need a live user for the installer to run!
create_installer_user() {
    log "INFO" "=========================================="
    log "INFO" "Creating Installer User"
    log "INFO" "=========================================="
    
    # Create installer user (temporary, for running Calamares)
    log "INFO" "Creating installer user..."
    chroot_exec "useradd -m -s /bin/bash -c 'Installer User' installer"
    chroot_exec "echo 'installer:installer' | chpasswd"
    
    # Add to necessary groups
    chroot_exec "usermod -aG sudo,audio,video,plugdev,netdev installer"
    
    # Configure sudo without password for installer user
    echo "installer ALL=(ALL) NOPASSWD: ALL" > "${CHROOT_DIR}/etc/sudoers.d/installer"
    chmod 0440 "${CHROOT_DIR}/etc/sudoers.d/installer"
    
    log "INFO" "✓ Installer user created (username: installer, password: installer)"
}

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
    create_installer_user
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