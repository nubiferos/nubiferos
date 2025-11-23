#!/bin/bash
# Configure CPU security mitigations for NubiferOS
# Can be run during build or on installed system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

echo "=========================================="
echo "CPU Security Mitigation Configuration"
echo "=========================================="
echo ""
echo "Choose mitigation level:"
echo ""
echo "1. Default (Recommended)"
echo "   - Spectre v2 mitigation enabled"
echo "   - RETBleed warning will appear"
echo "   - Best performance"
echo "   - Good security for most use cases"
echo ""
echo "2. Full Protection (High Security)"
echo "   - All mitigations enabled"
echo "   - No warnings"
echo "   - 15-30% performance reduction"
echo "   - Recommended for sensitive data"
echo ""
echo "3. Maximum Protection (Paranoid)"
echo "   - All mitigations + disable SMT"
echo "   - No warnings"
echo "   - 30-40% performance reduction"
echo "   - Recommended for highest security needs"
echo ""
echo "4. Performance Mode (NOT RECOMMENDED)"
echo "   - All mitigations disabled"
echo "   - System vulnerable"
echo "   - Only for isolated test environments"
echo ""

read -p "Select option (1-4): " -n 1 -r
echo ""
echo ""

case $REPLY in
    1)
        echo "Configuring: Default mitigations"
        MITIGATION_PARAMS=""
        ;;
    2)
        echo "Configuring: Full protection"
        MITIGATION_PARAMS="retbleed=auto mitigations=auto"
        ;;
    3)
        echo "Configuring: Maximum protection"
        MITIGATION_PARAMS="retbleed=auto mitigations=auto,nosmt"
        echo ""
        echo "⚠️  WARNING: This will disable SMT/HyperThreading"
        echo "   Your CPU will show half the number of cores"
        echo ""
        read -p "Continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
        ;;
    4)
        echo "Configuring: Performance mode (mitigations disabled)"
        echo ""
        echo "⚠️  DANGER: This disables ALL security mitigations"
        echo "   Your system will be vulnerable to:"
        echo "   - Spectre v1, v2, v4"
        echo "   - Meltdown"
        echo "   - RETBleed"
        echo "   - MDS"
        echo "   - And other CPU vulnerabilities"
        echo ""
        echo "   Only use in completely isolated environments!"
        echo ""
        read -p "Are you SURE? (type 'yes' to confirm): " -r
        echo ""
        if [[ ! $REPLY == "yes" ]]; then
            echo "Cancelled"
            exit 0
        fi
        MITIGATION_PARAMS="mitigations=off"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Backup GRUB config
echo "Backing up GRUB configuration..."
if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)
    
    # Update GRUB configuration
    echo "Updating GRUB configuration..."
    
    if [ -z "$MITIGATION_PARAMS" ]; then
        # Remove any existing mitigation parameters
        sed -i 's/ retbleed=[^ "]*//g' /etc/default/grub
        sed -i 's/ mitigations=[^ "]*//g' /etc/default/grub
    else
        # Remove old parameters first
        sed -i 's/ retbleed=[^ "]*//g' /etc/default/grub
        sed -i 's/ mitigations=[^ "]*//g' /etc/default/grub
        
        # Add new parameters
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 $MITIGATION_PARAMS\"/" /etc/default/grub
    fi
    
    # Clean up any double spaces
    sed -i 's/  */ /g' /etc/default/grub
    
    echo ""
    echo "New GRUB configuration:"
    grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub
    
    # Update GRUB
    echo ""
    echo "Updating GRUB..."
    update-grub
    
    echo ""
    echo "=========================================="
    echo "✓ Configuration complete"
    echo "=========================================="
    echo ""
    echo "IMPORTANT: Reboot for changes to take effect"
    echo ""
    echo "After reboot, verify with:"
    echo "  ./testing/check-cpu-mitigations.sh"
    echo ""
else
    echo "Error: /etc/default/grub not found"
    echo "This script must be run on an installed system"
    exit 1
fi
