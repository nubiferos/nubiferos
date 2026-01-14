#!/bin/bash
# NubiferOS CLI Wrappers Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
BIN_DIR="/usr/local/bin"

echo "Installing NubiferOS CLI Wrappers..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Create wrapper directory
echo "Creating wrapper directory..."
mkdir -p "$WRAPPER_DIR"

# Copy wrapper files
echo "Copying wrapper files..."
cp "$SCRIPT_DIR/wrapper_base.py" "$WRAPPER_DIR/"
cp "$SCRIPT_DIR/aws-wrapper.py" "$WRAPPER_DIR/"
cp "$SCRIPT_DIR/az-wrapper.py" "$WRAPPER_DIR/"
cp "$SCRIPT_DIR/gcloud-wrapper.py" "$WRAPPER_DIR/"
cp "$SCRIPT_DIR/terraform-wrapper.py" "$WRAPPER_DIR/"
cp "$SCRIPT_DIR/kubectl-wrapper.py" "$WRAPPER_DIR/"

# Make wrappers executable
chmod +x "$WRAPPER_DIR"/*.py

# Create wrapper scripts in /usr/local/bin
echo "Creating wrapper scripts..."

# AWS wrapper
cat > "$BIN_DIR/aws" << 'EOF'
#!/bin/bash
# NubiferOS AWS CLI Wrapper
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
export PYTHONPATH="$WRAPPER_DIR:$PYTHONPATH"
exec python3 "$WRAPPER_DIR/aws-wrapper.py" "$@"
EOF
chmod +x "$BIN_DIR/aws"

# Azure wrapper
cat > "$BIN_DIR/az" << 'EOF'
#!/bin/bash
# NubiferOS Azure CLI Wrapper
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
export PYTHONPATH="$WRAPPER_DIR:$PYTHONPATH"
exec python3 "$WRAPPER_DIR/az-wrapper.py" "$@"
EOF
chmod +x "$BIN_DIR/az"

# GCloud wrapper
cat > "$BIN_DIR/gcloud" << 'EOF'
#!/bin/bash
# NubiferOS GCloud CLI Wrapper
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
export PYTHONPATH="$WRAPPER_DIR:$PYTHONPATH"
exec python3 "$WRAPPER_DIR/gcloud-wrapper.py" "$@"
EOF
chmod +x "$BIN_DIR/gcloud"

# Terraform wrapper
cat > "$BIN_DIR/terraform" << 'EOF'
#!/bin/bash
# NubiferOS Terraform Wrapper
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
export PYTHONPATH="$WRAPPER_DIR:$PYTHONPATH"
exec python3 "$WRAPPER_DIR/terraform-wrapper.py" "$@"
EOF
chmod +x "$BIN_DIR/terraform"

# Kubectl wrapper
cat > "$BIN_DIR/kubectl" << 'EOF'
#!/bin/bash
# NubiferOS Kubectl Wrapper
WRAPPER_DIR="/usr/local/lib/nubiferos/cli-wrappers"
export PYTHONPATH="$WRAPPER_DIR:$PYTHONPATH"
exec python3 "$WRAPPER_DIR/kubectl-wrapper.py" "$@"
EOF
chmod +x "$BIN_DIR/kubectl"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Installed wrappers:"
echo "  - /usr/local/bin/aws (wraps /usr/bin/aws)"
echo "  - /usr/local/bin/az (wraps /usr/bin/az)"
echo "  - /usr/local/bin/gcloud (wraps /usr/bin/gcloud)"
echo "  - /usr/local/bin/terraform (wraps /usr/bin/terraform)"
echo "  - /usr/local/bin/kubectl (wraps /usr/bin/kubectl)"
echo ""
echo "These wrappers will:"
echo "  1. Automatically inject credentials from active workspace"
echo "  2. Enforce read-only mode when enabled"
echo "  3. Prevent accidental destructive operations"
echo ""
echo "Note: /usr/local/bin is typically before /usr/bin in PATH,"
echo "      so these wrappers will be used instead of system binaries."
echo ""
echo "To bypass wrappers (use real binaries):"
echo "  /usr/bin/aws ..."
echo "  /usr/bin/az ..."
echo ""
