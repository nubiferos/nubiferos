#!/bin/bash
# NubiferOS Context Manager Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/lib/nubiferos/context-manager"
BIN_DIR="/usr/local/bin"
PROFILE_D="/etc/profile.d"

echo "Installing NubiferOS Context Manager..."

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
cat > "$BIN_DIR/nubifer-workspace" << 'EOF'
#!/bin/bash
# NubiferOS Context Manager CLI wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/context-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/cli.py" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-workspace"

# Create D-Bus service wrapper
echo "Creating D-Bus service wrapper..."
cat > "$BIN_DIR/nubifer-context-service" << 'EOF'
#!/bin/bash
# NubiferOS Context Manager D-Bus service wrapper

INSTALL_DIR="/usr/local/lib/nubiferos/context-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"

exec python3 "$INSTALL_DIR/dbus_interface.py" "$@"
EOF

chmod +x "$BIN_DIR/nubifer-context-service"

# Install shell integration
echo "Installing shell integration..."
cp "$SCRIPT_DIR/nubiferos-context.sh" "$PROFILE_D/nubiferos-context.sh"
chmod +x "$PROFILE_D/nubiferos-context.sh"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Create a workspace: nubifer-workspace create --name 'AWS Prod' --provider aws --account-id 123456789012"
echo "  2. List workspaces: nubifer-workspace list"
echo "  3. Switch workspace: nubifer-workspace switch <workspace-id>"
echo "  4. Activate in shell: eval \$(nubifer-workspace env <workspace-id>)"
echo ""
echo "Shell integration will be active in new shells (source /etc/profile.d/nubiferos-context.sh)"
echo ""
