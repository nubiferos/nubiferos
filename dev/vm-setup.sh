#!/bin/bash
# NubiferOS VM Development Setup
# Run this ON THE VM to prepare it for development
#
# Usage: curl -sL <url> | bash
# Or:    scp vm-setup.sh user@vm: && ssh user@vm "./vm-setup.sh"

set -e

echo "=========================================="
echo "NubiferOS VM Development Setup"
echo "=========================================="

# Install SSH server
echo "[1/5] Installing SSH server..."
sudo apt-get update
sudo apt-get install -y openssh-server

# Enable and start SSH
echo "[2/5] Enabling SSH service..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure firewall
echo "[3/5] Configuring firewall..."
sudo ufw allow ssh
sudo ufw --force enable || true

# Install development dependencies
echo "[4/5] Installing development dependencies..."
sudo apt-get install -y \
    python3-pip \
    python3-gi \
    python3-dbus \
    gir1.2-gtk-3.0 \
    gir1.2-secret-1 \
    gnome-shell-extension-prefs \
    pass \
    gnupg

# Install Python packages for NubiferOS components
pip3 install --user dbus-python PyGObject || true

# Create directories
echo "[5/5] Setting up directories..."
mkdir -p ~/.local/share/gnome-shell/extensions
mkdir -p ~/.config/systemd/user
mkdir -p ~/.config/nubiferos

# Show IP address
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Your VM IP addresses:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'
echo ""
echo "On your dev machine, run:"
echo "  ssh-copy-id $(whoami)@<IP_ADDRESS>"
echo ""
echo "Then deploy components with:"
echo "  ./dev/dev-deploy.sh all <IP_ADDRESS>"
echo ""
