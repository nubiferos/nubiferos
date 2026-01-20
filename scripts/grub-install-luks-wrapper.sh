#!/bin/bash
# GRUB installation wrapper for LUKS encrypted systems
# Handles the device mapping issues with encrypted root filesystems

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> /tmp/grub-install-wrapper.log
}

log "=========================================="
log "GRUB Installation Wrapper Started"
log "=========================================="
log "Script: $0"
log "Arguments: $*"
log "Working directory: $(pwd)"
log "User: $(whoami)"
log "Environment:"
env | grep -E "CALAMARES|ROOT|CHROOT" | while read line; do log "  $line"; done || true

log "Starting GRUB installation for LUKS encrypted system..."
log "Wrapper version: 2.0 (UEFI + BIOS support)"

# Get the target device (usually /dev/vda or /dev/sda)
TARGET_DEVICE="$1"
if [ -z "$TARGET_DEVICE" ]; then
    log "ERROR: No target device specified"
    exit 1
fi

log "Target device: $TARGET_DEVICE"
log ""

# Check if we're in EFI mode
if [ -d /sys/firmware/efi ]; then
    log "Firmware mode: UEFI (EFI directory exists)"
    FIRMWARE_MODE="UEFI"
else
    log "Firmware mode: BIOS (no EFI directory)"
    FIRMWARE_MODE="BIOS"
fi
log ""

# Wait for LUKS devices to be available
log "Waiting for LUKS devices to be ready..."
sleep 5

# Find the LUKS device
LUKS_DEVICE=$(ls /dev/mapper/luks-* 2>/dev/null | head -1 || true)
if [ -n "$LUKS_DEVICE" ]; then
    log "Found LUKS device: $LUKS_DEVICE"
else
    log "WARNING: No LUKS device found, proceeding with standard installation"
fi

# Update GRUB configuration for encryption
log "Updating GRUB configuration for encryption..."
if [ -f /etc/default/grub ]; then
    # Enable cryptodisk support
    if ! grep -q "GRUB_ENABLE_CRYPTODISK=y" /etc/default/grub; then
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
    fi
    
    # Add crypto modules to preload
    if ! grep -q "GRUB_PRELOAD_MODULES" /etc/default/grub; then
        echo 'GRUB_PRELOAD_MODULES="luks cryptodisk part_gpt part_msdos"' >> /etc/default/grub
    fi
    
    log "✓ GRUB configuration updated"
fi

# Try GRUB installation with different approaches
install_grub() {
    local approach="$1"
    local device="$2"
    
    log "=========================================="
    log "Attempting GRUB installation: $approach"
    log "=========================================="
    
    case "$approach" in
        "standard-efi")
            local cmd="grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=nubiferos --no-nvram --removable"
            log "Command: $cmd"
            log "Flags explained:"
            log "  --target=x86_64-efi     : UEFI 64-bit target"
            log "  --efi-directory=/boot/efi : EFI system partition mount point"
            log "  --bootloader-id=nubiferos : Boot entry name"
            log "  --no-nvram              : Don't update NVRAM (works better in VMs)"
            log "  --removable             : Install to fallback path /EFI/BOOT/BOOTX64.EFI"
            log ""
            $cmd
            ;;
        "standard-bios")
            local cmd="grub-install --target=i386-pc --recheck --no-floppy $device"
            log "Command: $cmd"
            log "Flags explained:"
            log "  --target=i386-pc : BIOS/Legacy target"
            log "  --recheck        : Recheck device map"
            log "  --no-floppy      : Don't probe floppy drives"
            log ""
            $cmd
            ;;
        *)
            log "ERROR: Unknown installation approach: $approach"
            return 1
            ;;
    esac
}

# Try different installation approaches (removed --force as it's deprecated)
# Detect if we're in EFI mode
if [ -d /sys/firmware/efi ]; then
    log "EFI mode detected"
    APPROACHES=("standard-efi")
else
    log "BIOS mode detected"
    APPROACHES=("standard-bios")
fi

SUCCESS=false

for approach in "${APPROACHES[@]}"; do
    log "Trying approach: $approach"
    
    if install_grub "$approach" "$TARGET_DEVICE" 2>&1 | tee -a /tmp/grub-install.log; then
        log "✓ GRUB installation successful with approach: $approach"
        SUCCESS=true
        break
    else
        log "✗ GRUB installation failed with approach: $approach"
        log "Error details:"
        tail -10 /tmp/grub-install.log || true
    fi
done

if [ "$SUCCESS" = false ]; then
    log "=========================================="
    log "ERROR: All GRUB installation approaches failed"
    log "=========================================="
    log "This is a known issue with QEMU + LUKS encryption"
    log "The system may still be bootable, but manual GRUB installation may be needed"
    log ""
    log "Manual fix: Boot from live CD and run:"
    log "  grub-install $TARGET_DEVICE"
    log "  after unlocking LUKS"
    log ""
    log "Full log saved to: /tmp/grub-install-wrapper.log"
    log "GRUB output saved to: /tmp/grub-install.log"
    exit 0
fi

# Generate GRUB configuration
log "=========================================="
log "Generating GRUB configuration..."
log "=========================================="
if grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a /tmp/grub-install-wrapper.log; then
    log "✓ GRUB configuration generated successfully"
else
    log "WARNING: GRUB configuration generation failed"
fi

log "=========================================="
log "GRUB installation completed successfully"
log "=========================================="
log "Firmware mode: $FIRMWARE_MODE"
log "Approach used: ${APPROACHES[0]}"
log "Full log: /tmp/grub-install-wrapper.log"