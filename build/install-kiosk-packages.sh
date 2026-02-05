#!/bin/bash
# Install minimal packages for kiosk mode installer
# Part of NubiferOS build system - Kiosk Mode Implementation
#
# This script replaces install-desktop-installer.sh for kiosk mode builds.
# It installs ONLY the minimal packages needed to run Calamares:
# - Minimal X11 (xorg, xinit, video drivers)
# - Calamares installer
# - NO desktop environment (no GNOME, no GDM)
# - NO terminal emulators
# - NO file managers
# - NO web browsers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "=========================================="
log "INFO" "Installing Kiosk Mode Packages (Minimal)"
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

# Install Linux kernel with live-boot support
install_kernel() {
    log "INFO" "=========================================="
    log "INFO" "Installing Linux Kernel (Kiosk Mode)"
    log "INFO" "=========================================="
    
    # Install live-boot packages FIRST (before kernel generates initramfs)
    log "INFO" "Installing live-boot packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        initramfs-tools \
        live-boot \
        live-boot-initramfs-tools"
    
    # Install kernel packages
    log "INFO" "Installing kernel packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        linux-image-amd64 \
        linux-headers-amd64"
    
    # Install GRUB binaries for hybrid BIOS/UEFI support
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

# Install minimal X11 packages (NO desktop environment)
install_minimal_x11() {
    log "INFO" "=========================================="
    log "INFO" "Installing Minimal X11 (NO Desktop Environment)"
    log "INFO" "=========================================="
    
    # Install ONLY essential X11 packages
    log "INFO" "Installing X11 core packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xserver-xorg-core \
        xserver-xorg-input-libinput \
        xserver-xorg-video-fbdev \
        xserver-xorg-video-vesa \
        xserver-xorg-video-intel \
        xserver-xorg-video-amdgpu \
        xserver-xorg-video-nouveau \
        xinit \
        x11-xserver-utils \
        x11-utils"
    
    # Install fonts (required for Calamares UI)
    log "INFO" "Installing essential fonts..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fonts-dejavu-core \
        fonts-liberation2 \
        fonts-noto-core"
    
    # NOTE: We do NOT install:
    # - gnome-core, gnome-shell, gnome-session (desktop environment)
    # - gdm3, lightdm (display managers)
    # - gnome-terminal, xterm (terminal emulators)
    # - nautilus, thunar (file managers)
    # - firefox-esr, chromium (web browsers)
    # - gedit, nano (text editors beyond what Calamares needs)
    
    log "INFO" "✓ Minimal X11 installed (NO desktop environment)"
}

# Install Calamares and its dependencies
install_calamares() {
    log "INFO" "=========================================="
    log "INFO" "Installing Calamares Installer"
    log "INFO" "=========================================="
    
    # Install Calamares and required Qt/KDE dependencies
    log "INFO" "Installing Calamares packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        calamares \
        calamares-settings-debian"
    
    # Install additional dependencies Calamares needs
    log "INFO" "Installing Calamares dependencies..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        os-prober \
        parted \
        dosfstools \
        e2fsprogs \
        btrfs-progs \
        xfsprogs \
        cryptsetup \
        cryptsetup-initramfs \
        lvm2 \
        squashfs-tools \
        rsync"
    
    log "INFO" "✓ Calamares installer installed"
}

# Install essential system utilities
install_system_utilities() {
    log "INFO" "=========================================="
    log "INFO" "Installing Essential System Utilities"
    log "INFO" "=========================================="
    
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo \
        dbus \
        dbus-x11 \
        policykit-1 \
        network-manager \
        wpasupplicant \
        iproute2 \
        kbd"
    
    log "INFO" "✓ System utilities installed"
}

# Cleanup unnecessary packages and locales
cleanup_packages() {
    log "INFO" "=========================================="
    log "INFO" "Cleaning Up Unnecessary Packages"
    log "INFO" "=========================================="
    
    # Remove any accidentally installed desktop packages
    log "INFO" "Ensuring no desktop packages are installed..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get purge -y \
        gnome-core gnome-shell gnome-session gdm3 \
        gnome-terminal xterm \
        nautilus thunar \
        firefox-esr chromium \
        gedit 2>/dev/null || true"
    
    # Clean up
    chroot_exec "apt-get autoremove -y"
    chroot_exec "apt-get clean"
    
    # Remove unnecessary locales (saves space)
    log "INFO" "Removing unnecessary locales..."
    chroot_exec "find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    chroot_exec "find /usr/share/man -mindepth 1 -maxdepth 1 ! -name 'man[1-9]' ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    
    log "INFO" "✓ Cleanup complete"
}

# Verify no forbidden packages are installed
verify_package_exclusions() {
    log "INFO" "=========================================="
    log "INFO" "Verifying Package Exclusions"
    log "INFO" "=========================================="
    
    local forbidden_packages=(
        "gnome-shell"
        "gnome-session"
        "gdm3"
        "lightdm"
        "gnome-terminal"
        "xterm"
        "nautilus"
        "thunar"
        "firefox-esr"
        "chromium"
    )
    
    local found_forbidden=false
    
    for pkg in "${forbidden_packages[@]}"; do
        if chroot_exec "dpkg -l | grep -q '^ii  ${pkg} '"; then
            log "ERROR" "Forbidden package installed: ${pkg}"
            found_forbidden=true
        fi
    done
    
    if [ "$found_forbidden" = true ]; then
        log "ERROR" "Kiosk mode requires these packages to NOT be installed!"
        exit 1
    fi
    
    log "INFO" "✓ No forbidden packages found"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Kiosk Mode Package Installation"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "Type: Minimal kiosk installer ISO"
    log "INFO" "Security: Maximum lockdown, minimal attack surface"
    log "INFO" "=========================================="
    
    install_kernel
    install_minimal_x11
    install_calamares
    install_system_utilities
    cleanup_packages
    verify_package_exclusions
    
    log "INFO" "=========================================="
    log "INFO" "Kiosk mode package installation complete!"
    log "INFO" "=========================================="
    log "INFO" "Installed: Minimal X11, Calamares"
    log "INFO" "NOT installed: GNOME, GDM, terminals, browsers"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run configure-kiosk-session.sh"
}

main "$@"
