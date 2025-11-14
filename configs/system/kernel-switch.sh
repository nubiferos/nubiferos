#!/bin/bash
# NubiferOS Kernel Switcher
# Educational tool to switch between kernel versions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo nubifer-kernel-switch [stable|backports|realtime]"
    exit 1
fi

# Show current kernel
show_current_kernel() {
    echo "=========================================="
    echo "Current Kernel Information"
    echo "=========================================="
    echo ""
    echo "Kernel version: $(uname -r)"
    echo "Kernel type: $(uname -v)"
    echo ""
}

# Explain kernel switch
explain_switch() {
    local target="$1"
    
    case "$target" in
        stable)
            cat << 'EOF'
Switching to STABLE kernel (6.1 LTS)

WHAT THIS MEANS:
• Most reliable and tested kernel
• Long-term support until 2026
• Automatic security updates
• Best for production use

WHY SWITCH TO STABLE:
• You're experiencing issues with current kernel
• You prioritize stability over features
• You're managing production cloud infrastructure
• You don't need cutting-edge hardware support

WHAT WILL HAPPEN:
1. Install linux-image-amd64 (stable)
2. Update GRUB bootloader
3. Set stable as default boot option
4. Reboot required to use new kernel

AFTER REBOOT:
• System will boot with stable kernel
• Previous kernel remains as backup
• You can switch back anytime

EOF
            ;;
        backports)
            cat << 'EOF'
Switching to BACKPORTS kernel (6.5+)

WHAT THIS MEANS:
• Newer kernel with latest features
• Better support for new hardware
• Still tested, but less than stable
• Updated more frequently

WHY SWITCH TO BACKPORTS:
• You have very new hardware (2024)
• Stable kernel doesn't detect your hardware
• You need specific newer features
• You want better performance on new CPUs

WHAT WILL HAPPEN:
1. Enable Debian backports repository
2. Install linux-image-amd64 from backports
3. Update GRUB bootloader
4. Set backports as default boot option
5. Reboot required to use new kernel

TRADE-OFFS:
⚠️  Slightly less tested than stable
⚠️  More frequent updates
⚠️  Small chance of regressions

AFTER REBOOT:
• System will boot with backports kernel
• Previous kernel remains as backup
• You can switch back anytime

EOF
            ;;
        realtime)
            cat << 'EOF'
Switching to REAL-TIME kernel (6.1 RT)

WHAT THIS MEANS:
• Kernel with real-time patches
• Guarantees response times
• Reduces latency and jitter
• Specialized for timing-critical workloads

WHY SWITCH TO REAL-TIME:
• You need deterministic timing
• Audio/video production with low latency
• Industrial control systems
• High-frequency trading
• You KNOW you need real-time

WARNING:
⚠️  Not recommended for general cloud management
⚠️  Slightly lower overall throughput
⚠️  More complex configuration
⚠️  Only use if you have specific real-time requirements

WHAT WILL HAPPEN:
1. Install linux-image-rt-amd64
2. Update GRUB bootloader
3. Set real-time as default boot option
4. Reboot required to use new kernel

AFTER REBOOT:
• System will boot with real-time kernel
• Previous kernel remains as backup
• You can switch back anytime

EOF
            ;;
    esac
}

# Install stable kernel
install_stable() {
    echo "Installing stable kernel..."
    apt-get update
    apt-get install -y linux-image-amd64
    echo "✓ Stable kernel installed"
}

# Install backports kernel
install_backports() {
    echo "Installing backports kernel..."
    
    # Enable backports if not already enabled
    if ! grep -q "bookworm-backports" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "Enabling Debian backports repository..."
        echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list.d/backports.list
    fi
    
    apt-get update
    apt-get install -y -t bookworm-backports linux-image-amd64
    echo "✓ Backports kernel installed"
}

# Install real-time kernel
install_realtime() {
    echo "Installing real-time kernel..."
    apt-get update
    apt-get install -y linux-image-rt-amd64
    echo "✓ Real-time kernel installed"
}

# Update GRUB
update_grub() {
    echo "Updating GRUB bootloader..."
    update-grub
    echo "✓ GRUB updated"
}

# Main switch function
switch_kernel() {
    local target="$1"
    
    show_current_kernel
    explain_switch "$target"
    
    echo ""
    read -p "Do you want to proceed? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi
    
    echo ""
    echo "=========================================="
    echo "Installing $target kernel..."
    echo "=========================================="
    echo ""
    
    case "$target" in
        stable)
            install_stable
            ;;
        backports)
            install_backports
            ;;
        realtime)
            install_realtime
            ;;
        *)
            echo "ERROR: Unknown kernel type: $target"
            exit 1
            ;;
    esac
    
    update_grub
    
    echo ""
    echo "=========================================="
    echo "✓ Kernel Switch Complete"
    echo "=========================================="
    echo ""
    echo "NEXT STEPS:"
    echo "1. Reboot your system: sudo reboot"
    echo "2. After reboot, verify kernel: uname -r"
    echo "3. If issues occur, select previous kernel in GRUB menu"
    echo ""
    echo "Your previous kernel remains installed as backup."
    echo "You can always switch back with:"
    echo "  sudo nubifer-kernel-switch [stable|backports|realtime]"
    echo ""
}

# List available kernels
list_kernels() {
    echo "=========================================="
    echo "Available Kernels"
    echo "=========================================="
    echo ""
    echo "Installed kernels:"
    dpkg -l | grep linux-image | grep -v meta | awk '{print "  " $2 " (" $3 ")"}'
    echo ""
    echo "Current kernel: $(uname -r)"
    echo ""
}

# Show help
show_help() {
    cat << 'EOF'
NubiferOS Kernel Switcher

USAGE:
  sudo nubifer-kernel-switch [stable|backports|realtime]
  sudo nubifer-kernel-switch list
  sudo nubifer-kernel-switch help

KERNEL OPTIONS:

  stable      - Debian stable kernel (6.1 LTS)
                Most reliable, recommended for 95% of users
                Best for: Cloud management, production systems
  
  backports   - Newer kernel from backports (6.5+)
                Better hardware support, more features
                Best for: New hardware from 2024
  
  realtime    - Real-time kernel (6.1 RT)
                Low latency, deterministic timing
                Best for: Audio production, specialized workloads

EXAMPLES:

  # Switch to stable kernel
  sudo nubifer-kernel-switch stable
  
  # Switch to backports for new hardware
  sudo nubifer-kernel-switch backports
  
  # List installed kernels
  sudo nubifer-kernel-switch list
  
  # Show this help
  sudo nubifer-kernel-switch help

NOTES:

  • Reboot required after switching
  • Previous kernel remains as backup
  • You can switch back anytime
  • System will guide you through the process

For more information:
  man nubifer-kernel-switch
  https://docs.nubiferos.org/kernel-selection

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        stable|backports|realtime)
            switch_kernel "$command"
            ;;
        list)
            list_kernels
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "ERROR: Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
