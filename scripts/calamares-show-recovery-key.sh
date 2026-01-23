#!/bin/bash
# Display recovery key to user during installation
# This runs at the end of exec phase, before the "finished" screen

echo "=========================================="
echo "Displaying Recovery Key to User"
echo "=========================================="

RECOVERY_KEY_FILE="/tmp/nubiferos-install/recovery-key.txt"

# Check if recovery key was generated (only if LUKS is enabled)
if [ ! -f "$RECOVERY_KEY_FILE" ]; then
    echo "No recovery key found - encryption may not be enabled"
    exit 0
fi

RECOVERY_KEY=$(cat "$RECOVERY_KEY_FILE")

echo "Recovery key: $RECOVERY_KEY"

# Try to display using zenity (GNOME)
if command -v zenity &> /dev/null; then
    zenity --info --width=500 --height=300 \
        --title="NubiferOS - Recovery Key" \
        --text="<b>IMPORTANT: Write Down Your Recovery Key</b>\n\nYour disk encryption recovery key is:\n\n<span font='monospace 14' foreground='#2E7D32'><b>${RECOVERY_KEY}</b></span>\n\n<b>Store this key in a safe place!</b>\n\n• This key can unlock your disk if you forget your password\n• Anyone with this key can access your data\n• A copy will also be saved to your Desktop\n\n<small>Click OK to continue with installation...</small>" \
        --ok-label="I've Written It Down" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "User acknowledged recovery key"
    fi
# Fallback to kdialog (KDE)
elif command -v kdialog &> /dev/null; then
    kdialog --title "NubiferOS - Recovery Key" \
        --msgbox "IMPORTANT: Write Down Your Recovery Key\n\nYour disk encryption recovery key is:\n\n${RECOVERY_KEY}\n\nStore this key in a safe place!\n\n• This key can unlock your disk if you forget your password\n• Anyone with this key can access your data\n• A copy will also be saved to your Desktop" 2>/dev/null
# Fallback to xmessage
elif command -v xmessage &> /dev/null; then
    xmessage -center -buttons "I've Written It Down:0" \
        "IMPORTANT: Write Down Your Recovery Key

Your disk encryption recovery key is:

    ${RECOVERY_KEY}

Store this key in a safe place!

• This key can unlock your disk if you forget your password
• Anyone with this key can access your data
• A copy will also be saved to your Desktop" 2>/dev/null
else
    echo "WARNING: No graphical dialog tool available"
    echo "Recovery key will be on Desktop after reboot"
fi

exit 0
