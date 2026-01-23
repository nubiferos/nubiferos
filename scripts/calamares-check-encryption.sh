#!/bin/bash
# Check if encryption is enabled and warn user if not
# Runs at the very beginning of exec phase, before any changes are made

echo "=========================================="
echo "Checking Encryption Status"
echo "=========================================="

# Check if LUKS encryption is being used
# We can detect this by looking for LUKS devices being set up
# or by checking Calamares temp files

ENCRYPTION_ENABLED=false

# Method 1: Check if any LUKS passphrase was configured
# Calamares stores this in memory, but we can check for LUKS setup markers
if [ -f /tmp/calamares-luks-setup ] || [ -f /tmp/.calamares-luks ]; then
    ENCRYPTION_ENABLED=true
fi

# Method 2: Check for existing LUKS devices (in case of manual partitioning)
for device in /dev/sd*[0-9] /dev/nvme*p[0-9] /dev/vd*[0-9]; do
    if [ -b "$device" ] && cryptsetup isLuks "$device" 2>/dev/null; then
        ENCRYPTION_ENABLED=true
        echo "Found existing LUKS device: $device"
        break
    fi
done

# Method 3: Check Calamares job queue for LUKS operations
# This is a heuristic - if partition module will create LUKS, there should be markers
if grep -q "luks" /tmp/calamares* 2>/dev/null; then
    ENCRYPTION_ENABLED=true
fi

# If we can't definitively detect encryption status at this point,
# we'll check again after partition module runs and warn then
# For now, create a marker file to track our check
echo "encryption_check_done=true" > /tmp/nubiferos-encryption-check

if [ "$ENCRYPTION_ENABLED" = "true" ]; then
    echo "Encryption appears to be enabled - proceeding"
    exit 0
fi

# Show warning dialog
echo "WARNING: Encryption does not appear to be enabled!"

if command -v zenity &> /dev/null; then
    zenity --warning --width=550 --height=350 \
        --title="NubiferOS - Encryption Warning" \
        --text="<b><span foreground='#C62828' font='16'>Disk Encryption is NOT Enabled!</span></b>\n\n<b>NubiferOS strongly recommends full disk encryption</b> to protect your data from:\n\n  • Theft or loss of your device\n  • Unauthorized physical access\n  • Data recovery from disposed drives\n\n<b>Without encryption, anyone with physical access to your computer can read all your files.</b>\n\nTo enable encryption:\n  1. Click <b>Cancel Installation</b> below\n  2. Go back to the Partitioning step\n  3. Check the <b>\"Encrypt system\"</b> checkbox\n  4. Enter a strong passphrase\n\n<span foreground='#666666'>If you understand the risks and want to proceed without encryption, click Continue.</span>" \
        --ok-label="Continue WITHOUT Encryption" \
        --extra-button="Cancel Installation" 2>/dev/null

    RESULT=$?

    # zenity returns 0 for OK, 1 for extra button, 5 for timeout/close
    if [ $RESULT -eq 1 ]; then
        echo "User chose to cancel installation"
        # Create marker so Calamares knows to abort
        echo "USER_CANCELLED=true" > /tmp/nubiferos-install-cancelled
        exit 1  # Non-zero exit will stop the installation
    fi

    echo "User chose to continue without encryption"

elif command -v kdialog &> /dev/null; then
    kdialog --title "NubiferOS - Encryption Warning" \
        --warningyesno "DISK ENCRYPTION IS NOT ENABLED!\n\nNubiferOS strongly recommends full disk encryption to protect your data.\n\nWithout encryption, anyone with physical access can read your files.\n\nDo you want to continue WITHOUT encryption?" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "User chose to cancel installation"
        exit 1
    fi
fi

# User chose to continue - mark that they acknowledged
echo "encryption_warning_acknowledged=true" >> /tmp/nubiferos-encryption-check
echo "Proceeding without encryption (user acknowledged warning)"

exit 0
