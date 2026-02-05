#!/bin/bash
# Install packages for kiosk mode installer
# Part of NubiferOS build system - Kiosk Mode Implementation
#
# This script installs the FULL system that will be copied to the installed system,
# but the LIVE session runs in kiosk mode (minimal X + Calamares only).
#
# The installed system gets:
# - GNOME desktop environment
# - Cloud tools and development packages
# - Security hardening tools
#
# The live ISO session gets:
# - Minimal X11 (xorg, xinit, video drivers)
# - Calamares installer
# - NO desktop environment access (kiosk mode)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "=========================================="
log "INFO" "Installing Kiosk Mode Packages"
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
    log "INFO" "Installing Linux Kernel"
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

# Install GNOME desktop (for installed system)
install_gnome_desktop() {
    log "INFO" "=========================================="
    log "INFO" "Installing GNOME Desktop (for installed system)"
    log "INFO" "=========================================="
    
    # Install GNOME core
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
        gnome-tweaks \
        gnome-shell-extensions \
        dconf-editor \
        gnome-shell-extension-desktop-icons-ng"
    
    # Install Firefox
    log "INFO" "Installing Firefox..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr"
    
    log "INFO" "✓ GNOME desktop installed (for installed system)"
}

# Install minimal X11 packages for kiosk live session
install_minimal_x11() {
    log "INFO" "=========================================="
    log "INFO" "Installing X11 (includes kiosk session support)"
    log "INFO" "=========================================="
    
    # Install X11 packages (needed for both kiosk and installed system)
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
    
    # Install fonts (required for Calamares UI and installed system)
    log "INFO" "Installing fonts..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fonts-dejavu-core \
        fonts-liberation2 \
        fonts-noto-core"
    
    log "INFO" "✓ X11 installed"
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
    log "INFO" "Installing System Utilities"
    log "INFO" "=========================================="
    
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo \
        dbus \
        dbus-x11 \
        policykit-1 \
        network-manager \
        wpasupplicant \
        iproute2 \
        kbd \
        vim \
        curl \
        wget \
        git \
        htop \
        tmux \
        net-tools \
        jq \
        unzip \
        ca-certificates"
    
    log "INFO" "✓ System utilities installed"
}

# Install development tools (for installed system)
install_development_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing Development Tools"
    log "INFO" "=========================================="
    
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        nodejs \
        npm \
        build-essential \
        gcc \
        g++ \
        make"
    
    log "INFO" "✓ Development tools installed"
}

# Install security tools (for installed system)
install_security_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing Security Tools"
    log "INFO" "=========================================="
    
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        firejail \
        apparmor \
        apparmor-utils \
        fail2ban \
        ufw \
        aide \
        rkhunter \
        lynis \
        pass \
        gnupg"
    
    log "INFO" "✓ Security tools installed"
}

# Cleanup unnecessary packages and locales
cleanup_packages() {
    log "INFO" "=========================================="
    log "INFO" "Cleaning Up"
    log "INFO" "=========================================="
    
    # Clean up
    chroot_exec "apt-get autoremove -y"
    chroot_exec "apt-get clean"
    
    # Remove unnecessary locales (saves space)
    log "INFO" "Removing unnecessary locales..."
    chroot_exec "find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    chroot_exec "find /usr/share/man -mindepth 1 -maxdepth 1 ! -name 'man[1-9]' ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true"
    
    log "INFO" "✓ Cleanup complete"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Kiosk Mode Package Installation"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "Live session: Kiosk mode (minimal X + Calamares)"
    log "INFO" "Installed system: Full GNOME desktop"
    log "INFO" "=========================================="
    
    install_kernel
    install_gnome_desktop
    install_minimal_x11
    install_calamares
    install_system_utilities
    install_development_tools
    install_security_tools
    cleanup_packages
    
    log "INFO" "=========================================="
    log "INFO" "Package installation complete!"
    log "INFO" "=========================================="
    log "INFO" "Installed: GNOME, X11, Calamares, dev tools, security tools"
    log "INFO" "Live session will run in kiosk mode (configure-kiosk-session.sh)"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run configure-kiosk-session.sh"
}

main "$@"
