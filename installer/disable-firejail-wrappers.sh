#!/bin/bash
# Disable Firejail CLI wrappers for NubiferOS
# Restores original cloud CLIs

set -e

echo "Disabling Firejail CLI wrappers..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Remove wrapper symlinks
for cli in aws az gcloud oci; do
    if [ -L "/usr/local/bin/$cli" ]; then
        echo "  Removing wrapper: /usr/local/bin/$cli"
        rm "/usr/local/bin/$cli"
    fi
done

echo "✓ Firejail CLI wrappers disabled"
echo ""
echo "Cloud CLIs will now run without isolation."
echo ""
echo "To re-enable, run:"
echo "  sudo /usr/share/nubifer/installer/enable-firejail-wrappers.sh"
