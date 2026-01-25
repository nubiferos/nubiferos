#!/bin/bash
# Install NubiferOS branding assets (wallpapers, icons, GRUB theme)
# Part of NubiferOS build system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/../brand/load-brand.sh"

init_config

log "INFO" "Installing NubiferOS branding assets..."

# Install wallpapers
log "INFO" "Installing wallpapers..."
mkdir -p "${CHROOT_DIR}/usr/share/backgrounds/nubiferos"

# Copy nubifer_dark wallpapers (the main collection)
if [ -d "${PROJECT_ROOT}/brand/wallpapers/nubifer_dark" ]; then
    cp "${PROJECT_ROOT}/brand/wallpapers/nubifer_dark/"*.png "${CHROOT_DIR}/usr/share/backgrounds/nubiferos/"
    log "INFO" "  ✓ NubiferOS dark wallpapers (10 variants)"
fi

# Copy SVG wallpapers (provider-themed)
for wallpaper in default aws azure gcp oracle; do
    if [ -f "${PROJECT_ROOT}/brand/wallpapers/${wallpaper}.svg" ]; then
        cp "${PROJECT_ROOT}/brand/wallpapers/${wallpaper}.svg" "${CHROOT_DIR}/usr/share/backgrounds/nubiferos/"
        log "INFO" "  ✓ ${wallpaper}.svg"
    fi
done

# Copy PNG wallpapers if they exist (pre-generated from SVGs)
if [ -d "${PROJECT_ROOT}/brand/wallpapers/png" ]; then
    cp "${PROJECT_ROOT}/brand/wallpapers/png/"*.png "${CHROOT_DIR}/usr/share/backgrounds/nubiferos/" 2>/dev/null || true
    log "INFO" "  ✓ PNG wallpapers"
fi

# Install icons
log "INFO" "Installing icons..."
mkdir -p "${CHROOT_DIR}/usr/share/pixmaps/nubiferos"
mkdir -p "${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps"

# Copy logo icons
for size in 32 64 128 256 512; do
    if [ -f "${PROJECT_ROOT}/brand/icons/logo-${size}.png" ]; then
        cp "${PROJECT_ROOT}/brand/icons/logo-${size}.png" "${CHROOT_DIR}/usr/share/pixmaps/nubiferos/"
        
        # Also install to hicolor theme
        mkdir -p "${CHROOT_DIR}/usr/share/icons/hicolor/${size}x${size}/apps"
        cp "${PROJECT_ROOT}/brand/icons/logo-${size}.png" "${CHROOT_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/nubiferos.png"
    fi
done

# Copy SVG logo
if [ -f "${PROJECT_ROOT}/brand/logo.svg" ]; then
    cp "${PROJECT_ROOT}/brand/logo.svg" "${CHROOT_DIR}/usr/share/pixmaps/nubiferos/"
    cp "${PROJECT_ROOT}/brand/logo.svg" "${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps/nubiferos.svg"
fi

# Update icon cache
chroot_exec "gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true"

# Set default wallpaper for GNOME (cyan_black as default)
log "INFO" "Configuring default wallpaper..."
mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d"
cat > "${CHROOT_DIR}/etc/dconf/db/local.d/01-nubiferos-wallpaper" << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-uri-dark='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-options='zoom'
primary-color='#000000'
secondary-color='#00ffff'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
primary-color='#000000'
secondary-color='#00ffff'
EOF

# Create dconf profile if it doesn't exist
mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
if [ ! -f "${CHROOT_DIR}/etc/dconf/profile/user" ]; then
    cat > "${CHROOT_DIR}/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF
fi

# Update dconf database
chroot_exec "dconf update 2>/dev/null || true"

# Create GNOME background XML for wallpaper selection
log "INFO" "Creating wallpaper selection entries..."
mkdir -p "${CHROOT_DIR}/usr/share/gnome-background-properties"
cat > "${CHROOT_DIR}/usr/share/gnome-background-properties/nubiferos.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <!-- NubiferOS Dark Collection -->
  <wallpaper deleted="false">
    <name>NubiferOS Cyan (Default)</name>
    <filename>/usr/share/backgrounds/nubiferos/cyan_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#00ffff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Green</name>
    <filename>/usr/share/backgrounds/nubiferos/green_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#00ff00</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Lime</name>
    <filename>/usr/share/backgrounds/nubiferos/lime_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#32cd32</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Magenta</name>
    <filename>/usr/share/backgrounds/nubiferos/magenta_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ff00ff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Orange</name>
    <filename>/usr/share/backgrounds/nubiferos/orange_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ff9900</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Pink</name>
    <filename>/usr/share/backgrounds/nubiferos/pink_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ff69b4</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Purple</name>
    <filename>/usr/share/backgrounds/nubiferos/purple_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#9932cc</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Red</name>
    <filename>/usr/share/backgrounds/nubiferos/red_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ff0000</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS White</name>
    <filename>/usr/share/backgrounds/nubiferos/white_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ffffff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Yellow</name>
    <filename>/usr/share/backgrounds/nubiferos/yellow_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#ffff00</scolor>
  </wallpaper>
  <!-- Provider-themed wallpapers -->
  <wallpaper deleted="false">
    <name>NubiferOS AWS Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/aws.svg</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#232f3e</pcolor>
    <scolor>#ff9900</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Azure Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/azure.svg</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#0078d4</pcolor>
    <scolor>#002050</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS GCP Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/gcp.svg</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#4285f4</pcolor>
    <scolor>#1a1a2e</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Oracle Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/oracle.svg</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#c74634</pcolor>
    <scolor>#1a1a2e</scolor>
  </wallpaper>
</wallpapers>
EOF

log "INFO" "✓ Branding assets installed"
log "INFO" "  - Wallpapers: /usr/share/backgrounds/nubiferos/"
log "INFO" "  - Icons: /usr/share/pixmaps/nubiferos/"
log "INFO" "  - Default wallpaper configured"

# Configure GDM (login screen) branding
log "INFO" "Configuring GDM login screen branding..."

# Create GDM dconf profile
mkdir -p "${CHROOT_DIR}/etc/dconf/profile"
cat > "${CHROOT_DIR}/etc/dconf/profile/gdm" << 'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

# Create GDM dconf database directory
mkdir -p "${CHROOT_DIR}/etc/dconf/db/gdm.d"

# Configure GDM settings - logo and background
cat > "${CHROOT_DIR}/etc/dconf/db/gdm.d/01-nubiferos-branding" << 'EOF'
[org/gnome/login-screen]
logo='/usr/share/pixmaps/nubiferos/logo-128.png'
banner-message-enable=false

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-options='zoom'
primary-color='#000000'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
EOF

# Update dconf databases
chroot_exec "dconf update 2>/dev/null || true"

# Replace Debian logo in GDM with NubiferOS logo
# The logo shown at bottom of login screen comes from desktop-base package
if [ -f "${PROJECT_ROOT}/brand/icons/logo-64.png" ]; then
    # Replace the Debian logo files that GDM uses
    # active-theme is often a symlink - only create if it's a real directory
    ACTIVE_THEME="${CHROOT_DIR}/usr/share/desktop-base/active-theme"
    if [ -d "$ACTIVE_THEME" ] && [ ! -L "$ACTIVE_THEME" ]; then
        mkdir -p "${ACTIVE_THEME}/login"
        cp "${PROJECT_ROOT}/brand/icons/logo-64.png" "${ACTIVE_THEME}/login/logo.png"
        log "INFO" "  ✓ Replaced active-theme logo"
    fi
    
    # Also try to replace in common locations
    for logo_path in \
        "/usr/share/plymouth/themes/spinner/watermark.png" \
        "/usr/share/pixmaps/debian-logo.png" \
        "/usr/share/icons/desktop-base/64x64/emblems/emblem-debian.png"; do
        if [ -f "${CHROOT_DIR}${logo_path}" ]; then
            cp "${PROJECT_ROOT}/brand/icons/logo-64.png" "${CHROOT_DIR}${logo_path}"
            log "INFO" "  ✓ Replaced ${logo_path}"
        fi
    done
fi

# Create a vendor.conf to override the OS name shown in GDM
# This affects the "Debian 12" text at the bottom
mkdir -p "${CHROOT_DIR}/etc/gdm3"
if [ -f "${CHROOT_DIR}/etc/gdm3/greeter.dconf-defaults" ]; then
    # Append our settings if file exists
    cat >> "${CHROOT_DIR}/etc/gdm3/greeter.dconf-defaults" << 'EOF'

# NubiferOS branding
[org/gnome/login-screen]
logo='/usr/share/pixmaps/nubiferos/logo-128.png'
EOF
fi

log "INFO" "  ✓ GDM login screen branding configured"

# Remove or replace desktop-base Debian branding
log "INFO" "Replacing desktop-base Debian branding..."

# The "Debian 12" text comes from desktop-base package
# We need to replace the vendor logo and potentially modify the theme

# Replace Debian logos in desktop-base
if [ -d "${CHROOT_DIR}/usr/share/desktop-base" ]; then
    # Find and replace all Debian logos
    for debian_logo in $(find "${CHROOT_DIR}/usr/share/desktop-base" -name "*.png" -o -name "*.svg" 2>/dev/null | head -20); do
        # Only replace logo/emblem files, not wallpapers
        if echo "$debian_logo" | grep -qiE "(logo|emblem|vendor)"; then
            if [ -f "${PROJECT_ROOT}/brand/icons/logo-64.png" ]; then
                cp "${PROJECT_ROOT}/brand/icons/logo-64.png" "$debian_logo" 2>/dev/null || true
            fi
        fi
    done
fi

# Create/update the vendor configuration for GDM
# This tells GDM to show our branding instead of Debian's
mkdir -p "${CHROOT_DIR}/usr/share/gdm/greeter/images"
if [ -f "${PROJECT_ROOT}/brand/icons/logo-128.png" ]; then
    cp "${PROJECT_ROOT}/brand/icons/logo-128.png" "${CHROOT_DIR}/usr/share/gdm/greeter/images/logo.png"
fi

# Disable the Debian logo in GDM by creating an override
# GDM reads from /etc/gdm3/greeter.dconf-defaults
mkdir -p "${CHROOT_DIR}/etc/gdm3"
cat > "${CHROOT_DIR}/etc/gdm3/greeter.dconf-defaults" << 'EOF'
# NubiferOS GDM Configuration

[org/gnome/login-screen]
logo='/usr/share/pixmaps/nubiferos/logo-128.png'
disable-user-list=false
banner-message-enable=false

[org/gnome/desktop/interface]
cursor-theme='Adwaita'
icon-theme='Adwaita'
EOF

log "INFO" "  ✓ Desktop-base branding replaced"

# Set default user icon (replaces Debian logo for new users)
log "INFO" "Setting default user icon..."
mkdir -p "${CHROOT_DIR}/usr/share/pixmaps/faces"
if [ -f "${PROJECT_ROOT}/brand/icons/logo-256.png" ]; then
    cp "${PROJECT_ROOT}/brand/icons/logo-256.png" "${CHROOT_DIR}/usr/share/pixmaps/faces/nubiferos.png"
fi

# Set as default face for new users via /etc/skel
mkdir -p "${CHROOT_DIR}/etc/skel/.face.d"
if [ -f "${PROJECT_ROOT}/brand/icons/logo-256.png" ]; then
    cp "${PROJECT_ROOT}/brand/icons/logo-256.png" "${CHROOT_DIR}/etc/skel/.face"
fi

# Also set for AccountsService default
mkdir -p "${CHROOT_DIR}/var/lib/AccountsService/icons"
if [ -f "${PROJECT_ROOT}/brand/icons/logo-256.png" ]; then
    cp "${PROJECT_ROOT}/brand/icons/logo-256.png" "${CHROOT_DIR}/var/lib/AccountsService/icons/nubiferos-default"
fi

log "INFO" "  ✓ Default user icon configured"

# Install GNOME Shell context indicator extension
log "INFO" "Installing workspace context indicator extension..."
EXTENSION_UUID="nubiferos-context@nubiferos.org"
EXTENSION_DIR="${CHROOT_DIR}/usr/share/gnome-shell/extensions/${EXTENSION_UUID}"

mkdir -p "${EXTENSION_DIR}"
cp "${PROJECT_ROOT}/components/context-indicator/gnome-extension/extension.js" "${EXTENSION_DIR}/"
cp "${PROJECT_ROOT}/components/context-indicator/gnome-extension/metadata.json" "${EXTENSION_DIR}/"
cp "${PROJECT_ROOT}/components/context-indicator/gnome-extension/stylesheet.css" "${EXTENSION_DIR}/"

# Install terminal prompt integration
cp "${PROJECT_ROOT}/components/context-indicator/nubiferos-prompt.sh" "${CHROOT_DIR}/etc/profile.d/"
chmod +x "${CHROOT_DIR}/etc/profile.d/nubiferos-prompt.sh"

# Enable extension by default for all users via dconf
cat >> "${CHROOT_DIR}/etc/dconf/db/local.d/01-nubiferos-wallpaper" << 'EOF'

[org/gnome/shell]
enabled-extensions=['nubiferos-context@nubiferos.org']
EOF

# Lock down GNOME workspaces - only NubiferOS can manage them
log "INFO" "Locking down GNOME workspace management..."
cat > "${CHROOT_DIR}/etc/dconf/db/local.d/02-nubiferos-workspaces" << 'EOF'
# NubiferOS Workspace Management
# Workspaces are managed by NubiferOS, not GNOME directly

[org/gnome/desktop/wm/preferences]
# Start with 1 workspace, NubiferOS will add more as needed
num-workspaces=1

[org/gnome/mutter]
# Disable dynamic workspaces - NubiferOS controls workspace count
dynamic-workspaces=false

[org/gnome/shell/app-switcher]
# App switcher shows only current workspace apps
current-workspace-only=true
EOF

# Lock these settings so users can't change them
mkdir -p "${CHROOT_DIR}/etc/dconf/db/local.d/locks"
cat > "${CHROOT_DIR}/etc/dconf/db/local.d/locks/01-nubiferos-workspace-locks" << 'EOF'
# Lock workspace settings - managed by NubiferOS
/org/gnome/mutter/dynamic-workspaces
EOF

# Update dconf
chroot_exec "dconf update 2>/dev/null || true"

log "INFO" "  ✓ Context indicator extension installed"
log "INFO" "  ✓ GNOME workspace management locked down"
