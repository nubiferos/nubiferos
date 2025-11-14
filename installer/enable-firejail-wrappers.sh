#!/bin/bash
# Enable Firejail CLI wrappers for NubiferOS
# Can be run after installation if user initially declined

set -e

echo "Enabling Firejail CLI wrappers..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Backup original CLIs if they exist
for cli in aws az gcloud oci; do
    if command -v $cli &> /dev/null; then
        original_path=$(which $cli)
        if [ ! -L "$original_path" ]; then
            # Only backup if not already a symlink
            backup_path="${original_path}.original"
            if [ ! -f "$backup_path" ]; then
                echo "  Backing up $cli to ${backup_path}"
                cp "$original_path" "$backup_path"
            fi
        fi
    fi
done

# Create wrapper symlinks
ln -sf /usr/local/lib/nubifer/cli-wrappers/aws /usr/local/bin/aws
ln -sf /usr/local/lib/nubifer/cli-wrappers/az /usr/local/bin/az
ln -sf /usr/local/lib/nubifer/cli-wrappers/gcloud /usr/local/bin/gcloud
ln -sf /usr/local/lib/nubifer/cli-wrappers/oci /usr/local/bin/oci

echo "✓ Firejail CLI wrappers enabled"
echo ""
echo "Cloud CLIs will now run in isolated sandboxes:"
echo "  • aws    - AWS CLI with workspace isolation"
echo "  • az     - Azure CLI with workspace isolation"
echo "  • gcloud - Google Cloud CLI with workspace isolation"
echo "  • oci    - Oracle Cloud CLI with workspace isolation"
echo ""
echo "To disable, run:"
echo "  sudo /usr/share/nubifer/installer/disable-firejail-wrappers.sh"
