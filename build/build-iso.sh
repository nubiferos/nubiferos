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
MINIMAL_TEST=false

# NubiferOS only builds installer-only ISOs (live CD removed for security)
BUILD_TYPE="installer"

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
        --minimal)
            MINIMAL_TEST=true
            shift
            ;;
        --help)
            cat << EOF
NubiferOS ISO Build Script

Usage: $0 [options]

Options:
  --enable-tests     Enable post-installation testing
  --skip-download    Skip Debian ISO download (use existing)
  --minimal          Build minimal ISO for faster testing (no GNOME)
  --help             Show this help message

Notes:
  NubiferOS only builds installer-only ISOs for security reasons.
  The live CD functionality has been removed to prevent bypass of
  disk encryption via physical access.

Examples:
  sudo $0                         # Build production ISO
  sudo $0 --skip-download         # Build using existing base

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
log "INFO" "Build Type: Installer-Only ISO (Production)"
log "INFO" "Security: Minimal attack surface, mandatory encryption"
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
    if [ "$MINIMAL_TEST" = true ]; then
        log "INFO" "Step 4/7: Skipping GNOME desktop (--minimal mode for testing)"
        # Install minimal X and window manager for Calamares
        chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
            xorg \
            openbox \
            calamares"
    else
        log "INFO" "Step 4/7: Installing GNOME desktop (installer-only)..."
        "${SCRIPT_DIR}/install-desktop-installer.sh"
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
    log "INFO" "Step 6.6/8: Configuring installer auto-start..."
    "${SCRIPT_DIR}/configure-installer-autostart.sh"

    # Step 6.7: Configure NubiferOS branding
    log "INFO" "Step 6.7/8: Configuring system branding..."
    "${SCRIPT_DIR}/configure-branding.sh"

    # Step 6.8: Configure Plymouth boot splash
    log "INFO" "Step 6.8/8: Configuring Plymouth boot splash..."
    "${SCRIPT_DIR}/configure-plymouth.sh"

    # Step 6.9: Install branding assets (wallpapers, icons)
    log "INFO" "Step 6.9/8: Installing branding assets..."
    "${SCRIPT_DIR}/install-branding-assets.sh"

    # Step 7: Install NubiferOS components
    log "INFO" "Step 7/8: Installing NubiferOS components..."
    install_nubifer_components

    # Step 7.5: Install first-boot wizard
    log "INFO" "Step 7.5/8: Installing first-boot wizard..."
    "${SCRIPT_DIR}/install-first-boot-wizard.sh"
    
    # Step 7.6: Security cleanup - remove packages with known CVEs
    log "INFO" "Step 7.6/8: Running security cleanup..."
    "${SCRIPT_DIR}/security-cleanup.sh"
    
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
    
    # Update checker (bash version)
    cp "${PROJECT_ROOT}/scripts/nubifer-update-checker" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-update-checker"
    
    # Update checker (Python version with version comparison)
    cp "${PROJECT_ROOT}/scripts/nubifer-check-updates" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-check-updates"
    
    # Tools configuration for update checker
    mkdir -p "${CHROOT_DIR}/usr/share/nubifer"
    cp "${PROJECT_ROOT}/scripts/tools-config.yaml" "${CHROOT_DIR}/usr/share/nubifer/"
    
    # Security scanner
    cp "${PROJECT_ROOT}/scripts/nubifer-security-scan" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-security-scan"
    
    # Man pages
    mkdir -p "${CHROOT_DIR}/usr/share/man/man1"
    if [ -f "${PROJECT_ROOT}/docs/man/nubifer-security-scan.1" ]; then
        cp "${PROJECT_ROOT}/docs/man/nubifer-security-scan.1" "${CHROOT_DIR}/usr/share/man/man1/"
        gzip -f "${CHROOT_DIR}/usr/share/man/man1/nubifer-security-scan.1" 2>/dev/null || true
    fi
    
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
    
    # Copy version information
    mkdir -p "${CHROOT_DIR}/usr/share/nubifer"
    local VERSION=$(cat "${PROJECT_ROOT}/VERSION" | tr -d '\n')
    local GIT_COMMIT=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local BUILD_DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    
    cat > "${CHROOT_DIR}/usr/share/nubifer/VERSION.txt" << EOF
NubiferOS System Information
=============================
Version: ${VERSION}
Git Commit: ${GIT_COMMIT}
Build Date: ${BUILD_DATE}

Check for updates:
  /usr/local/bin/nubifer-update-checker
EOF
    
    # Copy browser configuration
    mkdir -p "${CHROOT_DIR}/usr/share/nubifer/browser"
    cp "${PROJECT_ROOT}/configs/browser/firefox-bookmarks.json" "${CHROOT_DIR}/usr/share/nubifer/browser/"
    cp "${PROJECT_ROOT}/configs/browser/firefox-hardening.js" "${CHROOT_DIR}/usr/share/nubifer/browser/"
    
    # Create Firefox ESR policy with bookmarks
    log "INFO" "Creating Firefox ESR policy with bookmarks..."
    mkdir -p "${CHROOT_DIR}/etc/firefox-esr/policies"
    
    # Convert bookmarks JSON to Firefox ManagedBookmarks policy format
    python3 << 'PYTHON_SCRIPT'
import json
import os

chroot_dir = os.environ.get('CHROOT_DIR', '')

# Read our bookmarks
bookmarks_file = f"{chroot_dir}/usr/share/nubifer/browser/firefox-bookmarks.json"
with open(bookmarks_file) as f:
    bookmarks = json.load(f)

def convert_children(children):
    """Convert child items to Firefox format"""
    result = []
    for item in children:
        if 'children' in item:
            result.append({
                "name": item['title'],
                "children": convert_children(item['children'])
            })
        elif 'url' in item:
            result.append({
                "name": item['title'],
                "url": item['url']
            })
    return result

# Build managed bookmarks array
managed = []
for folder in bookmarks.get('children', []):
    if 'children' in folder:
        managed.append({
            "toplevel_name": folder['title'],
            "children": convert_children(folder['children'])
        })

# Create Firefox policy
policy = {
    "policies": {
        "DisableTelemetry": True,
        "DisableFirefoxStudies": True,
        "DisablePocket": True,
        "DontCheckDefaultBrowser": True,
        "EnableTrackingProtection": {
            "Value": True,
            "Cryptomining": True,
            "Fingerprinting": True
        },
        "FirefoxHome": {
            "Pocket": False,
            "Snippets": False
        },
        "ManagedBookmarks": managed,
        "NoDefaultBookmarks": False,
        "SearchEngines": {
            "Default": "DuckDuckGo"
        }
    }
}

# Write policy file
policy_file = f"{chroot_dir}/etc/firefox-esr/policies/policies.json"
with open(policy_file, 'w') as f:
    json.dump(policy, f, indent=2)

print(f"Created Firefox policy with {len(managed)} bookmark folders")
PYTHON_SCRIPT
    
    log "INFO" "✓ Firefox ESR policy created with cloud bookmarks"
    
    # Install Workspace Manager
    log "INFO" "Installing Workspace Manager..."
    
    # Copy workspace manager
    cp "${PROJECT_ROOT}/components/workspace-manager/nubifer-workspace" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-workspace"
    
    # Install Context Manager D-Bus service
    log "INFO" "Installing Context Manager D-Bus service..."
    
    # Install Python D-Bus dependencies
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y python3-dbus python3-gi wmctrl"
    
    # Copy context manager source files
    mkdir -p "${CHROOT_DIR}/usr/local/lib/nubiferos/context-manager"
    cp "${PROJECT_ROOT}/components/context-manager/src/"*.py "${CHROOT_DIR}/usr/local/lib/nubiferos/context-manager/"
    
    # Copy GNOME desktop integration
    cp "${PROJECT_ROOT}/components/workspace-manager/gnome-desktop-integration.py" "${CHROOT_DIR}/usr/local/lib/nubiferos/"
    chmod +x "${CHROOT_DIR}/usr/local/lib/nubiferos/gnome-desktop-integration.py"
    
    # Create D-Bus service wrapper
    cat > "${CHROOT_DIR}/usr/local/bin/nubifer-context-service" << 'DBUS_EOF'
#!/bin/bash
# NubiferOS Context Manager D-Bus service wrapper
INSTALL_DIR="/usr/local/lib/nubiferos/context-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"
exec python3 "$INSTALL_DIR/dbus_interface.py" "$@"
DBUS_EOF
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-context-service"
    
    # Create GNOME desktop integration wrapper
    cat > "${CHROOT_DIR}/usr/local/bin/nubifer-desktop" << 'DESKTOP_EOF'
#!/bin/bash
# NubiferOS GNOME Desktop Integration wrapper
exec python3 /usr/local/lib/nubiferos/gnome-desktop-integration.py "$@"
DESKTOP_EOF
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-desktop"
    
    # Install D-Bus service file for session bus (auto-activation)
    mkdir -p "${CHROOT_DIR}/usr/share/dbus-1/services"
    cat > "${CHROOT_DIR}/usr/share/dbus-1/services/org.nubiferos.ContextManager.service" << 'DBUS_SVC_EOF'
[D-BUS Service]
Name=org.nubiferos.ContextManager
Exec=/usr/local/bin/nubifer-context-service
DBUS_SVC_EOF
    
    # Install systemd user service
    mkdir -p "${CHROOT_DIR}/usr/lib/systemd/user"
    cp "${PROJECT_ROOT}/components/context-manager/systemd/nubifer-context-manager.service" "${CHROOT_DIR}/usr/lib/systemd/user/"
    
    # Enable Context Manager service for all users by default
    mkdir -p "${CHROOT_DIR}/etc/systemd/user/default.target.wants"
    ln -sf /usr/lib/systemd/user/nubifer-context-manager.service "${CHROOT_DIR}/etc/systemd/user/default.target.wants/nubifer-context-manager.service"
    
    log "INFO" "  ✓ Context Manager D-Bus service installed"
    log "INFO" "  ✓ GNOME desktop integration installed"
    log "INFO" "  ✓ Context Manager auto-start enabled"
    
    # Install AWS credential helper
    log "INFO" "Installing AWS credential helper..."
    cp "${PROJECT_ROOT}/components/credential-manager/nubifer-aws-credential-helper" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-aws-credential-helper"
    log "INFO" "  ✓ AWS credential helper installed"
    
    # Copy shell integration
    mkdir -p "${CHROOT_DIR}/etc/nubifer"
    cp "${PROJECT_ROOT}/components/workspace-manager/shell-integration.sh" "${CHROOT_DIR}/etc/nubifer/"
    chmod 644 "${CHROOT_DIR}/etc/nubifer/shell-integration.sh"
    
    # Install NubiferOS configuration files
    log "INFO" "Installing NubiferOS configuration files..."
    mkdir -p "${CHROOT_DIR}/etc/nubiferos/providers"
    cp "${PROJECT_ROOT}/configs/nubiferos/nubiferos.conf" "${CHROOT_DIR}/etc/nubiferos/"
    cp "${PROJECT_ROOT}/configs/nubiferos/providers/"*.conf "${CHROOT_DIR}/etc/nubiferos/providers/"
    chmod 644 "${CHROOT_DIR}/etc/nubiferos/"*.conf
    chmod 644 "${CHROOT_DIR}/etc/nubiferos/providers/"*.conf
    
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
    
    # Install NubiferOS Software Center
    log "INFO" "Installing NubiferOS Software Center..."
    cp "${PROJECT_ROOT}/components/software-center/nubifer-software" "${CHROOT_DIR}/usr/bin/"
    chmod +x "${CHROOT_DIR}/usr/bin/nubifer-software"
    cp "${PROJECT_ROOT}/components/software-center/nubifer-software.desktop" "${CHROOT_DIR}/usr/share/applications/"
    
    # Install NubiferOS Security Dashboard
    log "INFO" "Installing NubiferOS Security Dashboard..."
    cp "${PROJECT_ROOT}/components/security-dashboard/nubifer-dashboard" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-dashboard"
    cp "${PROJECT_ROOT}/components/security-dashboard/nubifer-dashboard.desktop" "${CHROOT_DIR}/usr/share/applications/"
    # Autostart dashboard on first login after setup wizard completes
    cp "${PROJECT_ROOT}/components/security-dashboard/nubifer-dashboard-autostart.desktop" "${CHROOT_DIR}/etc/xdg/autostart/"
    log "INFO" "  ✓ Security Dashboard installed"
    
    # Install tool installer scripts
    mkdir -p "${CHROOT_DIR}/usr/share/nubiferos/installers"
    for script in "${PROJECT_ROOT}/scripts/installers/"*.sh; do
        if [ -f "$script" ]; then
            cp "$script" "${CHROOT_DIR}/usr/share/nubiferos/installers/"
            chmod +x "${CHROOT_DIR}/usr/share/nubiferos/installers/$(basename "$script")"
        fi
    done
    log "INFO" "  ✓ Software Center installed"
    
    # Install Cloud Tools Launcher
    log "INFO" "Installing Cloud Tools Launcher..."
    cp "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools" "${CHROOT_DIR}/usr/local/bin/"
    chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-tools"
    cp "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools.desktop" "${CHROOT_DIR}/usr/share/applications/"
    log "INFO" "  ✓ Cloud Tools Launcher installed"
    
    # Install desktop integration (menu categories, cloud console launchers)
    log "INFO" "Installing desktop integration..."
    
    # Create directories
    mkdir -p "${CHROOT_DIR}/usr/share/desktop-directories"
    mkdir -p "${CHROOT_DIR}/etc/xdg/menus/applications-merged"
    mkdir -p "${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps"
    
    # Install menu category directories
    for dir_file in "${PROJECT_ROOT}/configs/desktop/applications/"*.directory; do
        if [ -f "$dir_file" ]; then
            cp "$dir_file" "${CHROOT_DIR}/usr/share/desktop-directories/"
        fi
    done
    
    # Install menu configuration
    if [ -f "${PROJECT_ROOT}/configs/desktop/menus/nubiferos-applications.menu" ]; then
        cp "${PROJECT_ROOT}/configs/desktop/menus/nubiferos-applications.menu" \
           "${CHROOT_DIR}/etc/xdg/menus/applications-merged/"
    fi
    
    # Install cloud console desktop launchers
    for desktop_file in "${PROJECT_ROOT}/configs/desktop/applications/"*.desktop; do
        if [ -f "$desktop_file" ]; then
            cp "$desktop_file" "${CHROOT_DIR}/usr/share/applications/"
        fi
    done
    
    # Install custom icons (cloud providers, tools)
    for icon_file in "${PROJECT_ROOT}/brand/icons/"*.svg; do
        if [ -f "$icon_file" ]; then
            cp "$icon_file" "${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps/"
        fi
    done
    
    # Update icon cache and desktop database
    chroot_exec "gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true"
    chroot_exec "update-desktop-database /usr/share/applications 2>/dev/null || true"
    
    log "INFO" "  ✓ Desktop integration installed (menu categories, cloud consoles)"
    
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
    
    # Create version info file in ISO
    local VERSION=$(cat "${PROJECT_ROOT}/VERSION" | tr -d '\n')
    local GIT_COMMIT=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local BUILD_DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    
    cat > "${ISO_DIR}/VERSION.txt" << EOF
NubiferOS ISO Build Information
================================
Version: ${VERSION}
Git Commit: ${GIT_COMMIT}
Build Date: ${BUILD_DATE}
Build Host: $(hostname)

To check version from live CD:
  cat /run/live/medium/VERSION.txt

To check version from installed system:
  cat /usr/share/nubifer/VERSION.txt
EOF
    
    log "INFO" "ISO Version: ${VERSION} (${GIT_COMMIT})"
    
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
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
# Root device is set by embedded.cfg via search
set timeout=3
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Install" {
    linux /boot/vmlinuz boot=live components quiet splash username=installer
    initrd /boot/initrd.img
}

menuentry "${DISTRO_FULLNAME} ${DISTRO_VERSION} - Install (Safe Mode)" {
    linux /boot/vmlinuz boot=live components nomodeset username=installer
    initrd /boot/initrd.img
}
EOF
    
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
    
    # Get version and git commit for filename
    local VERSION=$(cat "${PROJECT_ROOT}/VERSION" | tr -d '\n')
    local GIT_COMMIT=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local BUILD_DATE=$(date +%Y%m%d)
    
    local ISO_FILE="${OUTPUT_DIR}/${DISTRO_NAME}-${VERSION}-${BUILD_DATE}-${GIT_COMMIT}-amd64.iso"
    
    log "INFO" "ISO version: ${VERSION}"
    log "INFO" "Git commit: ${GIT_COMMIT}"
    log "INFO" "Build date: ${BUILD_DATE}"
    log "INFO" "ISO file: ${ISO_FILE}"
    
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
