#!/bin/bash
# NubiferOS ISO Build Script
# Simple wrapper that checks dependencies and builds the ISO

set -e

#!/bin/bash
# NubiferOS ISO Build Script
# Simple wrapper that checks dependencies and builds the ISO

set -e

# Mode resolution: CLI flag > Environment variable > Default
BUILD_TYPE=""
if [ -n "${ISO_MODE}" ]; then
    case "${ISO_MODE}" in
        installer|live)
            BUILD_TYPE="${ISO_MODE}"
            ;;
        *)
            echo "ERROR: Invalid ISO_MODE value: ${ISO_MODE}"
            echo "Valid values: installer, live"
            exit 1
            ;;
    esac
fi

# Default to installer-only (production) if not set
if [ -z "${BUILD_TYPE}" ]; then
    BUILD_TYPE="installer"
fi

# Detect CI environment for non-interactive mode
NON_INTERACTIVE=false
if [ -n "${CI}" ] || [ -n "${GITHUB_ACTIONS}" ] || [ -n "${GITLAB_CI}" ] || [ -n "${JENKINS_URL}" ] || [ ! -t 0 ]; then
    NON_INTERACTIVE=true
fi

# Parse arguments
MINIMAL_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            if [ -z "$2" ]; then
                echo "ERROR: --mode requires a value (installer|live)"
                exit 1
            fi
            case "$2" in
                installer|live)
                    BUILD_TYPE="$2"
                    ;;
                *)
                    echo "ERROR: Invalid mode: $2"
                    echo "Valid modes: installer, live"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --installer-only)
            BUILD_TYPE="installer"
            shift
            ;;
        --live)
            BUILD_TYPE="live"
            shift
            ;;
        --minimal)
            MINIMAL_BUILD=true
            shift
            ;;
        --interactive)
            NON_INTERACTIVE=false
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --help)
            cat << EOF
NubiferOS ISO Build Script

Usage: $0 [options]

Build Types:
  --mode <type>      Set build mode (installer|live)
  --installer-only   Build production installer-only ISO (default)
  --live            Build development live ISO (testing only)
  --minimal         Fast test build: xorg+openbox+calamares only (~5-10 min)
                    Use this to quickly test Calamares/bootloader changes

Options:
  --interactive      Enable interactive prompts (default in terminal)
  --non-interactive  Disable interactive prompts (default in CI)
  --help            Show this help message

Environment Variables:
  ISO_MODE          Set build mode (installer|live)
                    CLI --mode flag takes precedence over environment
  CI                Auto-detected for non-interactive mode

Examples:
  sudo $0 --mode installer        # Production ISO (~35-55 min)
  sudo $0 --live                  # Development ISO
  sudo $0 --minimal               # Fast test ISO (~5-10 min)
  sudo ISO_MODE=installer $0      # Production ISO via environment

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
    if [ "$NON_INTERACTIVE" = "false" ]; then
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "   Continuing automatically in non-interactive mode..."
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
echo "  Architecture: amd64"
if [ "$MINIMAL_BUILD" = true ]; then
    echo "  Desktop: Openbox (minimal)"
    echo "  Type: FAST TEST BUILD"
    echo "  ⚠️  WARNING: Minimal desktop - for Calamares/bootloader testing only"
elif [ "$BUILD_TYPE" = "installer" ]; then
    echo "  Desktop: GNOME with Wayland"
    echo "  Type: Production Installer-Only ISO"
    echo "  Security: Minimal attack surface, mandatory encryption"
else
    echo "  Desktop: GNOME with Wayland"
    echo "  Type: Development Live ISO"
    echo "  ⚠️  WARNING: TESTING ONLY - NOT FOR PRODUCTION"
    echo "  Security: Reduced (live environment)"
fi
echo ""

# Estimate time
if [ "$MINIMAL_BUILD" = true ]; then
    echo "Estimated build time: 5-10 minutes"
    echo "  - Download Debian: 3-5 min"
    echo "  - Install minimal packages: 2-3 min"
    echo "  - Create ISO: 1-2 min"
else
    echo "Estimated build time: 35-55 minutes"
    echo "  - Download Debian: 5-10 min"
    echo "  - Extract & customize: 10-15 min"
    echo "  - Install packages: 15-20 min"
    echo "  - Create ISO: 5-10 min"
fi
echo ""

if [ "$NON_INTERACTIVE" = "false" ]; then
    read -p "Start build? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Build cancelled"
        exit 0
    fi
else
    echo "Starting build automatically in non-interactive mode..."
fi

echo ""
echo "=========================================="
echo "Starting ISO build..."
echo "=========================================="
echo ""

# Start build
cd build
BUILD_FLAGS=""
if [ "$MINIMAL_BUILD" = true ]; then
    BUILD_FLAGS="--minimal"
fi

if [ "$BUILD_TYPE" = "installer" ]; then
    ./build-iso.sh --installer-only $BUILD_FLAGS
else
    ./build-iso.sh --live $BUILD_FLAGS
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
