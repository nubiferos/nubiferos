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

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Initialize pass store: nubifer-creds init"
echo "  2. Add credentials: nubifer-creds add --provider aws --account-id 123456789012 --account-name prod"
echo "  3. List credentials: nubifer-creds list"
echo ""
