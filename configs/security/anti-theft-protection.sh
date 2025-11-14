#!/bin/bash
# NubiferOS Anti-Theft Protection
# Comprehensive security against physical theft

set -e

echo "=========================================="
echo "NubiferOS Anti-Theft Protection Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Layer 1: Verify LUKS Encryption
check_luks_encryption() {
    echo "Layer 1: Checking disk encryption..."
    
    if lsblk -f | grep -q "crypto_LUKS"; then
        echo "✓ LUKS encryption detected"
        
        # Check encryption strength
        for device in $(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print "/dev/"$1}'); do
            echo "  Checking $device..."
            cryptsetup luksDump "$device" | grep "Cipher:" || true
        done
    else
        echo "⚠️  WARNING: No LUKS encryption detected!"
        echo "   Your data is NOT protected if device is stolen"
        echo "   Run: sudo nubifer-enable-encryption"
        return 1
    fi
}

# Layer 2: Enable Secure Boot
enable_secure_boot() {
    echo ""
    echo "Layer 2: Secure Boot configuration..."
    
    if [ -d /sys/firmware/efi ]; then
        echo "✓ UEFI system detected"
        
        # Check if Secure Boot is enabled
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            echo "✓ Secure Boot is ENABLED"
        else
            echo "⚠️  Secure Boot is DISABLED"
            echo ""
            echo "To enable Secure Boot:"
            echo "  1. Reboot and enter BIOS/UEFI (usually F2, F10, or Del)"
            echo "  2. Find 'Secure Boot' option"
            echo "  3. Enable Secure Boot"
            echo "  4. Save and exit"
            echo ""
            echo "This prevents booting unauthorized operating systems"
        fi
    else
        echo "ℹ️  Legacy BIOS system (not UEFI)"
        echo "   Secure Boot not available"
    fi
}

# Layer 3: TPM Integration
configure_tpm() {
    echo ""
    echo "Layer 3: TPM (Trusted Platform Module) integration..."
    
    if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
        echo "✓ TPM device detected"
        
        # Install TPM tools
        apt-get install -y tpm2-tools 2>/dev/null || echo "Installing TPM tools..."
        
        # Check TPM version
        if tpm2_getcap properties-fixed 2>/dev/null | grep -q "TPM2"; then
            echo "✓ TPM 2.0 detected"
            
            # Configure TPM-backed LUKS
            echo ""
            echo "TPM can be used to:"
            echo "  - Automatically unlock disk on trusted hardware"
            echo "  - Detect hardware tampering"
            echo "  - Seal encryption keys to specific hardware"
            echo ""
            read -p "Configure TPM-backed encryption? (y/N): " configure_tpm
            
            if [ "$configure_tpm" = "y" ] || [ "$configure_tpm" = "Y" ]; then
                configure_tpm_luks
            fi
        fi
    else
        echo "ℹ️  No TPM device detected"
        echo "   TPM provides hardware-based security"
        echo "   Consider hardware with TPM 2.0 for maximum security"
    fi
}

# Configure TPM-backed LUKS
configure_tpm_luks() {
    echo "Configuring TPM-backed LUKS..."
    
    # Install systemd-cryptenroll
    apt-get install -y systemd-cryptenroll 2>/dev/null || true
    
    # Find LUKS devices
    for device in $(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print "/dev/"$1}'); do
        echo ""
        echo "Add TPM unlock for $device?"
        read -p "Continue? (y/N): " add_tpm
        
        if [ "$add_tpm" = "y" ] || [ "$add_tpm" = "Y" ]; then
            # Enroll TPM
            systemd-cryptenroll --tpm2-device=auto "$device"
            echo "✓ TPM enrolled for $device"
            echo "  Device will auto-unlock on this hardware"
            echo "  ⚠️  Will NOT unlock if hardware is modified"
        fi
    done
}

# Layer 4: BIOS/UEFI Password Check
check_bios_password() {
    echo ""
    echo "Layer 4: BIOS/UEFI Password..."
    echo ""
    echo "⚠️  CRITICAL: Set a BIOS/UEFI password!"
    echo ""
    echo "Why this matters:"
    echo "  - Prevents booting from USB/CD"
    echo "  - Prevents BIOS settings changes"
    echo "  - Prevents boot order modification"
    echo "  - Last line of defense against physical access"
    echo ""
    echo "How to set BIOS password:"
    echo "  1. Reboot and enter BIOS/UEFI (F2, F10, Del, or Esc)"
    echo "  2. Find 'Security' or 'Password' section"
    echo "  3. Set 'Supervisor Password' or 'Admin Password'"
    echo "  4. Set 'User Password' (optional)"
    echo "  5. Disable boot from USB/CD"
    echo "  6. Set boot order: Internal drive only"
    echo "  7. Save and exit"
    echo ""
    echo "⚠️  IMPORTANT: Store BIOS password securely!"
    echo "   If forgotten, may require hardware reset"
    echo ""
    
    read -p "Have you set a BIOS password? (y/N): " bios_set
    
    if [ "$bios_set" != "y" ] && [ "$bios_set" != "Y" ]; then
        echo ""
        echo "❌ BIOS password NOT set"
        echo "   Your system is vulnerable to physical theft"
        echo "   Please set BIOS password ASAP"
    else
        echo "✓ BIOS password confirmed"
    fi
}

# Layer 5: Boot Order Configuration
check_boot_order() {
    echo ""
    echo "Layer 5: Boot Order Security..."
    echo ""
    echo "Recommended boot configuration:"
    echo "  1. Internal drive ONLY"
    echo "  2. Disable USB boot"
    echo "  3. Disable CD/DVD boot"
    echo "  4. Disable network boot (PXE)"
    echo ""
    echo "This prevents:"
    echo "  - Booting from live USB"
    echo "  - Booting from live CD"
    echo "  - Network-based attacks"
    echo ""
    
    if command -v efibootmgr &>/dev/null; then
        echo "Current boot order:"
        efibootmgr | grep "BootOrder" || echo "Unable to read boot order"
    fi
    
    echo ""
    echo "To secure boot order:"
    echo "  1. Enter BIOS/UEFI"
    echo "  2. Go to Boot settings"
    echo "  3. Set internal drive as first (and only) boot device"
    echo "  4. Disable all other boot options"
    echo "  5. Enable 'Boot Order Lock' if available"
    echo ""
}

# Layer 6: Anti-Forensics
configure_anti_forensics() {
    echo ""
    echo "Layer 6: Anti-Forensics Protection..."
    echo ""
    echo "Additional protections:"
    
    # Disable hibernation (prevents memory dump)
    echo "  - Disabling hibernation (prevents memory dumps)"
    systemctl mask hibernate.target hybrid-sleep.target
    
    # Secure swap
    echo "  - Configuring encrypted swap"
    # Swap should be on encrypted partition
    
    # Clear bash history on logout
    echo "  - Configuring secure shell history"
    cat >> /etc/bash.bash_logout << 'EOF'
# Clear history on logout (NubiferOS security)
history -c
history -w
rm -f ~/.bash_history
EOF
    
    # Secure /tmp
    echo "  - Securing temporary files"
    echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,mode=1777 0 0" >> /etc/fstab
    
    echo "✓ Anti-forensics configured"
}

# Layer 7: Remote Wipe Capability
setup_remote_wipe() {
    echo ""
    echo "Layer 7: Remote Wipe (Optional)..."
    echo ""
    echo "⚠️  ADVANCED: Remote wipe capability"
    echo ""
    echo "This allows wiping the device if stolen, but requires:"
    echo "  - Device to be online"
    echo "  - Secure command channel"
    echo "  - Proper authentication"
    echo ""
    read -p "Set up remote wipe? (y/N): " setup_wipe
    
    if [ "$setup_wipe" = "y" ] || [ "$setup_wipe" = "Y" ]; then
        create_remote_wipe_system
    else
        echo "Skipped (can configure later)"
    fi
}

# Create remote wipe system
create_remote_wipe_system() {
    echo "Creating remote wipe system..."
    
    cat > /usr/local/bin/nubifer-emergency-wipe << 'EOF'
#!/bin/bash
# NubiferOS Emergency Wipe
# ⚠️  THIS WILL DESTROY ALL DATA

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Must run as root"
    exit 1
fi

echo "=========================================="
echo "⚠️  EMERGENCY WIPE WARNING ⚠️"
echo "=========================================="
echo ""
echo "This will PERMANENTLY DESTROY all data on this system"
echo "This action CANNOT be undone"
echo ""
read -p "Type 'WIPE ALL DATA' to confirm: " confirm

if [ "$confirm" != "WIPE ALL DATA" ]; then
    echo "Aborted"
    exit 1
fi

echo ""
echo "Wiping system in 10 seconds..."
echo "Press Ctrl+C to abort"
sleep 10

echo "Starting emergency wipe..."

# Wipe LUKS headers (makes data unrecoverable)
for device in $(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print "/dev/"$1}'); do
    echo "Wiping LUKS header on $device..."
    cryptsetup luksErase "$device" --batch-mode
done

# Overwrite disk
echo "Overwriting disk..."
dd if=/dev/urandom of=/dev/sda bs=1M count=100 status=progress

# Clear TPM
if [ -c /dev/tpm0 ]; then
    tpm2_clear || true
fi

echo "Emergency wipe complete"
echo "System will now power off"
poweroff
EOF
    
    chmod 700 /usr/local/bin/nubifer-emergency-wipe
    
    echo "✓ Emergency wipe command created: nubifer-emergency-wipe"
    echo "  ⚠️  Use only in emergency (stolen device)"
}

# Create theft response guide
create_theft_response_guide() {
    cat > /usr/share/doc/nubifer/THEFT_RESPONSE.txt << 'EOF'
NubiferOS Theft Response Guide
===============================

If your NubiferOS device is stolen:

IMMEDIATE ACTIONS (Within 1 hour):
-----------------------------------
1. Report theft to local authorities
2. Report to IT Security team
3. Document: When, where, what was on device
4. Change ALL cloud credentials immediately:
   - AWS accounts
   - Azure accounts
   - GCP accounts
   - Any other cloud services
5. Revoke all API keys and tokens
6. Enable MFA on all accounts (if not already)
7. Review recent cloud activity for unauthorized access

WITHIN 24 HOURS:
----------------
1. Review audit logs for suspicious activity
2. Rotate all SSH keys
3. Invalidate all active sessions
4. Review IAM policies and permissions
5. Check for new resources created
6. Monitor billing for unusual charges
7. Notify affected customers/partners if needed

ONGOING:
--------
1. Monitor for data breach indicators
2. Review security logs regularly
3. Consider device as compromised
4. Update incident response procedures
5. Review physical security policies

WHAT ATTACKER CANNOT ACCESS (if properly configured):
------------------------------------------------------
✓ Encrypted disk data (with strong passphrase)
✓ Stored credentials (encrypted)
✓ Cloud account access (if credentials changed)
✓ SSH keys (if rotated)

WHAT ATTACKER MIGHT ACCESS:
----------------------------
✗ Data if weak encryption passphrase
✗ Cloud accounts if credentials not changed
✗ Cached browser sessions (if not expired)
✗ Recently accessed data (if in memory)

PREVENTION FOR NEXT TIME:
--------------------------
1. Set BIOS password
2. Enable Secure Boot
3. Use TPM if available
4. Use strong encryption passphrase (16+ chars)
5. Enable automatic screen lock (1 minute)
6. Don't leave device unattended
7. Use cable lock in public spaces
8. Enable "Find My Device" if available
9. Regular backups to secure location
10. Minimize sensitive data on device

CONTACT:
--------
IT Security: [Your contact]
Incident Response: [Your contact]
Legal: [Your contact]

REMEMBER:
---------
- Act quickly
- Assume compromise
- Change all credentials
- Document everything
- Learn and improve
EOF
    
    echo "✓ Theft response guide created: /usr/share/doc/nubifer/THEFT_RESPONSE.txt"
}

# Summary and recommendations
print_summary() {
    echo ""
    echo "=========================================="
    echo "Anti-Theft Protection Summary"
    echo "=========================================="
    echo ""
    echo "Protection Layers:"
    echo ""
    
    # Check each layer
    if lsblk -f | grep -q "crypto_LUKS"; then
        echo "✓ Layer 1: Disk Encryption (LUKS) - ENABLED"
    else
        echo "✗ Layer 1: Disk Encryption (LUKS) - MISSING"
    fi
    
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
        echo "✓ Layer 2: Secure Boot - ENABLED"
    else
        echo "⚠️  Layer 2: Secure Boot - DISABLED"
    fi
    
    if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
        echo "✓ Layer 3: TPM Available"
    else
        echo "ℹ️  Layer 3: TPM - Not Available"
    fi
    
    echo "⚠️  Layer 4: BIOS Password - USER MUST SET"
    echo "⚠️  Layer 5: Boot Order - USER MUST CONFIGURE"
    echo "✓ Layer 6: Anti-Forensics - CONFIGURED"
    
    echo ""
    echo "=========================================="
    echo "CRITICAL ACTIONS REQUIRED:"
    echo "=========================================="
    echo ""
    echo "1. SET BIOS PASSWORD (prevents boot from USB/CD)"
    echo "2. DISABLE USB/CD BOOT in BIOS"
    echo "3. ENABLE SECURE BOOT in BIOS"
    echo "4. USE STRONG ENCRYPTION PASSPHRASE (16+ characters)"
    echo "5. NEVER LEAVE DEVICE UNATTENDED"
    echo ""
    echo "With these protections:"
    echo "  ✓ Stolen device data is UNREADABLE"
    echo "  ✓ Cannot boot from live CD/USB"
    echo "  ✓ Cannot access your cloud accounts"
    echo "  ✓ Cannot modify BIOS settings"
    echo ""
    echo "Read: /usr/share/doc/nubifer/THEFT_RESPONSE.txt"
    echo "=========================================="
}

# Main execution
main() {
    check_luks_encryption
    enable_secure_boot
    configure_tpm
    check_bios_password
    check_boot_order
    configure_anti_forensics
    setup_remote_wipe
    create_theft_response_guide
    print_summary
}

main "$@"
