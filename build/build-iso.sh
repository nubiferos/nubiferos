#!/bin/bash
# Main ISO build script for NubiferOS
# Orchestrates the complete build process

set -e

# Error handler
error_handler() {
    echo ""
    echo "=========================================="
    echo "❌ BUILD FAILED at line $1"
    echo "=========================================="
    echo "Command: $BASH_COMMAND"
    echo "Exit code: $?"
    echo ""
    echo "Check the logs above for details."
    exit 1
}

trap 'error_handler $LINENO' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

# Parse arguments
ENABLE_TESTS=false
SKIP_DOWNLOAD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --enable-tests)
            ENABLE_TESTS=true
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        --help)
            cat << EOF
NubiferOS ISO Build Script

Usage: $0 [options]

Options:
  --enable-tests     Enable post-installation testing
  --skip-download    Skip Debian ISO download (use existing)
  --help            Show this help message

Example:
  sudo $0 --enable-tests

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

log "INFO" "=========================================="
log "INFO" "NubiferOS ISO Build"
log "INFO" "=========================================="
log "INFO" "Version: ${DISTRO_VERSION}"
log "INFO" "Codename: ${DISTRO_CODENAME}"
log "INFO" "Test Mode: ${ENABLE_TESTS}"
log "INFO" "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Check dependencies
check_dependencies() {
    log "INFO" "Checking build dependencies..."
    
    local missing=()
    
    for cmd in debootstrap mksquashfs xorriso grub-mkrescue; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        log "INFO" "Install with: apt-get install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools"
        exit 1
    fi
    
    log "INFO" "✓ All dependencies present"
}

# Build steps
build_iso() {
    local start_time=$(date +%s)
    
    # Step 1: Download Debian base
    if [ "$SKIP_DOWNLOAD" = false ]; then
        log "INFO" "Step 1/7: Downloading Debian base..."
        "${SCRIPT_DIR}/download-debian.sh"
    else
        log "INFO" "Step 1/7: Skipping download (--skip-download)"
    fi
    
    # Step 2: Extract Debian
    log "INFO" "Step 2/7: Extracting Debian base..."
    "${SCRIPT_DIR}/extract-debian.sh"
    
    # Step 3: Install cloud tools
    log "INFO" "Step 3/7: Installing cloud tools..."
    "${SCRIPT_DIR}/install-cloud-tools.sh"
    
    # Step 4: Install desktop environment
    log "INFO" "Step 4/7: Installing GNOME desktop..."
    "${SCRIPT_DIR}/install-desktop.sh"
    
    # Step 5: Apply security hardening
    log "INFO" "Step 5/7: Applying security hardening..."
    "${SCRIPT_DIR}/apply-security-hardening.sh"
    
    # Step 6: Install NubiferOS components
    log "INFO" "Step 6/7: Installing NubiferOS components..."
    install_nubifer_components
    
    # Step 7: Create bootable ISO
    log "INFO" "Step 7/7: Creating bootable ISO..."
    create_bootable_iso
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "INFO" "=========================================="
    log "INFO" "Build complete!"
    log "INFO" "=========================================="
    log "INFO" "Duration: $((duration / 60)) minutes $((duration % 60)) seconds"
    log "INFO" "ISO: ${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso"
    log "INFO" "Checksum: ${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso.sha256"
    log "INFO" "=========================================="
}

# Install NubiferOS components
install_nubifer_components() {
    log "INFO" "Installing NubiferOS scripts and components..."
    
    # Copy scripts to chroot
    mkdir -p "${CHROOT_DIR}/usr/local/bin"
    
    # Credential manager
    cp "${PROJECT_ROOT}/components/credential-manager/nubifer-creds" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-creds"
    
    # Setup wizard
    cp "${PROJECT_ROOT}/scripts/nubifer-setup-wizard" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-setup-wizard"
    
    # Update checker
    cp "${PROJECT_ROOT}/scripts/nubifer-update-checker" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-update-checker"
    
    # IDE plugin installer
    cp "${PROJECT_ROOT}/configs/ide/install-ide-plugins.sh" "${CHROOT_DIR}/usr/local/bin/install-ide-plugins"
    chmod +x "${CHROOT_DIR}/usr/local/bin/install-ide-plugins"
    
    # Copy documentation
    mkdir -p "${CHROOT_DIR}/usr/share/doc/nubifer"
    cp "${PROJECT_ROOT}"/docs/*.md "${CHROOT_DIR}/usr/share/doc/nubifer/"
    
    # Copy browser configuration
    mkdir -p "${CHROOT_DIR}/usr/share/nubifer/browser"
    cp "${PROJECT_ROOT}/configs/browser/firefox-bookmarks.json" "${CHROOT_DIR}/usr/share/nubifer/browser/"
    cp "${PROJECT_ROOT}/configs/browser/firefox-hardening.js" "${CHROOT_DIR}/usr/share/nubifer/browser/"
    
    # Install Workspace Manager
    log "INFO" "Installing Workspace Manager..."
    
    # Copy workspace manager
    cp "${PROJECT_ROOT}/components/workspace-manager/nubifer-workspace" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-workspace"
    
    # Copy shell integration
    mkdir -p "${CHROOT_DIR}/etc/nubifer"
    cp "${PROJECT_ROOT}/components/workspace-manager/shell-integration.sh" "${CHROOT_DIR}/etc/nubifer/"
    chmod 644 "${CHROOT_DIR}/etc/nubifer/shell-integration.sh"
    
    # Add to /etc/bash.bashrc
    if ! grep -q "nubifer/shell-integration.sh" "${CHROOT_DIR}/etc/bash.bashrc"; then
        cat >> "${CHROOT_DIR}/etc/bash.bashrc" << 'EOF'

# NubiferOS Workspace Integration
if [ -f /etc/nubifer/shell-integration.sh ]; then
    source /etc/nubifer/shell-integration.sh
fi
EOF
    fi
    
    # Install Firejail integration
    log "INFO" "Installing Firejail integration..."
    
    # Install Firejail
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y firejail"
    
    # Copy Firejail profiles
    mkdir -p "${CHROOT_DIR}/etc/firejail/nubifer"
    cp "${PROJECT_ROOT}/components/workspace-manager/firejail-profiles"/*.profile "${CHROOT_DIR}/etc/firejail/nubifer/"
    chmod 644 "${CHROOT_DIR}/etc/firejail/nubifer"/*.profile
    
    # Copy Firejail wrapper
    mkdir -p "${CHROOT_DIR}/usr/local/lib/nubifer"
    cp "${PROJECT_ROOT}/components/workspace-manager/firejail-wrapper.sh" "${CHROOT_DIR}/usr/local/lib/nubifer/"
    chmod 755 "${CHROOT_DIR}/usr/local/lib/nubifer/firejail-wrapper.sh"
    
    # Copy CLI wrappers
    mkdir -p "${CHROOT_DIR}/usr/local/lib/nubifer/cli-wrappers"
    cp "${PROJECT_ROOT}/components/workspace-manager/cli-wrappers"/* "${CHROOT_DIR}/usr/local/lib/nubifer/cli-wrappers/"
    chmod 755 "${CHROOT_DIR}/usr/local/lib/nubifer/cli-wrappers"/*
    
    # Note: CLI wrapper symlinks will be created during post-install
    # This allows users to opt-in to Firejail isolation
    
    log "INFO" "  ✓ Workspace Manager installed"
    log "INFO" "  ✓ Firejail integration installed"
    
    # Copy workspace manager installer scripts
    mkdir -p "${CHROOT_DIR}/usr/share/nubifer/installer"
    cp "${PROJECT_ROOT}/installer/post-install-workspace.sh" "${CHROOT_DIR}/usr/share/nubifer/installer/"
    cp "${PROJECT_ROOT}/installer/enable-firejail-wrappers.sh" "${CHROOT_DIR}/usr/share/nubifer/installer/"
    cp "${PROJECT_ROOT}/installer/disable-firejail-wrappers.sh" "${CHROOT_DIR}/usr/share/nubifer/installer/"
    chmod +x "${CHROOT_DIR}/usr/share/nubifer/installer"/*.sh
    
    # Copy test scripts if test mode enabled
    if [ "$ENABLE_TESTS" = true ]; then
        mkdir -p "${CHROOT_DIR}/usr/share/nubifer/tests"
        cp "${PROJECT_ROOT}/tests/post-install-tests.sh" "${CHROOT_DIR}/usr/share/nubifer/tests/"
        cp "${PROJECT_ROOT}/installer/post-install-test.service" "${CHROOT_DIR}/usr/share/nubifer/installer/"
        
        # Enable test mode
        mkdir -p "${CHROOT_DIR}/etc/nubifer"
        touch "${CHROOT_DIR}/etc/nubifer/run-post-install-tests"
        
        log "INFO" "  ✓ Test mode enabled"
    fi
    
    log "INFO" "✓ NubiferOS components installed"
}

# Create bootable ISO
create_bootable_iso() {
    log "INFO" "Creating bootable ISO..."
    
    local ISO_DIR="${WORK_DIR}/iso"
    local SQUASHFS_DIR="${ISO_DIR}/live"
    
    # Create ISO directory structure
    mkdir -p "${SQUASHFS_DIR}"
    mkdir -p "${ISO_DIR}/boot/grub"
    
    # Create squashfs filesystem
    log "INFO" "Creating squashfs filesystem (this may take several minutes)..."
    mksquashfs "${CHROOT_DIR}" "${SQUASHFS_DIR}/filesystem.squashfs" \
        -comp xz \
        -b 1M \
        -Xdict-size 100% \
        -noappend
    
    # Create GRUB configuration
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
set timeout=10
set default=0

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Live" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Install" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}
EOF
    
    # Copy kernel and initrd
    log "INFO" "Copying kernel and initrd..."
    cp "${CHROOT_DIR}/boot/vmlinuz-"* "${ISO_DIR}/boot/vmlinuz"
    cp "${CHROOT_DIR}/boot/initrd.img-"* "${ISO_DIR}/boot/initrd.img"
    
    # Create ISO
    log "INFO" "Generating ISO file..."
    mkdir -p "${OUTPUT_DIR}"
    
    local ISO_FILE="${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso"
    
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${DISTRO_NAME}-${DISTRO_VERSION}" \
        -eltorito-boot boot/grub/grub.cfg \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -eltorito-catalog boot/boot.cat \
        -output "${ISO_FILE}" \
        "${ISO_DIR}"
    
    # Generate checksum
    log "INFO" "Generating checksum..."
    (cd "${OUTPUT_DIR}" && sha256sum "$(basename ${ISO_FILE})" > "$(basename ${ISO_FILE}).sha256")
    
    # Get ISO size
    local iso_size=$(du -h "${ISO_FILE}" | cut -f1)
    
    log "INFO" "✓ ISO created: ${ISO_FILE} (${iso_size})"
}

# Main execution
main() {
    check_dependencies
    build_iso
    
    log "INFO" ""
    log "INFO" "=========================================="
    log "INFO" "Build Complete!"
    log "INFO" "=========================================="
    log "INFO" ""
    log "INFO" "ISO file: ${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso"
    log "INFO" "Checksum: ${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso.sha256"
    log "INFO" ""
    log "INFO" "Test in VM:"
    log "INFO" "  qemu-system-x86_64 -cdrom ${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso -m 4096 -enable-kvm"
    log "INFO" ""
    log "INFO" "Write to USB:"
    log "INFO" "  sudo dd if=${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso of=/dev/sdX bs=4M status=progress"
    log "INFO" ""
    log "INFO" "=========================================="
}

main "$@"
