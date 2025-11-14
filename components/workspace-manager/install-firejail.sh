#!/bin/bash
# Installation script for NubiferOS Firejail Integration

set -e

echo "Installing NubiferOS Firejail Integration..."
echo "============================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Create required directories
echo "Creating system directories..."
mkdir -p /etc/nubifer
mkdir -p /etc/firejail/nubifer
mkdir -p /usr/local/lib/nubifer
mkdir -p /usr/local/lib/nubifer/cli-wrappers
chmod 755 /etc/nubifer
chmod 755 /etc/firejail/nubifer
chmod 755 /usr/local/lib/nubifer
chmod 755 /usr/local/lib/nubifer/cli-wrappers

# Check if Firejail is installed
if ! command -v firejail &> /dev/null; then
    echo "Firejail not found. Installing..."
    apt-get update
    apt-get install -y firejail
    echo "✓ Firejail installed"
else
    echo "✓ Firejail already installed"
fi

# Install base profiles
echo "Installing Firejail profiles..."
cp firejail-profiles/*.profile /etc/firejail/nubifer/
chmod 644 /etc/firejail/nubifer/*.profile
echo "✓ Profiles installed to /etc/firejail/nubifer/"

# Install Firejail wrapper
echo "Installing Firejail wrapper..."
cp firejail-wrapper.sh /usr/local/lib/nubifer/
chmod 755 /usr/local/lib/nubifer/firejail-wrapper.sh
echo "✓ Wrapper installed to /usr/local/lib/nubifer/"

# Install CLI wrappers
echo "Installing CLI wrappers..."
cp cli-wrappers/* /usr/local/lib/nubifer/cli-wrappers/
chmod 755 /usr/local/lib/nubifer/cli-wrappers/*

# Create symlinks to override system CLIs
echo "Creating CLI wrapper symlinks..."

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

echo "✓ CLI wrappers installed"

# Configure Firejail
echo "Configuring Firejail..."

# Enable Firejail by default for cloud CLIs
if [ ! -f /etc/firejail/firejail.config ]; then
    cat > /etc/firejail/firejail.config << 'EOF'
# NubiferOS Firejail Configuration

# Enable seccomp by default
seccomp yes

# Enable AppArmor integration
apparmor yes

# Restrict network access
restricted-network no

# Enable audit logging
audit yes
EOF
    chmod 644 /etc/firejail/firejail.config
    echo "✓ Firejail configured"
else
    echo "✓ Firejail config already exists"
fi

# Test Firejail installation
echo ""
echo "Testing Firejail installation..."
if firejail --version &> /dev/null; then
    echo "✓ Firejail is working"
else
    echo "✗ Firejail test failed"
    exit 1
fi

echo ""
echo "============================================"
echo "✓ Firejail integration installed!"
echo "============================================"
echo ""
echo "Features enabled:"
echo "  ✓ Workspace isolation via Firejail"
echo "  ✓ Credential directory isolation"
echo "  ✓ Read-only mode enforcement"
echo "  ✓ CLI command sandboxing"
echo ""
echo "Wrapped commands:"
echo "  • aws    - AWS CLI with workspace isolation"
echo "  • az     - Azure CLI with workspace isolation"
echo "  • gcloud - Google Cloud CLI with workspace isolation"
echo "  • oci    - Oracle Cloud CLI with workspace isolation"
echo ""
echo "Original CLIs backed up with .original extension"
echo ""
echo "To restore original CLIs:"
echo "  sudo rm /usr/local/bin/{aws,az,gcloud,oci}"
echo "  sudo cp /usr/bin/*.original /usr/bin/"
echo ""
echo "Test workspace isolation:"
echo "  1. Create workspace: nubifer-workspace create --name test --provider aws --account-id 123"
echo "  2. Activate workspace: eval \$(nubifer-workspace env <workspace-id>)"
echo "  3. Run AWS CLI: aws s3 ls"
echo "  4. Check Firejail: ps aux | grep firejail"
echo ""
