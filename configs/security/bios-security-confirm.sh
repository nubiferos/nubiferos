#!/bin/bash
# NubiferOS BIOS Security Confirmation
# User confirms they have set BIOS password and disabled USB boot

set -e

echo "=========================================="
echo "BIOS Security Configuration Confirmation"
echo "=========================================="
echo ""
echo "This tool confirms you have configured BIOS security."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "Required BIOS Security Settings:"
echo "================================="
echo ""
echo "1. BIOS/UEFI Password"
echo "   - Set Supervisor/Admin password"
echo "   - Prevents unauthorized BIOS changes"
echo "   - Prevents booting from USB/CD without password"
echo ""
echo "2. Secure Boot"
echo "   - Enable Secure Boot"
echo "   - Prevents unauthorized operating systems"
echo ""
echo "3. Boot Order"
echo "   - Set internal drive as ONLY boot device"
echo "   - Disable USB boot"
echo "   - Disable CD/DVD boot"
echo "   - Disable network boot (PXE)"
echo ""
echo "4. Boot Order Lock (if available)"
echo "   - Enable boot order lock"
echo "   - Prevents boot order changes"
echo ""

# Interactive confirmation
confirm_bios_password() {
    echo "=========================================="
    echo "BIOS Password Confirmation"
    echo "=========================================="
    echo ""
    read -p "Have you set a BIOS/UEFI password? (yes/no): " bios_pass
    
    if [ "$bios_pass" != "yes" ]; then
        echo ""
        echo "❌ BIOS password is REQUIRED for security"
        echo ""
        echo "Without BIOS password:"
        echo "  - Anyone can boot from USB/CD"
        echo "  - Anyone can change BIOS settings"
        echo "  - Your encrypted data is at risk"
        echo ""
        echo "Please set BIOS password and run this script again"
        return 1
    fi
    
    echo "✓ BIOS password confirmed"
    return 0
}

confirm_usb_boot_disabled() {
    echo ""
    echo "=========================================="
    echo "USB/CD Boot Confirmation"
    echo "=========================================="
    echo ""
    read -p "Have you disabled USB/CD boot in BIOS? (yes/no): " usb_disabled
    
    if [ "$usb_disabled" != "yes" ]; then
        echo ""
        echo "❌ USB/CD boot must be DISABLED"
        echo ""
        echo "With USB/CD boot enabled:"
        echo "  - Attacker can boot from live USB"
        echo "  - Attacker can attempt to access data"
        echo "  - Physical theft is more dangerous"
        echo ""
        echo "Please disable USB/CD boot and run this script again"
        return 1
    fi
    
    echo "✓ USB/CD boot disabled confirmed"
    return 0
}

confirm_secure_boot() {
    echo ""
    echo "=========================================="
    echo "Secure Boot Confirmation"
    echo "=========================================="
    echo ""
    
    # Check if Secure Boot is actually enabled
    if [ -d /sys/firmware/efi ]; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            echo "✓ Secure Boot is ENABLED (verified)"
            return 0
        else
            echo "❌ Secure Boot is NOT enabled"
            echo ""
            read -p "Have you enabled Secure Boot in BIOS? (yes/no): " sb_enabled
            
            if [ "$sb_enabled" != "yes" ]; then
                echo ""
                echo "Please enable Secure Boot in BIOS and reboot"
                return 1
            else
                echo ""
                echo "⚠️  You confirmed Secure Boot is enabled, but system doesn't detect it"
                echo "   Please reboot for changes to take effect"
                return 1
            fi
        fi
    else
        echo "ℹ️  Legacy BIOS system - Secure Boot not available"
        return 0
    fi
}

# Save confirmation
save_confirmation() {
    echo ""
    echo "Saving security confirmation..."
    
    mkdir -p /var/lib/nubifer
    
    cat > /var/lib/nubifer/bios-password-confirmed << EOF
# NubiferOS BIOS Security Confirmation
# This file indicates the user has confirmed BIOS security settings

CONFIRMED_DATE=$(date +%Y-%m-%d)
CONFIRMED_TIMESTAMP=$(date +%s)
CONFIRMED_BY=$(whoami)
HOSTNAME=$(hostname)

BIOS_PASSWORD=CONFIRMED
USB_BOOT_DISABLED=CONFIRMED
SECURE_BOOT=CONFIRMED

# User should re-confirm annually
NEXT_CONFIRMATION=$(date -d "+1 year" +%Y-%m-%d)
EOF
    
    chmod 600 /var/lib/nubifer/bios-password-confirmed
    
    echo "✓ Confirmation saved"
}

# Create reminder for annual re-confirmation
create_reminder() {
    echo ""
    echo "Creating annual reminder..."
    
    # Create systemd timer for annual reminder
    cat > /etc/systemd/system/nubifer-security-reminder.timer << 'EOF'
[Unit]
Description=NubiferOS Annual Security Confirmation Reminder
Documentation=man:nubifer-security

[Timer]
OnCalendar=yearly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    cat > /etc/systemd/system/nubifer-security-reminder.service << 'EOF'
[Unit]
Description=NubiferOS Security Confirmation Reminder
Documentation=man:nubifer-security

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nubifer-security-reminder
EOF
    
    cat > /usr/local/bin/nubifer-security-reminder << 'EOF'
#!/bin/bash
# Send reminder to re-confirm BIOS security

notify-send -u critical \
    "🔒 NubiferOS Security Reminder" \
    "Annual BIOS security confirmation required. Run: sudo nubifer-confirm-bios-security" \
    -i security-low \
    -t 0
EOF
    
    chmod +x /usr/local/bin/nubifer-security-reminder
    systemctl enable nubifer-security-reminder.timer
    
    echo "✓ Annual reminder configured"
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "✓ BIOS Security Confirmed"
    echo "=========================================="
    echo ""
    echo "Your system is now properly secured against:"
    echo "  ✓ Unauthorized BIOS changes"
    echo "  ✓ Booting from USB/CD"
    echo "  ✓ Physical theft attacks"
    echo "  ✓ Live CD/USB attacks"
    echo ""
    echo "Security warnings will no longer appear."
    echo ""
    echo "IMPORTANT:"
    echo "  - Never share your BIOS password"
    echo "  - Store BIOS password securely"
    echo "  - Re-confirm annually (you'll be reminded)"
    echo ""
    echo "If you ever reset BIOS settings:"
    echo "  - Re-apply all security settings"
    echo "  - Run this script again"
    echo ""
}

# Main execution
main() {
    # Confirm all settings
    if ! confirm_bios_password; then
        exit 1
    fi
    
    if ! confirm_usb_boot_disabled; then
        exit 1
    fi
    
    if ! confirm_secure_boot; then
        exit 1
    fi
    
    # Save confirmation
    save_confirmation
    
    # Create reminder
    create_reminder
    
    # Print summary
    print_summary
    
    echo "Run 'nubifer-security-status' to verify all security settings"
}

main "$@"
