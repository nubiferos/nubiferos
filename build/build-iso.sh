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

# Parse arguments and environment variables
ENABLE_TESTS=false
SKIP_DOWNLOAD=false

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
        --help)
            cat << EOF
NubiferOS ISO Build Script

Usage: $0 [options]

Build Types:
  --mode <type>      Set build mode (installer|live)
  --installer-only   Build production installer-only ISO (default)
  --live            Build development live ISO (testing only)

Options:
  --enable-tests     Enable post-installation testing
  --skip-download    Skip Debian ISO download (use existing)
  --help            Show this help message

Environment Variables:
  ISO_MODE          Set build mode (installer|live)
                    CLI --mode flag takes precedence over environment

Examples:
  sudo $0 --mode installer        # Production ISO
  sudo $0 --live                  # Development ISO
  sudo ISO_MODE=installer $0      # Production ISO via environment
  sudo ISO_MODE=live $0           # Development ISO via environment

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
if [ "$BUILD_TYPE" = "installer" ]; then
    log "INFO" "Build Type: Production Installer-Only ISO"
    log "INFO" "Security: Minimal attack surface, mandatory encryption"
else
    log "INFO" "Build Type: Development Live ISO"
    log "WARN" "⚠️  WARNING: TESTING ONLY - NOT FOR PRODUCTION"
    log "INFO" "Security: Reduced (live environment)"
fi
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
    
    for cmd in debootstrap mksquashfs xorriso grub-mkstandalone mkfs.vfat; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    # Check for required GRUB files
    if [ ! -f /usr/lib/grub/i386-pc/cdboot.img ]; then
        log "ERROR" "Missing GRUB BIOS boot files"
        missing+=("grub-pc-bin")
    fi
    
    if [ ! -f /usr/lib/grub/i386-pc/boot_hybrid.img ]; then
        log "ERROR" "Missing GRUB hybrid boot files"
        missing+=("grub-pc-bin")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        log "INFO" "Install with: apt-get install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
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
    # DISABLED: Cloud tools now installed via Calamares package selection
    # This reduces ISO size from 4-5GB to 2-3GB
    # log "INFO" "Step 3/7: Installing cloud tools..."
    # "${SCRIPT_DIR}/install-cloud-tools.sh"
    log "INFO" "Step 3/7: Skipping cloud tools (will be installed via Calamares)"
    
    # Step 4: Install desktop environment
    if [ "$BUILD_TYPE" = "installer" ]; then
        log "INFO" "Step 4/7: Installing GNOME desktop (installer-only)..."
        "${SCRIPT_DIR}/install-desktop-installer.sh"
    else
        log "INFO" "Step 4/7: Installing GNOME desktop (live environment)..."
        "${SCRIPT_DIR}/install-desktop-live.sh"
    fi
    
    # Step 5: Apply security hardening
    log "INFO" "Step 5/7: Applying security hardening..."
    "${SCRIPT_DIR}/apply-security-hardening.sh"
    
    # Step 6: Install Calamares installer
    log "INFO" "Step 6/7: Installing Calamares installer..."
    "${SCRIPT_DIR}/install-calamares.sh"
    
    # Step 6.5: Fix Calamares Debian-specific issues
    log "INFO" "Step 6.5/7: Fixing Calamares Debian issues..."
    "${SCRIPT_DIR}/fix-calamares-debian-issues.sh"
    
    # Step 6.6: Configure auto-login and Calamares auto-launch
    log "INFO" "Step 6.6/7: Configuring installer auto-start..."
    "${SCRIPT_DIR}/configure-installer-autostart.sh"
    
    # Step 7: Install NubiferOS components
    log "INFO" "Step 7/7: Installing NubiferOS components..."
    install_nubifer_components
    
    # Step 8: Create bootable ISO
    log "INFO" "Creating bootable ISO..."
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
    
    # IDE installer (VS Code, IntelliJ, PyCharm)
    cp "${PROJECT_ROOT}/scripts/install-ides.sh" "${CHROOT_DIR}/usr/local/bin/install-ides"
    chmod +x "${CHROOT_DIR}/usr/local/bin/install-ides"
    
    # Cloud SDK installer
    cp "${PROJECT_ROOT}/scripts/install-cloud-sdks.sh" "${CHROOT_DIR}/usr/local/bin/install-cloud-sdks"
    chmod +x "${CHROOT_DIR}/usr/local/bin/install-cloud-sdks"
    
    # GRUB installation wrapper for LUKS
    cp "${PROJECT_ROOT}/scripts/grub-install-luks-wrapper.sh" "${CHROOT_DIR}/usr/local/bin/grub-install-luks-wrapper"
    chmod +x "${CHROOT_DIR}/usr/local/bin/grub-install-luks-wrapper"
    
    # Calamares config logger for debugging
    cp "${PROJECT_ROOT}/scripts/calamares-config-logger.sh" "${CHROOT_DIR}/usr/local/bin/calamares-config-logger.sh"
    chmod +x "${CHROOT_DIR}/usr/local/bin/calamares-config-logger.sh"
    
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
    
    # Install systemd tmpfiles configuration for XDG_RUNTIME_DIR
    log "INFO" "Installing systemd tmpfiles configuration..."
    mkdir -p "${CHROOT_DIR}/etc/tmpfiles.d"
    cp "${PROJECT_ROOT}/configs/system/xdg-runtime-root.conf" "${CHROOT_DIR}/etc/tmpfiles.d/"
    chmod 644 "${CHROOT_DIR}/etc/tmpfiles.d/xdg-runtime-root.conf"
    
    log "INFO" "  ✓ Workspace Manager installed"
    log "INFO" "  ✓ Firejail integration installed"
    log "INFO" "  ✓ XDG runtime directory configuration installed"
    
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
    mkdir -p "${ISO_DIR}/EFI/boot"
    
    # Create squashfs filesystem
    log "INFO" "Creating squashfs filesystem (this may take several minutes)..."
    mksquashfs "${CHROOT_DIR}" "${SQUASHFS_DIR}/filesystem.squashfs" \
        -comp xz \
        -b 1M \
        -Xdict-size 100% \
        -noappend
    
    # Copy kernel and initrd
    log "INFO" "Copying kernel and initrd..."
    
    # Find kernel and initrd files
    KERNEL_FILE=$(ls "${CHROOT_DIR}/boot/vmlinuz-"* 2>/dev/null | head -1)
    INITRD_FILE=$(ls "${CHROOT_DIR}/boot/initrd.img-"* 2>/dev/null | head -1)
    
    if [ -z "${KERNEL_FILE}" ]; then
        log "ERROR" "Kernel not found in ${CHROOT_DIR}/boot/"
        log "ERROR" "Available files:"
        ls -la "${CHROOT_DIR}/boot/" || true
        exit 1
    fi
    
    if [ -z "${INITRD_FILE}" ]; then
        log "ERROR" "Initrd not found in ${CHROOT_DIR}/boot/"
        log "ERROR" "Available files:"
        ls -la "${CHROOT_DIR}/boot/" || true
        exit 1
    fi
    
    log "INFO" "Found kernel: $(basename ${KERNEL_FILE})"
    log "INFO" "Found initrd: $(basename ${INITRD_FILE})"
    
    cp "${KERNEL_FILE}" "${ISO_DIR}/boot/vmlinuz"
    cp "${INITRD_FILE}" "${ISO_DIR}/boot/initrd.img"
    
    # Verify files were copied
    if [ ! -f "${ISO_DIR}/boot/vmlinuz" ] || [ ! -f "${ISO_DIR}/boot/initrd.img" ]; then
        log "ERROR" "Failed to copy kernel or initrd to ISO"
        exit 1
    fi
    
    log "INFO" "✓ Kernel and initrd copied successfully"
    
    # Create GRUB configuration for BIOS
    if [ "$BUILD_TYPE" = "installer" ]; then
        cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
# Root device is set by embedded.cfg via search
set timeout=3
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Installer" {
    linux /boot/vmlinuz boot=live components quiet splash username=installer
    initrd /boot/initrd.img
}

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Installer (Safe Mode)" {
    linux /boot/vmlinuz boot=live components nomodeset username=installer
    initrd /boot/initrd.img
}
EOF
    else
        cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
# Root device is set by embedded.cfg via search
set timeout=3
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Live" {
    linux /boot/vmlinuz boot=live components quiet splash username=live
    initrd /boot/initrd.img
}

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Live (Safe Mode)" {
    linux /boot/vmlinuz boot=live components nomodeset username=live
    initrd /boot/initrd.img
}
EOF
    fi
    
    # Create GRUB configuration for UEFI (same content, different location)
    mkdir -p "${ISO_DIR}/EFI/boot"
    cp "${ISO_DIR}/boot/grub/grub.cfg" "${ISO_DIR}/EFI/boot/grub.cfg"
    
    # Create GRUB standalone image for BIOS boot
    log "INFO" "Creating GRUB boot images..."
    
    # ⚠️ CRITICAL: DO NOT MODIFY THIS GRUB EMBEDDED CONFIG ⚠️
    # This configuration has been fixed multiple times. The sequential approach
    # (no conditionals) is the ONLY method that works reliably across all platforms.
    # 
    # WHY THIS WORKS:
    # - GRUB silently fails on invalid devices and continues to next command
    # - No conditionals needed - just try each device in sequence
    # - Works on QEMU (cd), VirtualBox (cd0), and physical hardware
    # 
    # WHAT DOESN'T WORK:
    # - Conditionals like "if [ -e (cd)/... ]" - modules not loaded yet
    # - Search commands - too slow and unreliable in embedded config
    # - Absolute paths to config files outside ISO directory
    # 
    # See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md
    cat > "${ISO_DIR}/boot/grub/embedded.cfg" << 'EOF'
# Try to load grub.cfg from common CD device names
# GRUB will silently fail and try the next one if a device doesn't exist
set root=(cd)
configfile (cd)/boot/grub/grub.cfg
set root=(cd0)
configfile (cd0)/boot/grub/grub.cfg
set root=(cd1)
configfile (cd1)/boot/grub/grub.cfg
# If we get here, none worked - drop to rescue shell
echo "Error: Could not find grub.cfg on any CD device"
echo "Available devices:"
ls
EOF
    
    # Change to ISO directory so relative paths work correctly
    cd "${ISO_DIR}"
    
    grub-mkstandalone \
        --format=i386-pc \
        --output="boot/grub/core.img" \
        --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt" \
        --modules="linux normal iso9660 biosdisk memdisk search search_fs_file configfile part_msdos part_gpt" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=boot/grub/embedded.cfg"
    
    # Return to original directory
    cd - > /dev/null
    
    # Return to original directory
    cd - > /dev/null
    
    # Combine with GRUB boot sector
    cat /usr/lib/grub/i386-pc/cdboot.img "${ISO_DIR}/boot/grub/core.img" > "${ISO_DIR}/boot/grub/bios.img"
    
    # Create embedded GRUB config for EFI (same logic as BIOS)
    # ⚠️ CRITICAL: Keep this identical to BIOS embedded config ⚠️
    cat > "${ISO_DIR}/EFI/boot/embedded.cfg" << 'EOF'
# Try to load grub.cfg from common CD device names
set root=(cd)
configfile (cd)/boot/grub/grub.cfg
set root=(cd0)
configfile (cd0)/boot/grub/grub.cfg
set root=(cd1)
configfile (cd1)/boot/grub/grub.cfg
echo "Error: Could not find grub.cfg on any CD device"
echo "Available devices:"
ls
EOF
    
    # Create GRUB EFI image
    mkdir -p "${ISO_DIR}/EFI/BOOT"
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" \
        --install-modules="linux normal iso9660 efi_gop efi_uga search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt echo test read" \
        --modules="linux normal iso9660 efi_gop efi_uga search search_fs_file configfile part_msdos part_gpt echo test read" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=${ISO_DIR}/EFI/boot/embedded.cfg"
    
    # Create FAT EFI boot image
    log "INFO" "Creating EFI boot image..."
    dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10
    mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"
    
    # Mount and populate EFI image with canonical paths
    local EFI_MOUNT="${WORK_DIR}/efi_mount"
    mkdir -p "${EFI_MOUNT}"
    mount -o loop "${ISO_DIR}/boot/grub/efi.img" "${EFI_MOUNT}"
    
    mkdir -p "${EFI_MOUNT}/EFI/BOOT"
    cp "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" "${EFI_MOUNT}/EFI/BOOT/"
    cp "${ISO_DIR}/boot/grub/grub.cfg" "${EFI_MOUNT}/EFI/BOOT/"
    
    umount "${EFI_MOUNT}"
    rmdir "${EFI_MOUNT}"
    
    # Create ISO
    log "INFO" "Generating ISO file..."
    mkdir -p "${OUTPUT_DIR}"
    
    local ISO_FILE="${OUTPUT_DIR}/${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso"
    
    # Create hybrid BIOS/UEFI bootable ISO
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${DISTRO_NAME}-${DISTRO_VERSION}" \
        -output "${ISO_FILE}" \
        -eltorito-boot boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/boot.cat \
        --grub2-boot-info \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -append_partition 2 0xef "${ISO_DIR}/boot/grub/efi.img" \
        -partition_offset 16 \
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
