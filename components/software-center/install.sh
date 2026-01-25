#!/bin/bash
# Install NubiferOS Software Center
# Part of NubiferOS build system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_ROOT="${1:-}"

# If DEST_ROOT provided, install to chroot
if [ -n "$DEST_ROOT" ]; then
    PREFIX="$DEST_ROOT"
else
    PREFIX=""
fi

echo "Installing NubiferOS Software Center..."

# Install main application
install -Dm755 "${SCRIPT_DIR}/nubifer-software" "${PREFIX}/usr/bin/nubifer-software"

# Install desktop file
install -Dm644 "${SCRIPT_DIR}/nubifer-software.desktop" "${PREFIX}/usr/share/applications/nubifer-software.desktop"

# Install installer scripts
mkdir -p "${PREFIX}/usr/share/nubiferos/installers"
for script in "${SCRIPT_DIR}/../../scripts/installers/"*.sh; do
    if [ -f "$script" ]; then
        install -Dm755 "$script" "${PREFIX}/usr/share/nubiferos/installers/$(basename "$script")"
    fi
done

echo "✓ NubiferOS Software Center installed"
