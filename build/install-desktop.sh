#!/bin/bash
# Install and configure GNOME desktop environment
# Part of NubiferOS build system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "Starting GNOME desktop installation"

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
    log "INFO" "Installing Linux Kernel"
    log "INFO" "=========================================="
    
    # Install kernel and required packages
    log "INFO" "Installing kernel packages..."
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

# Install GNOME desktop
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
        gnome-tweaks \
        nautilus \
        gdm3"
    
    # Install additional useful GNOME apps
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
    
    log "INFO" "✓ GNOME installed"
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

# Configure GNOME settings
configure_gnome_settings() {
    log "INFO" "=========================================="
    log "INFO" "Configuring GNOME Settings"
    log "INFO" "=========================================="
    
    # Create dconf profile directory
    mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
    mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d"
    
    # Create user profile
    cat > "${CHROOT_DIR}/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF
    
    # Configure GNOME settings
    cat > "${CHROOT_DIR}/etc/dconf/db/local.d/00-nubiferos-settings" << 'EOF'
# NubiferOS GNOME Settings

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
    
    log "INFO" "✓ GNOME settings configured"
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
    
    # For now, create placeholder wallpapers
    # TODO: Replace with actual branded wallpapers
    
    # Create a simple SVG wallpaper
    cat > "${CHROOT_DIR}/usr/share/backgrounds/nubiferos/default.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1e3a8a;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0c1e47;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#grad1)"/>
  <text x="960" y="540" font-family="Arial, sans-serif" font-size="72" fill="#ffffff" text-anchor="middle" opacity="0.3">
    NubiferOS
  </text>
  <text x="960" y="600" font-family="Arial, sans-serif" font-size="24" fill="#ffffff" text-anchor="middle" opacity="0.2">
    Multi-Cloud, Unified Control
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
    
    log "INFO" "✓ Wallpapers created"
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

# Install fonts (minimal set - language-specific fonts added during setup)
install_fonts() {
    log "INFO" "=========================================="
    log "INFO" "Installing Essential Fonts Only"
    log "INFO" "=========================================="
    
    # Install only essential fonts (saves ~600MB)
    # Language-specific fonts will be installed during first-run setup
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fonts-dejavu-core \
        fonts-liberation2 \
        fonts-noto-core \
        fonts-noto-color-emoji"
    
    log "INFO" "✓ Essential fonts installed"
    log "INFO" "  (Language-specific fonts available via setup wizard)"
}

# Cleanup unnecessary locales (keep only English - saves ~400MB)
cleanup_locales() {
    log "INFO" "=========================================="
    log "INFO" "Cleaning Up Unnecessary Locales"
    log "INFO" "=========================================="
    
    log "INFO" "Keeping only English locales (saves ~400MB)"
    log "INFO" "  (Other languages available via setup wizard)"
    
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

# Create live user for testing (REMOVE BEFORE ALPHA!)
create_live_user() {
    log "INFO" "=========================================="
    log "INFO" "Creating Live User (TESTING ONLY)"
    log "INFO" "=========================================="
    
    log "WARN" "⚠️  Creating live user - REMOVE BEFORE PRODUCTION!"
    
    # Create live user
    chroot_exec "useradd -m -s /bin/bash -c 'Live User' live"
    chroot_exec "echo 'live:live' | chpasswd"
    
    # Add to sudo group
    chroot_exec "usermod -aG sudo live"
    
    # Configure passwordless sudo for live user (TESTING ONLY)
    cat > "${CHROOT_DIR}/etc/sudoers.d/live-user" << 'EOF'
# Allow live user to run sudo without password (TESTING ONLY)
# This file will be removed when live CD is removed before Alpha
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

# Auto-login for live user (TESTING ONLY - REMOVE BEFORE PRODUCTION)
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
    log "INFO" "GNOME Desktop Installation"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
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
    log "INFO" "GNOME desktop installation complete!"
    log "INFO" "=========================================="
    log "INFO" "Desktop: GNOME with Wayland"
    log "INFO" "Workspaces: 4 configured"
    log "INFO" "Keyring: GNOME Keyring enabled"
    log "INFO" "Theme: Adwaita Dark"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run ./build/build-iso.sh"
}

main "$@"
