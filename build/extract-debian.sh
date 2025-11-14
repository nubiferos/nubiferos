#!/bin/bash
# Extract and customize Debian base system
# Part of NubiferOS build system

set -e  # Exit on error

# Load brand configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

# Initialize configuration
init_config

# Non-interactive mode (auto-accept prompts)
NON_INTERACTIVE=${NON_INTERACTIVE:-false}

log "INFO" "Starting Debian base extraction"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Directories
DOWNLOAD_DIR="${PROJECT_ROOT}/downloads"
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"
MOUNT_DIR="${WORK_DIR}/mnt"

# Create working directories
mkdir -p "${WORK_DIR}"
mkdir -p "${CHROOT_DIR}"
mkdir -p "${MOUNT_DIR}"

# Get ISO path
ISO_PATH_FILE="${DOWNLOAD_DIR}/debian-iso-path.txt"
if [ ! -f "${ISO_PATH_FILE}" ]; then
    log "ERROR" "Debian ISO path file not found. Run download-debian.sh first."
    exit 1
fi

ISO_PATH=$(cat "${ISO_PATH_FILE}")

if [ ! -f "${ISO_PATH}" ]; then
    log "ERROR" "Debian ISO not found: ${ISO_PATH}"
    exit 1
fi

log "INFO" "Using ISO: ${ISO_PATH}"

# Check for required tools
check_dependencies() {
    local missing_deps=()
    
    for cmd in debootstrap mount umount chroot; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "ERROR" "Install with: sudo apt-get install debootstrap debian-archive-keyring"
        exit 1
    fi
    
    # Check for Debian keyring
    if [ ! -f "/usr/share/keyrings/debian-archive-keyring.gpg" ]; then
        log "WARN" "Debian archive keyring not found"
        log "WARN" "Install with: sudo apt-get install debian-archive-keyring"
        log "WARN" "Continuing without signature verification..."
    fi
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up mounts..."
    
    # Unmount in reverse order
    umount "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
    umount "${CHROOT_DIR}/dev" 2>/dev/null || true
    umount "${CHROOT_DIR}/proc" 2>/dev/null || true
    umount "${CHROOT_DIR}/sys" 2>/dev/null || true
    umount "${MOUNT_DIR}" 2>/dev/null || true
    
    log "INFO" "Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT

# Bootstrap Debian base system
bootstrap_debian() {
    log "INFO" "Bootstrapping Debian ${BASE_VERSION} (${BASE_CODENAME})..."
    
    if [ -d "${CHROOT_DIR}/bin" ]; then
        log "WARN" "Chroot directory already exists: ${CHROOT_DIR}"
        if [ "$NON_INTERACTIVE" = "true" ]; then
            log "INFO" "Non-interactive mode: using existing chroot"
            return 0
        fi
        read -p "Remove and re-bootstrap? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Removing existing chroot..."
            rm -rf "${CHROOT_DIR}"
            mkdir -p "${CHROOT_DIR}"
        else
            log "INFO" "Using existing chroot"
            return 0
        fi
    fi
    
    # Run debootstrap
    log "INFO" "Running debootstrap (this will take several minutes)..."
    debootstrap \
        --arch="${ARCH}" \
        --variant=minbase \
        --include=systemd,systemd-sysv,udev,dbus \
        "${BASE_CODENAME}" \
        "${CHROOT_DIR}" \
        "${DEBIAN_MIRROR}"
    
    log "INFO" "✓ Debian base system bootstrapped"
}

# Configure base system
configure_base_system() {
    log "INFO" "Configuring base system..."
    
    # Set hostname
    echo "${BRAND_CLI_NAME}" > "${CHROOT_DIR}/etc/hostname"
    
    # Configure hosts file
    cat > "${CHROOT_DIR}/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   ${BRAND_CLI_NAME}

# IPv6
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Configure APT sources
    cat > "${CHROOT_DIR}/etc/apt/sources.list" << EOF
# Debian ${BASE_VERSION} (${BASE_CODENAME}) repositories
deb ${DEBIAN_MIRROR} ${BASE_CODENAME} main contrib non-free non-free-firmware
deb-src ${DEBIAN_MIRROR} ${BASE_CODENAME} main contrib non-free non-free-firmware

# Security updates
deb ${DEBIAN_SECURITY} ${BASE_CODENAME}-security main contrib non-free non-free-firmware
deb-src ${DEBIAN_SECURITY} ${BASE_CODENAME}-security main contrib non-free non-free-firmware

# Updates
deb ${DEBIAN_MIRROR} ${BASE_CODENAME}-updates main contrib non-free non-free-firmware
deb-src ${DEBIAN_MIRROR} ${BASE_CODENAME}-updates main contrib non-free non-free-firmware
EOF
    
    # Configure timezone
    echo "UTC" > "${CHROOT_DIR}/etc/timezone"
    
    # Configure locale
    echo "en_US.UTF-8 UTF-8" > "${CHROOT_DIR}/etc/locale.gen"
    
    log "INFO" "✓ Base system configured"
}

# Mount necessary filesystems for chroot
mount_chroot() {
    log "INFO" "Mounting filesystems for chroot..."
    
    mount -t proc proc "${CHROOT_DIR}/proc"
    mount -t sysfs sysfs "${CHROOT_DIR}/sys"
    mount -o bind /dev "${CHROOT_DIR}/dev"
    mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
    
    log "INFO" "✓ Filesystems mounted"
}

# Update package lists in chroot
update_chroot() {
    log "INFO" "Updating package lists in chroot..."
    
    chroot "${CHROOT_DIR}" /bin/bash -c "apt-get update"
    
    log "INFO" "✓ Package lists updated"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Debian Base Extraction"
    log "INFO" "=========================================="
    log "INFO" "Base: Debian ${BASE_VERSION} (${BASE_CODENAME})"
    log "INFO" "Architecture: ${ARCH}"
    log "INFO" "Work directory: ${WORK_DIR}"
    log "INFO" "=========================================="
    
    # Check dependencies
    check_dependencies
    
    # Bootstrap Debian
    bootstrap_debian
    
    # Configure base system
    configure_base_system
    
    # Mount filesystems
    mount_chroot
    
    # Update package lists
    update_chroot
    
    log "INFO" "=========================================="
    log "INFO" "Debian base system ready: ${CHROOT_DIR}"
    log "INFO" "=========================================="
    log "INFO" "Next step: Run ./build/install-cloud-tools.sh"
}

# Run main function
main "$@"
