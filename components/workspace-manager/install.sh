#!/bin/bash
# Installation script for NubiferOS Workspace Manager

set -e

echo "Installing NubiferOS Workspace Manager..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Create required directories
echo "Creating system directories..."
mkdir -p /etc/nubifer
mkdir -p /usr/local/lib/nubifer
chmod 755 /etc/nubifer
chmod 755 /usr/local/lib/nubifer

# Install to /usr/local/bin
echo "Installing nubifer-workspace command..."
cp nubifer-workspace /usr/local/bin/
chmod +x /usr/local/bin/nubifer-workspace

# Install GNOME desktop integration
echo "Installing GNOME virtual desktop integration..."
cp gnome-desktop-integration.py /usr/local/lib/nubifer/
chmod +x /usr/local/lib/nubifer/gnome-desktop-integration.py
ln -sf /usr/local/lib/nubifer/gnome-desktop-integration.py /usr/local/bin/nubifer-desktop

# Install shell integration
echo "Installing shell integration..."
cp shell-integration.sh /etc/nubifer/shell-integration.sh
chmod 644 /etc/nubifer/shell-integration.sh

# Add to /etc/bash.bashrc for system-wide integration
if ! grep -q "nubifer/shell-integration.sh" /etc/bash.bashrc; then
    echo "" >> /etc/bash.bashrc
    echo "# NubiferOS Workspace Integration" >> /etc/bash.bashrc
    echo "if [ -f /etc/nubifer/shell-integration.sh ]; then" >> /etc/bash.bashrc
    echo "    source /etc/nubifer/shell-integration.sh" >> /etc/bash.bashrc
    echo "fi" >> /etc/bash.bashrc
    echo "✓ Added to /etc/bash.bashrc"
fi

# Create system directories
mkdir -p /etc/nubifer
chmod 755 /etc/nubifer

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  nubifer-workspace create --name 'AWS Prod' --provider aws --account-id 123456789012"
echo "  nubifer-workspace list"
echo "  nubifer-workspace switch <workspace-id>"
echo "  nubifer-workspace current"
echo ""
echo "Aliases:"
echo "  nw          - Short for nubifer-workspace"
echo "  nw-switch   - Quick workspace switching"
echo "  nw-context  - Show current workspace"
echo ""
echo "Restart your shell or run: source /etc/nubifer/shell-integration.sh"
