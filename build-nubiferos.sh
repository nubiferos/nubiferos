#!/bin/bash
# NubiferOS ISO Build Script
# Simple wrapper that checks dependencies and builds the ISO

set -e

# Parse arguments
BUILD_TYPE="installer"  # Default to installer-only (production)
NON_INTERACTIVE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --installer-only)
            BUILD_TYPE="installer"
            shift
            ;;
        --live)
            BUILD_TYPE="live"
            shift
            ;;
        --interactive)
            NON_INTERACTIVE=false
            shift
            ;;
        --help)
            cat << EOF
NubiferOS ISO Build Script

Usage: $0 [options]

Build Types:
  --installer-only   Build production installer-only ISO (default)
  --live            Build development live ISO (testing only)

Options:
  --interactive     Enable interactive prompts
  --help           Show this help message

Examples:
  sudo $0 --installer-only    # Production ISO (recommended)
  sudo $0 --live              # Development ISO (testing only)

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
done

# Enable non-interactive mode for automated builds
export NON_INTERACTIVE

echo "=========================================="
echo "NubiferOS ISO Builder"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root"
    echo "   Run: sudo ./build-nubiferos.sh"
    exit 1
fi

# Check disk space
AVAILABLE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE" -lt 50 ]; then
    echo "⚠️  Warning: Low disk space (${AVAILABLE}GB available)"
    echo "   Recommended: 50GB+ free space"
    if [ "$NON_INTERACTIVE" != "true" ]; then
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "   Continuing in non-interactive mode..."
    fi
fi

# Check dependencies
echo "Checking build dependencies..."
MISSING=()

DEPS=(
    "debootstrap"
    "mksquashfs"
    "xorriso"
    "grub-mkstandalone"
    "mkfs.vfat"
)

for dep in "${DEPS[@]}"; do
    if ! command -v $dep &> /dev/null; then
        MISSING+=($dep)
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${MISSING[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
    echo ""
    exit 1
fi

echo "✅ All dependencies present"
echo ""

# Show what will be built
echo "Build Configuration:"
echo "  Distribution: NubiferOS 1.0 (Nimbus)"
echo "  Base: Debian 12 (Bookworm)"
echo "  Desktop: GNOME with Wayland"
echo "  Architecture: amd64"
if [ "$BUILD_TYPE" = "installer" ]; then
    echo "  Type: Production Installer-Only ISO"
    echo "  Security: Minimal attack surface, mandatory encryption"
else
    echo "  Type: Development Live ISO"
    echo "  ⚠️  WARNING: TESTING ONLY - NOT FOR PRODUCTION"
    echo "  Security: Reduced (live environment)"
fi
echo ""

# Estimate time
echo "Estimated build time: 35-55 minutes"
echo "  - Download Debian: 5-10 min"
echo "  - Extract & customize: 10-15 min"
echo "  - Install packages: 15-20 min"
echo "  - Create ISO: 5-10 min"
echo ""

if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Start build? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Build cancelled"
        exit 0
    fi
else
    echo "Starting build in non-interactive mode..."
fi

echo ""
echo "=========================================="
echo "Starting ISO build..."
echo "=========================================="
echo ""

# Start build
cd build
if [ "$BUILD_TYPE" = "installer" ]; then
    ./build-iso.sh --installer-only
else
    ./build-iso.sh --live
fi

echo ""
echo "=========================================="
echo "✅ Build Complete!"
echo "=========================================="
echo ""

# Show output
ISO_FILE=$(ls ../output/*.iso 2>/dev/null | head -1)
if [ -f "$ISO_FILE" ]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    ISO_NAME=$(basename "$ISO_FILE")
    echo "ISO created: output/$ISO_NAME (${ISO_SIZE})"
    echo "Checksum: output/$ISO_NAME.sha256"
    echo ""
    echo "Test in VirtualBox:"
    echo "  1. Create new VM (Linux/Debian 64-bit)"
    echo "  2. Allocate 4GB RAM, 20GB disk"
    echo "  3. Mount ISO: output/$ISO_NAME"
    echo "  4. Boot and test!"
    echo ""
    echo "Or test with QEMU:"
    echo "  qemu-system-x86_64 -cdrom output/$ISO_NAME -m 4096 -enable-kvm"
    echo ""
else
    echo "❌ ISO file not found. Check build logs for errors."
    echo "Looking for ISO in: ../output/"
    ls -la ../output/ || echo "output/ directory not found"
    exit 1
fi
