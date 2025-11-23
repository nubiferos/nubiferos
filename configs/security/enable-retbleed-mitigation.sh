#!/bin/bash
# Enable full RETBleed mitigation

set -e

echo "=========================================="
echo "Enable RETBleed Mitigation"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Backup GRUB config
echo "Backing up GRUB configuration..."
cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)

# Check current configuration
echo "Current GRUB configuration:"
grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub

echo ""
echo "⚠️  WARNING: Enabling full RETBleed mitigation"
echo ""
echo "This will:"
echo "  - Add 'retbleed=auto' to kernel parameters"
echo "  - Reduce performance by 15-30%"
echo "  - Provide full protection against RETBleed attacks"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Update GRUB configuration
echo ""
echo "Updating GRUB configuration..."

# Check if retbleed parameter already exists
if grep -q "retbleed=" /etc/default/grub; then
    echo "RETBleed parameter already exists, updating..."
    sed -i 's/retbleed=[^ "]*/retbleed=auto/' /etc/default/grub
else
    echo "Adding RETBleed mitigation parameter..."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 retbleed=auto"/' /etc/default/grub
fi

# Show new configuration
echo ""
echo "New GRUB configuration:"
grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub

# Update GRUB
echo ""
echo "Updating GRUB..."
update-grub

echo ""
echo "=========================================="
echo "✓ RETBleed mitigation enabled"
echo "=========================================="
echo ""
echo "IMPORTANT: You must reboot for changes to take effect"
echo ""
echo "After reboot, verify with:"
echo "  cat /sys/devices/system/cpu/vulnerabilities/retbleed"
echo "  ./testing/check-cpu-mitigations.sh"
echo ""
echo "To revert, restore from backup:"
echo "  sudo cp /etc/default/grub.backup.* /etc/default/grub"
echo "  sudo update-grub"
echo "  sudo reboot"
echo ""
