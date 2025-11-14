#!/bin/bash
# NubiferOS Security Monitor
# Runs at boot and periodically to check security status
# Warns user if critical security features are disabled

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Security status file
SECURITY_STATUS="/var/lib/nubifer/security-status"
mkdir -p "$(dirname "$SECURITY_STATUS")"

# Check Secure Boot status
check_secure_boot() {
    local status="UNKNOWN"
    local warning=""
    
    if [ -d /sys/firmware/efi ]; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            status="ENABLED"
        else
            status="DISABLED"
            warning="⚠️  SECURITY RISK: Secure Boot is disabled"
        fi
    else
        status="NOT_AVAILABLE"
        warning="ℹ️  Legacy BIOS - Secure Boot not available"
    fi
    
    echo "SECURE_BOOT=$status" >> "$SECURITY_STATUS"
    echo "$warning"
}

# Check TPM status
check_tpm() {
    local status="UNKNOWN"
    local warning=""
    
    if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
        if tpm2_getcap properties-fixed 2>/dev/null | grep -q "TPM2"; then
            status="ENABLED"
        else
            status="DETECTED_NOT_CONFIGURED"
            warning="⚠️  TPM detected but not configured"
        fi
    else
        status="NOT_AVAILABLE"
        warning="⚠️  No TPM detected - hardware security unavailable"
    fi
    
    echo "TPM=$status" >> "$SECURITY_STATUS"
    echo "$warning"
}

# Check LUKS encryption
check_luks() {
    local status="UNKNOWN"
    local warning=""
    
    if lsblk -f | grep -q "crypto_LUKS"; then
        status="ENABLED"
    else
        status="DISABLED"
        warning="❌ CRITICAL: Disk encryption is DISABLED!"
    fi
    
    echo "LUKS=$status" >> "$SECURITY_STATUS"
    echo "$warning"
}

# Check BIOS password (indirect detection)
check_bios_password() {
    local status="UNKNOWN"
    local warning=""
    
    # We can't directly check if BIOS password is set
    # But we can check if USB boot is disabled (indicator)
    
    # Check if we've been warned before
    if [ -f /var/lib/nubifer/bios-password-confirmed ]; then
        status="CONFIRMED"
    else
        status="NOT_CONFIRMED"
        warning="⚠️  CRITICAL: BIOS password not confirmed"
    fi
    
    echo "BIOS_PASSWORD=$status" >> "$SECURITY_STATUS"
    echo "$warning"
}

# Check boot order security
check_boot_order() {
    local status="UNKNOWN"
    local warning=""
    
    if command -v efibootmgr &>/dev/null; then
        # Check if USB/CD boot is in boot order
        if efibootmgr 2>/dev/null | grep -i "usb\|cd\|dvd" | grep -q "Boot"; then
            status="INSECURE"
            warning="⚠️  USB/CD boot is enabled in boot order"
        else
            status="SECURE"
        fi
    else
        status="UNKNOWN"
    fi
    
    echo "BOOT_ORDER=$status" >> "$SECURITY_STATUS"
    echo "$warning"
}

# Generate security report
generate_report() {
    local critical_issues=0
    local warnings=0
    
    # Clear previous status
    > "$SECURITY_STATUS"
    
    echo "=========================================="
    echo "NubiferOS Security Status"
    echo "=========================================="
    echo ""
    
    # Check all security features
    local sb_warn=$(check_secure_boot)
    local tpm_warn=$(check_tpm)
    local luks_warn=$(check_luks)
    local bios_warn=$(check_bios_password)
    local boot_warn=$(check_boot_order)
    
    # Count issues
    [ -n "$sb_warn" ] && [ "$sb_warn" != *"ℹ️"* ] && ((warnings++))
    [ -n "$tpm_warn" ] && ((warnings++))
    [ -n "$luks_warn" ] && ((critical_issues++))
    [ -n "$bios_warn" ] && ((critical_issues++))
    [ -n "$boot_warn" ] && ((warnings++))
    
    # Print warnings
    [ -n "$sb_warn" ] && echo "$sb_warn"
    [ -n "$tpm_warn" ] && echo "$tpm_warn"
    [ -n "$luks_warn" ] && echo "$luks_warn"
    [ -n "$bios_warn" ] && echo "$bios_warn"
    [ -n "$boot_warn" ] && echo "$boot_warn"
    
    echo ""
    echo "Critical Issues: $critical_issues"
    echo "Warnings: $warnings"
    echo ""
    
    # Save counts
    echo "CRITICAL_ISSUES=$critical_issues" >> "$SECURITY_STATUS"
    echo "WARNINGS=$warnings" >> "$SECURITY_STATUS"
    echo "LAST_CHECK=$(date +%s)" >> "$SECURITY_STATUS"
    
    return $critical_issues
}

# Show GUI warning if issues found
show_gui_warning() {
    local critical=$1
    local warnings=$2
    
    if [ $critical -gt 0 ] || [ $warnings -gt 0 ]; then
        # Create desktop notification
        if command -v notify-send &>/dev/null; then
            if [ $critical -gt 0 ]; then
                notify-send -u critical \
                    "⚠️  NubiferOS Security Alert" \
                    "Critical security issues detected. Click to view details." \
                    -i security-low \
                    -t 0
            else
                notify-send -u normal \
                    "⚠️  NubiferOS Security Warning" \
                    "$warnings security warnings detected. Click to view details." \
                    -i security-medium \
                    -t 10000
            fi
        fi
        
        # Create warning file for desktop indicator
        echo "SHOW_WARNING=true" > /var/lib/nubifer/security-warning
        echo "CRITICAL=$critical" >> /var/lib/nubifer/security-warning
        echo "WARNINGS=$warnings" >> /var/lib/nubifer/security-warning
    else
        # Clear warning
        rm -f /var/lib/nubifer/security-warning
    fi
}

# Main execution
main() {
    # Generate report
    generate_report
    local exit_code=$?
    
    # Get counts
    local critical=$(grep "CRITICAL_ISSUES=" "$SECURITY_STATUS" | cut -d= -f2)
    local warnings=$(grep "WARNINGS=" "$SECURITY_STATUS" | cut -d= -f2)
    
    # Show GUI warning if running in user session
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        show_gui_warning "$critical" "$warnings"
    fi
    
    # If critical issues, show detailed help
    if [ $exit_code -gt 0 ]; then
        echo "=========================================="
        echo "ACTION REQUIRED"
        echo "=========================================="
        echo ""
        echo "To fix critical security issues:"
        echo "  1. Run: sudo nubifer-security-setup"
        echo "  2. Follow the prompts"
        echo "  3. Reboot if required"
        echo ""
        echo "For BIOS password setup:"
        echo "  1. Reboot and enter BIOS (F2/F10/Del)"
        echo "  2. Set Supervisor/Admin password"
        echo "  3. Disable USB/CD boot"
        echo "  4. Enable Secure Boot"
        echo "  5. Save and exit"
        echo "  6. Run: sudo nubifer-confirm-bios-security"
        echo ""
    fi
    
    return $exit_code
}

main "$@"
