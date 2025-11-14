#!/bin/bash
# NubiferOS ISO Build Script
# Simple wrapper that checks dependencies and builds the ISO

set -e

# Enable non-interactive mode for automated builds
export NON_INTERACTIVE=true

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
    "grub-mkrescue"
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
    echo "  sudo apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools"
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
echo ""

# Estimate time
echo "Estimated build time: 35-55 minutes"
echo "  - Download Debian: 5-10 min"
echo "  - Extract & customize: 10-15 min"
echo "  - Install packages: 15-20 min"
echo "  - Create ISO: 5-10 min"
echo ""

read -p "Start build? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Build cancelled"
    exit 0
fi

echo ""
echo "=========================================="
echo "Starting ISO build..."
echo "=========================================="
echo ""

# Start build
cd build
./build-iso.sh

echo ""
echo "=========================================="
echo "✅ Build Complete!"
echo "=========================================="
echo ""

# Show output
if [ -f ../output/nubiferos-1.0-amd64.iso ]; then
    ISO_SIZE=$(du -h ../output/nubiferos-1.0-amd64.iso | cut -f1)
    echo "ISO created: output/nubiferos-1.0-amd64.iso (${ISO_SIZE})"
    echo "Checksum: output/nubiferos-1.0-amd64.iso.sha256"
    echo ""
    echo "Test in VirtualBox:"
    echo "  1. Create new VM (Linux/Debian 64-bit)"
    echo "  2. Allocate 4GB RAM, 20GB disk"
    echo "  3. Mount ISO: output/nubiferos-1.0-amd64.iso"
    echo "  4. Boot and test!"
    echo ""
    echo "Or test with QEMU:"
    echo "  qemu-system-x86_64 -cdrom output/nubiferos-1.0-amd64.iso -m 4096 -enable-kvm"
    echo ""
else
    echo "❌ ISO file not found. Check build logs for errors."
    exit 1
fi
