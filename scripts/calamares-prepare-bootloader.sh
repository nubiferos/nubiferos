#!/bin/bash
# Prepare system for bootloader installation
# Ensures device nodes are visible and ready
#
# This script runs in chroot (dontChroot: false)

echo "=========================================="
echo "Preparing for bootloader installation"
echo "=========================================="

# Enable GRUB cryptodisk support for LUKS encrypted disks
echo "Enabling GRUB cryptodisk support..."
if [ -f /etc/default/grub ]; then
    # Check if already set
    if grep -q "GRUB_ENABLE_CRYPTODISK" /etc/default/grub; then
        # Update existing setting
        sed -i 's/^#*GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
    else
        # Add the setting
        echo "" >> /etc/default/grub
        echo "# Enable LUKS encrypted disk support" >> /etc/default/grub
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
    fi
    echo "✓ GRUB_ENABLE_CRYPTODISK=y set in /etc/default/grub"
    grep CRYPTODISK /etc/default/grub
else
    echo "WARNING: /etc/default/grub not found, creating it..."
    mkdir -p /etc/default
    cat > /etc/default/grub << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="NubiferOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_ENABLE_CRYPTODISK=y
EOF
    echo "✓ Created /etc/default/grub with cryptodisk support"
fi
echo ""

# Ensure all device nodes are settled and visible
echo "Waiting for device nodes to settle..."
udevadm settle --timeout=30

# Wait for specific devices to be available
echo "Checking for required devices..."
for i in {1..10}; do
  if [ -b /dev/sda ] || [ -b /dev/vda ]; then
    echo "✓ Boot device found"
    break
  fi
  echo "Waiting for boot device... (attempt $i/10)"
  sleep 1
  udevadm trigger
  udevadm settle --timeout=5
done

# List devices for debugging
echo ""
echo "Available block devices:"
ls -la /dev/sd* 2>/dev/null || echo "No /dev/sd* devices"
ls -la /dev/vd* 2>/dev/null || echo "No /dev/vd* devices"
echo ""

# Show partition information
echo "Partition information:"
blkid || echo "blkid failed"
echo ""

# Ensure /boot/efi directory exists
echo "Creating /boot/efi directory..."
mkdir -p /boot/efi
ls -la /boot/ | grep efi && echo "✓ /boot/efi exists" || echo "✗ /boot/efi missing"
echo ""

# Ensure EFI variables are accessible
if [ -d /sys/firmware/efi ]; then
  echo "✓ EFI mode detected"
  modprobe efivarfs 2>/dev/null || true
  mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || echo "efivarfs already mounted"
else
  echo "BIOS mode detected (no EFI)"
fi

echo ""
echo "=========================================="
echo "Bootloader preparation complete"
echo "=========================================="

exit 0
