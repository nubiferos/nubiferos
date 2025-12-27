#!/bin/bash
# Install and configure GNOME desktop environment for LIVE ISO
# Part of NubiferOS build system - Development/Testing builds ONLY

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "WARN" "=========================================="
log "WARN" "⚠️  BUILDING LIVE ISO - TESTING ONLY"
log "WARN" "⚠️  NOT FOR PRODUCTION USE"
log "WARN" "=========================================="

log "INFO" "Starting GNOME desktop installation (LIVE)"

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

# Install Linux kernel WITH LIVE BOOT
install_kernel() {
    log "INFO" "=========================================="
    log "INFO" "Installing Linux Kernel (Live Boot)"
    log "INFO" "=========================================="
    
    # Install kernel and required packages INCLUDING live-boot
    log "INFO" "Installing kernel packages with live-boot..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        linux-image-amd64 \
        linux-headers-amd64 \
        initramfs-tools \
        live-boot \
        live-boot-initramfs-tools"
    
    # Install GRUB binaries (not the full packages to avoid conflicts)
    # We need both for hybrid BIOS/UEFI support
    log "INFO" "Installing GRUB binaries..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        grub-pc-bin \
        grub-efi-amd64-bin \
        grub-common \
        grub2-common"
    
    # Update initramfs to include live-boot
    log "INFO" "Updating initramfs with live-boot support..."
    chroot_exec "update-initramfs -u -k all"
    
    log "INFO" "✓ Kernel and live-boot installed"
}

# Install GNOME desktop (full for live environment)
install_gnome() {
    log "INFO" "=========================================="
    log "INFO" "Installing GNOME Desktop Environment (Full)"
    log "INFO" "=========================================="
    
    # Install GNOME core (full installation for live environment)
    log "INFO" "Installing GNOME core packages..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-core \
        gnome-shell \
        gnome-session \
        gnome-terminal \
        gnome-control-center \
        gnome-tweaks \
        nautilus \
        gdm3"
    
    # Install additional useful GNOME apps for live environment
    log "INFO" "Installing GNOME applications..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-system-monitor \
        gnome-calculator \
        gnome-screenshot \
        gedit \
        file-roller"
    
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
    
    log "INFO" "✓ GNOME installed (full for live environment)"
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

[security]

[xdmcp]

[chooser]

[debug]
EOF
    
    log "INFO" "✓ Wayland configured"
}

# Configure GNOME settings (full)
configure_gnome_settings() {
    log "INFO" "=========================================="
    log "INFO" "Configuring GNOME Settings (Full)"
    log "INFO" "=========================================="
    
    # Create dconf profile directory
    mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
    mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d"
    
    # Create user profile
    cat > "${CHROOT_DIR}/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF
    
    # Configure GNOME settings (full for live environment)
    cat > "${CHROOT_DIR}/etc/dconf/db/local.d/00-nubiferos-settings" << 'EOF'
# NubiferOS GNOME Settings (Live Environment)

[org/gnome/desktop/interface]
# Enable dark theme
gtk-theme='Adwaita-dark'
color-scheme='prefer-dark'

[org/gnome/desktop/wm/preferences]
# Configure 4 workspaces
num-workspaces=4

[org/gnome/desktop/wm/keybindings]
# Workspace switching shortcuts
switch-to-workspace-1=['<Super>1']
switch-to-workspace-2=['<Super>2']
switch-to-workspace-3=['<Super>3']
switch-to-workspace-4=['<Super>4']

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

[org/gnome/shell]
# Favorite apps in dash
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox-esr.desktop', 'org.gnome.gedit.desktop']

[org/gnome/desktop/background]
# Will be set by branding
picture-uri='file:///usr/share/backgrounds/nubiferos/default.png'
picture-uri-dark='file:///usr/share/backgrounds/nubiferos/default-dark.png'
EOF
    
    # Update dconf database
    chroot_exec "dconf update"
    
    log "INFO" "✓ GNOME settings configured (full)"
}

# Install and configure GNOME Keyring
configure_gnome_keyring() {
    log "INFO" "=========================================="
    log "INFO" "Configuring GNOME Keyring"
    log "INFO" "=========================================="
    
    # Install GNOME Keyring (should already be installed with gnome-core)
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-keyring \
        libsecret-1-0 \
        libsecret-tools"
    
    # Enable GNOME Keyring daemon
    chroot_exec "systemctl --user enable gnome-keyring-daemon"
    
    log "INFO" "✓ GNOME Keyring configured"
}

# Create wallpapers
create_wallpapers() {
    log "INFO" "=========================================="
    log "INFO" "Creating NubiferOS Wallpapers"
    log "INFO" "=========================================="
    
    # Create wallpaper directory
    mkdir -p "${CHROOT_DIR}/usr/share/backgrounds/nubiferos"
    
    # Create a simple SVG wallpaper with TESTING warning
    cat > "${CHROOT_DIR}/usr/share/backgrounds/nubiferos/default.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#8b0000;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#4b0000;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#grad1)"/>
  <text x="960" y="400" font-family="Arial, sans-serif" font-size="72" fill="#ffffff" text-anchor="middle" opacity="0.8">
    NubiferOS
  </text>
  <text x="960" y="480" font-family="Arial, sans-serif" font-size="48" fill="#ffff00" text-anchor="middle" opacity="0.9">
    TESTING ONLY
  </text>
  <text x="960" y="540" font-family="Arial, sans-serif" font-size="32" fill="#ffff00" text-anchor="middle" opacity="0.7">
    NOT FOR PRODUCTION
  </text>
  <text x="960" y="600" font-family="Arial, sans-serif" font-size="24" fill="#ffffff" text-anchor="middle" opacity="0.5">
    Development/Testing Live Environment
  </text>
</svg>
EOF
    
    # Convert SVG to PNG (if imagemagick is available in chroot)
    if chroot_exec "command -v convert" &>/dev/null; then
        chroot_exec "convert /usr/share/backgrounds/nubiferos/default.svg /usr/share/backgrounds/nubiferos/default.png"
        chroot_exec "cp /usr/share/backgrounds/nubiferos/default.png /usr/share/backgrounds/nubiferos/default-dark.png"
    else
        log "WARN" "ImageMagick not available, using SVG wallpaper"
        chroot_exec "ln -sf /usr/share/backgrounds/nubiferos/default.svg /usr/share/backgrounds/nubiferos/default.png"
        chroot_exec "ln -sf /usr/share/backgrounds/nubiferos/default.svg /usr/share/backgrounds/nubiferos/default-dark.png"
    fi
    
    log "INFO" "✓ Wallpapers created (with testing warning)"
}

# Set default applications
set_default_applications() {
    log "INFO" "=========================================="
    log "INFO" "Setting Default Applications"
    log "INFO" "=========================================="
    
    # Create mimeapps.list for default applications
    mkdir -p "${CHROOT_DIR}/etc/xdg"
    
    cat > "${CHROOT_DIR}/etc/xdg/mimeapps.list" << 'EOF'
[Default Applications]
text/html=firefox-esr.desktop
x-scheme-handler/http=firefox-esr.desktop
x-scheme-handler/https=firefox-esr.desktop
x-scheme-handler/about=firefox-esr.desktop
x-scheme-handler/unknown=firefox-esr.desktop
text/plain=org.gnome.gedit.desktop
inode/directory=org.gnome.Nautilus.desktop
EOF
    
    log "INFO" "✓ Default applications set"
}

# Install fonts (full set for live environment)
install_fonts() {
    log "INFO" "=========================================="
    log "INFO" "Installing Fonts (Full Set)"
    log "INFO" "=========================================="
    
    # Install full font set for live environment
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fonts-dejavu-core \
        fonts-liberation2 \
        fonts-noto-core \
        fonts-noto-color-emoji"
    
    log "INFO" "✓ Fonts installed (full set)"
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

# Create live user for testing (LIVE ISO ONLY!)
create_live_user() {
    log "INFO" "=========================================="
    log "INFO" "Creating Live User (TESTING ONLY)"
    log "INFO" "=========================================="
    
    log "WARN" "⚠️  Creating live user - TESTING ONLY!"
    
    # Create live user
    chroot_exec "useradd -m -s /bin/bash -c 'Live User (Testing)' live"
    chroot_exec "echo 'live:live' | chpasswd"
    
    # Add to sudo group
    chroot_exec "usermod -aG sudo live"
    
    # Configure passwordless sudo for live user (TESTING ONLY)
    cat > "${CHROOT_DIR}/etc/sudoers.d/live-user" << 'EOF'
# Allow live user to run sudo without password (TESTING ONLY)
# This file is only present in development/testing live ISOs
live ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 "${CHROOT_DIR}/etc/sudoers.d/live-user"
    
    # Configure auto-login for GDM
    mkdir -p "${CHROOT_DIR}/etc/gdm3"
    cat > "${CHROOT_DIR}/etc/gdm3/custom.conf" << 'EOF'
# GDM configuration storage

[daemon]
# Enable Wayland
WaylandEnable=true

# Auto-login for live user (TESTING ONLY)
AutomaticLoginEnable=true
AutomaticLogin=live

[security]

[xdmcp]

[chooser]

[debug]
EOF
    
    log "INFO" "✓ Live user created"
    log "INFO" "  Username: live"
    log "INFO" "  Password: live"
    log "WARN" "⚠️  AUTO-LOGIN ENABLED - TESTING ONLY!"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "GNOME Desktop Installation (Live)"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "Type: Development/testing live ISO"
    log "WARN" "⚠️  WARNING: NOT FOR PRODUCTION USE"
    log "INFO" "=========================================="
    
    install_kernel
    install_gnome
    configure_wayland
    configure_gnome_settings
    configure_gnome_keyring
    create_wallpapers
    set_default_applications
    install_fonts
    cleanup_locales
    create_live_user
    
    log "INFO" "=========================================="
    log "INFO" "GNOME desktop installation complete (live)!"
    log "INFO" "=========================================="
    log "INFO" "Desktop: GNOME with Wayland"
    log "INFO" "Workspaces: 4 configured"
    log "INFO" "Keyring: GNOME Keyring enabled"
    log "INFO" "Theme: Adwaita Dark"
    log "INFO" "Live User: live/live with auto-login"
    log "WARN" "⚠️  WARNING: TESTING ONLY - NOT FOR PRODUCTION"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run ./build/build-iso.sh --live"
}

main "$@"