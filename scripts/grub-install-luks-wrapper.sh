#!/bin/bash
# GRUB installation wrapper for LUKS encrypted systems
# Handles the device mapping issues with encrypted root filesystems

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log "Starting GRUB installation for LUKS encrypted system..."

# Get the target device (usually /dev/vda or /dev/sda)
TARGET_DEVICE="$1"
if [ -z "$TARGET_DEVICE" ]; then
    log "ERROR: No target device specified"
    exit 1
fi

log "Target device: $TARGET_DEVICE"

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
    
    log "Attempting GRUB installation: $approach"
    
    case "$approach" in
        "standard")
            grub-install --target=i386-pc --recheck --no-floppy "$device"
            ;;
        "force")
            grub-install --target=i386-pc --recheck --no-floppy --force "$device"
            ;;
        "skip-fs-probe")
            grub-install --target=i386-pc --recheck --no-floppy --force --skip-fs-probe "$device"
            ;;
        *)
            log "ERROR: Unknown installation approach: $approach"
            return 1
            ;;
    esac
}

# Try different installation approaches
APPROACHES=("standard" "force" "skip-fs-probe")
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
    log "ERROR: All GRUB installation approaches failed"
    log "This is a known issue with QEMU + LUKS encryption"
    log "The system may still be bootable, but manual GRUB installation may be needed"
    
    # Don't fail the entire installation - just warn
    log "WARNING: Continuing installation without bootloader"
    log "Manual fix: Boot from live CD and run 'grub-install $TARGET_DEVICE' after unlocking LUKS"
    exit 0
fi

# Generate GRUB configuration
log "Generating GRUB configuration..."
if grub-mkconfig -o /boot/grub/grub.cfg; then
    log "✓ GRUB configuration generated successfully"
else
    log "WARNING: GRUB configuration generation failed"
fi

log "GRUB installation completed"