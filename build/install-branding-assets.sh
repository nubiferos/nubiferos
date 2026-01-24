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
