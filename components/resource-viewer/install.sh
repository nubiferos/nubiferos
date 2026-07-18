#!/bin/bash
# NubiferOS Resource Viewer Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/lib/nubiferos/resource-viewer"
BIN_DIR="/usr/local/bin"

echo "Installing NubiferOS Resource Viewer..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y \
    python3 \
    python3-pip \
    python3-gi \
    gir1.2-gtk-3.0

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy source files
echo "Copying source files..."
cp -r "$SCRIPT_DIR/src/"* "$INSTALL_DIR/"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r "$SCRIPT_DIR/requirements.txt"

# Create CLI sync wrapper
echo "Creating CLI wrapper..."
cat > "$BIN_DIR/nubifer-resource-sync" << 'EOF'
#!/bin/bash
# NubiferOS Resource Viewer sync CLI wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/resource-viewer"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/indexer.py" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-resource-sync"

# Create GUI launcher wrapper
echo "Creating GUI launcher..."
cat > "$BIN_DIR/nubifer-resources" << 'EOF'
#!/bin/bash
# NubiferOS Resource Viewer GUI wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/resource-viewer"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/nubifer-resources" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-resources"
chmod +x "$INSTALL_DIR/nubifer-resources"

# Desktop entry (matches security-dashboard convention)
echo "Installing desktop entry..."
cp "$SCRIPT_DIR/nubifer-resources.desktop" /usr/share/applications/nubifer-resources.desktop
chmod 644 /usr/share/applications/nubifer-resources.desktop

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Activate a workspace so the credential chain is populated:"
echo "     nubifer-workspace switch <name>"
echo "  2. Sync your inventory: nubifer-resource-sync"
echo "     (or click Sync in the GUI: nubifer-resources)"
echo "  3. Limit regions for a faster sync:"
echo "     nubifer-resource-sync --regions us-east-1,eu-west-1"
echo ""
echo "Database: ~/.local/share/nubifer/resources.db (metadata only, no secrets)"
echo ""
