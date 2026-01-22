#!/bin/bash
# Fix /dev bind mounts after Calamares mount module
# Calamares mount module can't handle bind mounts properly,
# so we do them manually here
#
# This script runs with dontChroot: true (in live environment)

set -x  # Enable debug output
exec 2>&1  # Redirect stderr to stdout

echo "=========================================="
echo "Fixing /dev bind mounts"
echo "=========================================="

# Show all current mounts
echo "Current mounts:"
mount | grep calamares || echo "No calamares mounts found yet"

# Find the Calamares root mount point - try multiple methods
ROOT_MOUNT=$(mount | grep 'type ext4' | grep calamares | head -1 | awk '{print $3}')

if [ -z "$ROOT_MOUNT" ]; then
  echo "Method 1 failed, trying method 2..."
  ROOT_MOUNT=$(df | grep calamares | grep -v tmpfs | head -1 | awk '{print $NF}')
fi

if [ -z "$ROOT_MOUNT" ]; then
  echo "Method 2 failed, trying method 3..."
  ROOT_MOUNT=$(ls -d /tmp/user/*/calamares-root-* 2>/dev/null | head -1)
fi

if [ -z "$ROOT_MOUNT" ]; then
  echo "ERROR: Could not find Calamares root mount after trying 3 methods"
  echo "Available mounts:"
  mount
  echo "Available /tmp directories:"
  ls -la /tmp/user/*/calamares-* 2>/dev/null || echo "None found"
  exit 1
fi

echo "Found root mount point: $ROOT_MOUNT"

# Ensure target directories exist
mkdir -p "$ROOT_MOUNT/dev"
mkdir -p "$ROOT_MOUNT/dev/pts"
mkdir -p "$ROOT_MOUNT/run/udev"

# Bind mount /dev
echo "Bind mounting /dev..."
if mount --bind /dev "$ROOT_MOUNT/dev"; then
  echo "✓ /dev mounted successfully"
else
  echo "✗ Failed to mount /dev"
  exit 1
fi

# Bind mount /dev/pts
echo "Bind mounting /dev/pts..."
if mount --bind /dev/pts "$ROOT_MOUNT/dev/pts"; then
  echo "✓ /dev/pts mounted successfully"
else
  echo "✗ Failed to mount /dev/pts"
fi

# Bind mount /run/udev
echo "Bind mounting /run/udev..."
if mount --bind /run/udev "$ROOT_MOUNT/run/udev"; then
  echo "✓ /run/udev mounted successfully"
else
  echo "✗ Failed to mount /run/udev"
fi

echo ""
echo "Verifying mounts..."
mount | grep "$ROOT_MOUNT"

echo ""
echo "Checking device visibility in target..."
ls -la "$ROOT_MOUNT/dev/sd"* 2>/dev/null || ls -la "$ROOT_MOUNT/dev/vd"* 2>/dev/null || echo "WARNING: No block devices visible"

echo ""
echo "=========================================="
echo "/dev bind mounts complete"
echo "=========================================="

exit 0
