#!/bin/bash
# Install and configure Calamares installer for NubiferOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Installing Calamares installer..."

# Install Calamares and dependencies
log "INFO" "Installing Calamares packages..."
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    calamares \
    calamares-settings-debian \
    qml-module-qtquick2 \
    qml-module-qtquick-controls \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2"

# Create Calamares configuration directory
log "INFO" "Creating Calamares configuration..."
mkdir -p "${CHROOT_DIR}/etc/calamares"
mkdir -p "${CHROOT_DIR}/etc/calamares/modules"
mkdir -p "${CHROOT_DIR}/etc/calamares/branding/nubiferos"

# Copy Calamares configuration files
log "INFO" "Copying configuration files..."
cp -r "${PROJECT_ROOT}/installer/calamares/"* "${CHROOT_DIR}/etc/calamares/" || true

log "INFO" "✓ Calamares installed and configured"
