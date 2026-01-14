#!/bin/bash
# NubiferOS Credential Manager Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/lib/nubiferos/credential-manager"
BIN_DIR="/usr/local/bin"

echo "Installing NubiferOS Credential Manager..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y \
    pass \
    gnupg \
    python3 \
    python3-pip \
    python3-dbus \
    python3-gi

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy source files
echo "Copying source files..."
cp -r "$SCRIPT_DIR/src/"* "$INSTALL_DIR/"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r "$SCRIPT_DIR/requirements.txt"

# Create CLI wrapper script
echo "Creating CLI wrapper..."
cat > "$BIN_DIR/nubifer-creds" << 'EOF'
#!/bin/bash
# NubiferOS Credential Manager CLI wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/credential-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/cli.py" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-creds"

# Create D-Bus service wrapper
echo "Creating D-Bus service wrapper..."
cat > "$BIN_DIR/nubifer-creds-service" << 'EOF'
#!/bin/bash
# NubiferOS Credential Manager D-Bus service wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/credential-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/dbus_interface.py" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-creds-service"

# Install systemd service files (optional - for auto-start on boot)
if [ -d "$SCRIPT_DIR/systemd" ]; then
    echo "Installing systemd service files..."
    
    # Install user service file
    SYSTEMD_USER_DIR="/usr/lib/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"
    
    if [ -f "$SCRIPT_DIR/systemd/nubifer-credential-manager.service" ]; then
        cp "$SCRIPT_DIR/systemd/nubifer-credential-manager.service" "$SYSTEMD_USER_DIR/"
        echo "  ✓ Installed user service: $SYSTEMD_USER_DIR/nubifer-credential-manager.service"
    fi
    
    # Install D-Bus service file for auto-activation
    DBUS_SERVICES_DIR="/usr/share/dbus-1/services"
    mkdir -p "$DBUS_SERVICES_DIR"
    
    if [ -f "$SCRIPT_DIR/systemd/org.nubiferos.CredentialManager.service" ]; then
        cp "$SCRIPT_DIR/systemd/org.nubiferos.CredentialManager.service" "$DBUS_SERVICES_DIR/"
        echo "  ✓ Installed D-Bus service: $DBUS_SERVICES_DIR/org.nubiferos.CredentialManager.service"
    fi
    
    # Reload systemd daemon
    systemctl daemon-reload 2>/dev/null || true
    
    echo ""
    echo "Systemd service installed but NOT enabled by default."
    echo "To enable auto-start on boot (per-user):"
    echo "  systemctl --user enable nubifer-credential-manager.service"
    echo "  systemctl --user start nubifer-credential-manager.service"
    echo ""
    echo "To check service status:"
    echo "  systemctl --user status nubifer-credential-manager.service"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Initialize pass store: nubifer-creds init"
echo "  2. Add credentials: nubifer-creds add --provider aws --account-id 123456789012 --account-name prod"
echo "  3. List credentials: nubifer-creds list"
echo ""
echo "Optional - Enable D-Bus service to start on boot:"
echo "  systemctl --user enable nubifer-credential-manager.service"
echo ""
