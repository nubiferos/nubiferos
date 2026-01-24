#!/bin/bash
# Configure Plymouth boot splash for NubiferOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Configuring Plymouth boot splash..."

# Install Plymouth if not present
chroot_exec "apt-get install -y plymouth plymouth-themes"

# Create NubiferOS theme directory
THEME_DIR="${CHROOT_DIR}/usr/share/plymouth/themes/nubiferos"
mkdir -p "$THEME_DIR"

# Copy theme files
cp "${PROJECT_ROOT}/branding/plymouth/nubiferos/nubiferos.plymouth" "$THEME_DIR/"
cp "${PROJECT_ROOT}/branding/plymouth/nubiferos/nubiferos.script" "$THEME_DIR/"

# Copy logo from Calamares branding (or use a placeholder)
if [ -f "${PROJECT_ROOT}/installer/calamares/branding/nubiferos/logo.png" ]; then
    cp "${PROJECT_ROOT}/installer/calamares/branding/nubiferos/logo.png" "$THEME_DIR/"
    log "INFO" "Using logo from Calamares branding"
else
    # Create a simple text-based placeholder logo
    log "INFO" "Creating placeholder logo..."
    chroot_exec "apt-get install -y imagemagick"
    chroot_exec "convert -size 200x60 xc:'#2c3e50' -fill white -gravity center -pointsize 24 -annotate 0 'NubiferOS' /usr/share/plymouth/themes/nubiferos/logo.png"
fi

# Create spinner frames (simple rotating dots)
log "INFO" "Creating spinner animation frames..."
chroot_exec "apt-get install -y imagemagick"
for i in $(seq 0 35); do
    angle=$((i * 10))
    chroot_exec "convert -size 32x32 xc:transparent -fill '#3498db' -draw 'translate 16,16 rotate $angle circle 0,-12 0,-10' /usr/share/plymouth/themes/nubiferos/spinner-${i}.png"
done

# Create progress bar images
chroot_exec "convert -size 400x8 xc:'#34495e' -fill '#34495e' -draw 'roundrectangle 0,0 399,7 4,4' /usr/share/plymouth/themes/nubiferos/progress-box.png"
chroot_exec "convert -size 400x8 xc:'#3498db' -fill '#3498db' -draw 'roundrectangle 0,0 399,7 4,4' /usr/share/plymouth/themes/nubiferos/progress-bar.png"

# Install the theme
log "INFO" "Installing NubiferOS Plymouth theme..."
chroot_exec "plymouth-set-default-theme nubiferos"

# Update initramfs to include the theme
log "INFO" "Updating initramfs with Plymouth theme..."
chroot_exec "update-initramfs -u"

log "INFO" "✓ Plymouth configured with NubiferOS branding"
