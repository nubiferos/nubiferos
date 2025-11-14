#!/bin/bash
# Post-installation script for NubiferOS Workspace Manager
# This runs after OS installation to set up workspace isolation

set -e

echo "=========================================="
echo "NubiferOS Workspace Manager Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Function to enable Firejail CLI wrappers
enable_firejail_wrappers() {
    echo "Enabling Firejail CLI wrappers for workspace isolation..."
    
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
    
    # Create wrapper symlinks in /usr/local/bin (higher priority than /usr/bin)
    ln -sf /usr/local/lib/nubifer/cli-wrappers/aws /usr/local/bin/aws
    ln -sf /usr/local/lib/nubifer/cli-wrappers/az /usr/local/bin/az
    ln -sf /usr/local/lib/nubifer/cli-wrappers/gcloud /usr/local/bin/gcloud
    ln -sf /usr/local/lib/nubifer/cli-wrappers/oci /usr/local/bin/oci
    
    echo "✓ Firejail CLI wrappers enabled"
}

# Ask user if they want to enable Firejail isolation
echo "NubiferOS Workspace Manager provides secure workspace isolation"
echo "using Firejail sandboxing. This prevents credential leakage"
echo "between workspaces and enforces read-only mode."
echo ""
echo "Would you like to enable Firejail CLI wrappers?"
echo "  - Yes: Cloud CLIs (aws, az, gcloud, oci) will run in isolated sandboxes"
echo "  - No: Cloud CLIs will run normally (you can enable later)"
echo ""
read -p "Enable Firejail isolation? [Y/n] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    enable_firejail_wrappers
else
    echo "Firejail isolation not enabled."
    echo "You can enable it later by running:"
    echo "  sudo /usr/share/nubifer/installer/enable-firejail-wrappers.sh"
fi

echo ""
echo "=========================================="
echo "✓ Workspace Manager Setup Complete"
echo "=========================================="
echo ""
echo "Getting Started:"
echo ""
echo "1. Create a workspace:"
echo "   nubifer-workspace create \\"
echo "     --name 'AWS Production' \\"
echo "     --provider aws \\"
echo "     --account-id 123456789012 \\"
echo "     --region us-east-1"
echo ""
echo "2. List workspaces:"
echo "   nubifer-workspace list"
echo ""
echo "3. Switch workspace:"
echo "   nubifer-workspace switch <workspace-id>"
echo "   eval \$(nubifer-workspace env <workspace-id>)"
echo ""
echo "4. Your terminal prompt will show the active workspace:"
echo "   [☁️ prod-account] user@host:~$"
echo ""
echo "Documentation:"
echo "  /usr/share/doc/nubifer/README.md"
echo "  /usr/share/doc/nubifer/FIREJAIL_INTEGRATION.md"
echo ""
echo "Aliases:"
echo "  nw          - Short for nubifer-workspace"
echo "  nw-switch   - Quick workspace switching"
echo "  nw-context  - Show current workspace"
echo ""
