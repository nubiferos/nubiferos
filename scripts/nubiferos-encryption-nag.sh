#!/bin/bash
# NubiferOS Encryption Nag Script
# This runs on login if the user installed without encryption.
# It will remind them of their questionable decision. Forever.

SHAME_FILE="$HOME/.config/nubiferos/.no-encryption-shame"

# Only nag if the shame file exists
if [ ! -f "$SHAME_FILE" ]; then
    exit 0
fi

# Count how many times we've nagged
NAG_COUNT=$(cat "$SHAME_FILE" 2>/dev/null || echo "0")
NAG_COUNT=$((NAG_COUNT + 1))
echo "$NAG_COUNT" > "$SHAME_FILE"

# Different messages based on nag count
case $NAG_COUNT in
    1)
        MSG="Your disk is not encrypted. Your cloud credentials are at risk if this device is lost or stolen."
        ;;
    2|3|4)
        MSG="Reminder #$NAG_COUNT: Still no disk encryption. Your AWS/Azure/GCP keys are stored in plain text on disk."
        ;;
    5|6|7|8|9)
        MSG="Nag #$NAG_COUNT: Seriously, encrypt your disk. Run 'sudo nubiferos-enable-encryption' to fix this."
        ;;
    *)
        # After 10+, get progressively more passive-aggressive
        PHRASES=(
            "Day $NAG_COUNT without encryption. The cloud credentials remain vulnerable."
            "Encryption reminder #$NAG_COUNT. We're not mad, just disappointed."
            "Still unencrypted after $NAG_COUNT logins. Your secrets called, they feel exposed."
            "Login #$NAG_COUNT. Your credentials are still readable by anyone with a screwdriver."
            "Nag $NAG_COUNT: If your laptop gets stolen, don't say we didn't warn you."
        )
        IDX=$((NAG_COUNT % ${#PHRASES[@]}))
        MSG="${PHRASES[$IDX]}"
        ;;
esac

# Show notification
notify-send -u critical -i security-low \
    "NubiferOS Security Warning" \
    "$MSG" \
    -t 10000

# Also log it
logger -t nubiferos-security "Encryption nag #$NAG_COUNT shown to user"
