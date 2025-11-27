#!/bin/bash
# Fix Calamares Debian-specific issues
# Addresses the install-debian.desktop error

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Fixing Calamares Debian-specific issues..."

# The calamares-settings-debian package includes scripts that try to:
# 1. Copy /usr/share/applications/install-debian.desktop to ~/Desktop
# 2. Run xdg-user-dirs-update
# These fail because:
# - Desktop directory doesn't exist in live environment
# - install-debian.desktop doesn't exist (we use our own config)

# Solution: Create a wrapper script that handles these gracefully

# Check if the Debian Calamares script exists
if [ -f "${CHROOT_DIR}/usr/bin/add-calamares-desktop-icon" ]; then
    log "INFO" "Found add-calamares-desktop-icon script, replacing with safe version..."
    
    # Backup original
    chroot_exec "mv /usr/bin/add-calamares-desktop-icon /usr/bin/add-calamares-desktop-icon.orig || true"
    
    # Create safe replacement
    cat > "${CHROOT_DIR}/usr/bin/add-calamares-desktop-icon" << 'EOF'
#!/bin/bash
# Safe wrapper for add-calamares-desktop-icon
# Prevents errors when Desktop directory or files don't exist

# Exit silently - we handle Calamares autostart differently
exit 0
EOF
    
    chmod +x "${CHROOT_DIR}/usr/bin/add-calamares-desktop-icon"
    log "INFO" "✓ Replaced add-calamares-desktop-icon with safe version"
fi

# Also check for any systemd services that might call this
if [ -f "${CHROOT_DIR}/etc/systemd/system/calamares-desktop-icon.service" ]; then
    log "INFO" "Disabling calamares-desktop-icon service..."
    chroot_exec "systemctl disable calamares-desktop-icon.service || true"
    chroot_exec "systemctl mask calamares-desktop-icon.service || true"
fi

# Remove the install-debian.desktop file if it exists (we don't use it)
if [ -f "${CHROOT_DIR}/usr/share/applications/install-debian.desktop" ]; then
    log "INFO" "Removing install-debian.desktop (using our own configuration)..."
    rm -f "${CHROOT_DIR}/usr/share/applications/install-debian.desktop"
fi

# Ensure xdg-user-dirs is installed and configured
log "INFO" "Configuring XDG user directories..."
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-user-dirs"

# Create default XDG directories for live user
if [ -d "${CHROOT_DIR}/home/live" ]; then
    log "INFO" "Creating XDG directories for live user..."
    chroot_exec "su - live -c 'xdg-user-dirs-update' || true"
    
    # Ensure Desktop directory exists
    mkdir -p "${CHROOT_DIR}/home/live/Desktop"
    chroot_exec "chown live:live /home/live/Desktop"
fi

log "INFO" "✓ Calamares Debian issues fixed"
