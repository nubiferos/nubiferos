#!/bin/bash
# Log which Calamares configuration files are being used
# This helps debug which bootloader config is active

LOG_FILE="/tmp/calamares-config-info.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Calamares Configuration Info"
log "=========================================="
log ""

# Check which bootloader configs exist
log "Bootloader configuration files:"
for conf in /etc/calamares/modules/bootloader*.conf; do
    if [ -f "$conf" ]; then
        log "  Found: $conf"
        log "    Size: $(stat -c%s "$conf") bytes"
        log "    Modified: $(stat -c%y "$conf")"
        
        # Check for key indicators
        if grep -q "grubInstall.*wrapper" "$conf" 2>/dev/null; then
            log "    Uses wrapper: YES"
            wrapper=$(grep "grubInstall:" "$conf" | awk '{print $2}' | tr -d '"')
            log "    Wrapper path: $wrapper"
        else
            log "    Uses wrapper: NO"
        fi
        
        if grep -q "\-\-force" "$conf" 2>/dev/null; then
            log "    Contains --force: YES (WARNING!)"
        else
            log "    Contains --force: NO (good)"
        fi
        
        if grep -q "\-\-no-nvram" "$conf" 2>/dev/null; then
            log "    Contains --no-nvram: YES (UEFI optimized)"
        fi
        
        log ""
    fi
done

# Check which config is active in settings
log "Active configuration from settings.conf:"
if [ -f /etc/calamares/settings.conf ]; then
    grep -A 2 "bootloader" /etc/calamares/settings.conf | while read line; do
        log "  $line"
    done
else
    log "  ERROR: settings.conf not found"
fi
log ""

# Check if wrapper scripts exist
log "Wrapper scripts:"
for wrapper in /usr/local/bin/grub-install*wrapper* /usr/bin/grub-install*wrapper*; do
    if [ -f "$wrapper" ]; then
        log "  Found: $wrapper"
        log "    Size: $(stat -c%s "$wrapper") bytes"
        log "    Executable: $(test -x "$wrapper" && echo YES || echo NO)"
        if grep -q "\-\-force" "$wrapper" 2>/dev/null; then
            log "    Contains --force: YES (WARNING!)"
        else
            log "    Contains --force: NO (good)"
        fi
        log ""
    fi
done

# Check firmware mode
log "Firmware mode:"
if [ -d /sys/firmware/efi ]; then
    log "  UEFI (EFI directory exists)"
else
    log "  BIOS (no EFI directory)"
fi
log ""

log "=========================================="
log "Configuration info saved to: $LOG_FILE"
log "=========================================="
