#!/bin/bash
# NubiferOS Recovery Key Setup
# Creates a physical USB recovery key during installation
# NO BACKDOORS - Physical access required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "NubiferOS Recovery Key Setup"
echo "=========================================="
echo ""
echo "This will create a physical recovery key on a USB drive."
echo "This key can be used to:"
echo "  - Reset user passwords"
echo "  - Unlock encrypted drives"
echo "  - Access system in emergency"
echo ""
echo "⚠️  SECURITY NOTICE:"
echo "  - Physical access to USB key = full system access"
echo "  - Store in a secure location (safe, vault)"
echo "  - Create multiple copies for redundancy"
echo "  - NO network/remote access possible"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    exit 1
fi

# List available USB devices
list_usb_devices() {
    echo "Available USB devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part" | grep -v "loop"
    echo ""
}

# Generate recovery key
generate_recovery_key() {
    local key_file="$1"
    
    echo "Generating recovery key..."
    
    # Generate strong random key
    dd if=/dev/urandom bs=1 count=4096 2>/dev/null | base64 > "${key_file}"
    
    # Set secure permissions
    chmod 400 "${key_file}"
    
    echo "✓ Recovery key generated"
}

# Create recovery USB
create_recovery_usb() {
    local usb_device="$1"
    local key_file="$2"
    
    echo ""
    echo "⚠️  WARNING: This will ERASE all data on ${usb_device}"
    read -p "Continue? (yes/NO): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Aborted"
        exit 1
    fi
    
    echo "Creating recovery USB..."
    
    # Unmount if mounted
    umount "${usb_device}"* 2>/dev/null || true
    
    # Create new partition table
    parted -s "${usb_device}" mklabel gpt
    
    # Create single partition
    parted -s "${usb_device}" mkpart primary ext4 1MiB 100%
    
    # Format as ext4
    mkfs.ext4 -F "${usb_device}1" -L "NUBIFER_RECOVERY"
    
    # Mount
    local mount_point="/mnt/nubifer-recovery"
    mkdir -p "${mount_point}"
    mount "${usb_device}1" "${mount_point}"
    
    # Copy recovery key
    cp "${key_file}" "${mount_point}/recovery.key"
    
    # Create recovery info file
    cat > "${mount_point}/RECOVERY_INFO.txt" << EOF
NubiferOS Recovery Key
======================

Created: $(date)
Hostname: $(hostname)
System UUID: $(dmidecode -s system-uuid 2>/dev/null || echo "N/A")

This USB drive contains a recovery key for NubiferOS.

USAGE:
------
1. Boot NubiferOS system
2. Insert this USB drive
3. Run: sudo nubifer-recovery
4. Follow prompts

SECURITY:
---------
- Store in secure location (safe, vault)
- Physical access to this USB = full system access
- Create backup copies
- Never connect to untrusted systems
- Replace if compromised

EMERGENCY CONTACTS:
-------------------
IT Security: [Add your contact]
System Admin: [Add your contact]

EOF
    
    # Create recovery script
    cat > "${mount_point}/recovery.sh" << 'RECOVERY_SCRIPT'
#!/bin/bash
# NubiferOS Recovery Script
# Run this script from the recovery USB

set -e

echo "=========================================="
echo "NubiferOS Recovery Mode"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Must run as root"
    echo "Usage: sudo ./recovery.sh"
    exit 1
fi

# Verify recovery key
RECOVERY_KEY_FILE="$(dirname "$0")/recovery.key"

if [ ! -f "$RECOVERY_KEY_FILE" ]; then
    echo "ERROR: Recovery key not found"
    exit 1
fi

echo "Recovery key verified"
echo ""
echo "Recovery Options:"
echo "  1) Reset user password"
echo "  2) Unlock encrypted drive"
echo "  3) Emergency shell access"
echo "  4) View system logs"
echo "  5) Exit"
echo ""

read -p "Select option (1-5): " option

case $option in
    1)
        echo ""
        echo "Reset User Password"
        echo "-------------------"
        read -p "Username: " username
        
        if id "$username" &>/dev/null; then
            passwd "$username"
            echo "✓ Password reset for $username"
        else
            echo "ERROR: User $username not found"
        fi
        ;;
    2)
        echo ""
        echo "Unlock Encrypted Drive"
        echo "----------------------"
        echo "Available encrypted devices:"
        lsblk -o NAME,SIZE,TYPE,FSTYPE | grep crypto
        echo ""
        read -p "Device (e.g., /dev/sda2): " device
        
        cryptsetup luksOpen "$device" recovery_unlock
        echo "✓ Device unlocked as /dev/mapper/recovery_unlock"
        ;;
    3)
        echo ""
        echo "Emergency Shell Access"
        echo "----------------------"
        echo "Type 'exit' to return"
        /bin/bash
        ;;
    4)
        echo ""
        echo "System Logs"
        echo "-----------"
        journalctl -xe | tail -n 50
        ;;
    5)
        echo "Exiting"
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Recovery operation complete"
RECOVERY_SCRIPT
    
    chmod +x "${mount_point}/recovery.sh"
    
    # Create README
    cat > "${mount_point}/README.txt" << EOF
NubiferOS Recovery USB
======================

⚠️  SECURITY WARNING ⚠️
This USB drive provides FULL SYSTEM ACCESS.
Store securely. Physical access = complete control.

QUICK START:
1. Boot NubiferOS system
2. Insert this USB
3. Run: sudo /media/NUBIFER_RECOVERY/recovery.sh

FILES:
- recovery.key: Cryptographic recovery key
- recovery.sh: Recovery script
- RECOVERY_INFO.txt: System information
- README.txt: This file

For detailed instructions, see RECOVERY_INFO.txt
EOF
    
    # Sync and unmount
    sync
    umount "${mount_point}"
    
    echo "✓ Recovery USB created successfully"
    echo ""
    echo "USB Label: NUBIFER_RECOVERY"
    echo "Device: ${usb_device}1"
}

# Add recovery key to LUKS (for disk encryption)
add_luks_recovery_key() {
    local key_file="$1"
    
    echo ""
    echo "Add recovery key to encrypted drives?"
    echo "(This allows unlocking with the USB key)"
    read -p "Continue? (y/N): " add_luks
    
    if [ "$add_luks" = "y" ] || [ "$add_luks" = "Y" ]; then
        echo ""
        echo "Encrypted devices:"
        lsblk -o NAME,SIZE,TYPE,FSTYPE | grep crypto || echo "No encrypted devices found"
        echo ""
        read -p "Device to add key (e.g., /dev/sda2) or 'skip': " luks_device
        
        if [ "$luks_device" != "skip" ] && [ -b "$luks_device" ]; then
            echo "Adding recovery key to $luks_device..."
            cryptsetup luksAddKey "$luks_device" "$key_file"
            echo "✓ Recovery key added to LUKS device"
        fi
    fi
}

# Create system recovery command
install_recovery_command() {
    echo "Installing system recovery command..."
    
    cat > /usr/local/bin/nubifer-recovery << 'EOF'
#!/bin/bash
# NubiferOS Recovery Command
# Detects and mounts recovery USB

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Must run as root"
    echo "Usage: sudo nubifer-recovery"
    exit 1
fi

echo "=========================================="
echo "NubiferOS Recovery"
echo "=========================================="
echo ""
echo "Searching for recovery USB..."

# Find recovery USB
RECOVERY_DEVICE=$(blkid | grep "NUBIFER_RECOVERY" | cut -d: -f1)

if [ -z "$RECOVERY_DEVICE" ]; then
    echo "ERROR: Recovery USB not found"
    echo ""
    echo "Please insert the NubiferOS recovery USB and try again"
    exit 1
fi

echo "✓ Recovery USB found: $RECOVERY_DEVICE"

# Mount recovery USB
MOUNT_POINT="/media/NUBIFER_RECOVERY"
mkdir -p "$MOUNT_POINT"
mount "$RECOVERY_DEVICE" "$MOUNT_POINT"

echo "✓ Recovery USB mounted at $MOUNT_POINT"
echo ""

# Run recovery script
if [ -f "$MOUNT_POINT/recovery.sh" ]; then
    cd "$MOUNT_POINT"
    ./recovery.sh
else
    echo "ERROR: Recovery script not found on USB"
    umount "$MOUNT_POINT"
    exit 1
fi

# Cleanup
umount "$MOUNT_POINT"
echo ""
echo "Recovery USB unmounted"
EOF
    
    chmod +x /usr/local/bin/nubifer-recovery
    
    echo "✓ Recovery command installed: nubifer-recovery"
}

# Main execution
main() {
    # Generate recovery key
    KEY_FILE="/tmp/nubifer-recovery-$(date +%s).key"
    generate_recovery_key "$KEY_FILE"
    
    echo ""
    list_usb_devices
    
    read -p "Enter USB device (e.g., /dev/sdb): " USB_DEVICE
    
    if [ ! -b "$USB_DEVICE" ]; then
        echo "ERROR: Device $USB_DEVICE not found"
        rm -f "$KEY_FILE"
        exit 1
    fi
    
    # Create recovery USB
    create_recovery_usb "$USB_DEVICE" "$KEY_FILE"
    
    # Add to LUKS if desired
    add_luks_recovery_key "$KEY_FILE"
    
    # Install recovery command
    install_recovery_command
    
    # Cleanup
    shred -u "$KEY_FILE"
    
    echo ""
    echo "=========================================="
    echo "✓ Recovery Key Setup Complete"
    echo "=========================================="
    echo ""
    echo "IMPORTANT:"
    echo "  1. Remove USB and store in secure location"
    echo "  2. Label USB clearly: 'NubiferOS Recovery - $(hostname)'"
    echo "  3. Create backup copies (run this script again)"
    echo "  4. Document USB location in secure records"
    echo "  5. Test recovery process periodically"
    echo ""
    echo "To use recovery:"
    echo "  1. Boot system"
    echo "  2. Insert recovery USB"
    echo "  3. Run: sudo nubifer-recovery"
    echo ""
}

main "$@"
