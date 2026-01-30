#!/bin/bash
# NubiferOS Security Cleanup Script
# Removes unnecessary packages that introduce CVEs without providing value
#
# This script is run after package installation to reduce attack surface
# See CHANGELOG.md for rationale on each removal

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true

# Directories
WORK_DIR="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

# Function to run commands in chroot
chroot_exec() {
    if [ -d "${CHROOT_DIR}/bin" ]; then
        chroot "${CHROOT_DIR}" /bin/bash -c "$*"
    else
        log "ERROR" "Chroot not found at ${CHROOT_DIR}"
        exit 1
    fi
}

# Remove package if installed, ignore if not
remove_if_installed() {
    local pkg="$1"
    local reason="$2"
    
    if chroot_exec "dpkg -l $pkg 2>/dev/null | grep -q '^ii'"; then
        log "INFO" "Removing $pkg: $reason"
        chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge $pkg 2>/dev/null || true"
        return 0
    else
        log "INFO" "Package $pkg not installed (skipping)"
        return 1
    fi
}

main() {
    log "INFO" "=========================================="
    log "INFO" "NubiferOS Security Cleanup"
    log "INFO" "=========================================="
    log "INFO" "Removing packages with known CVEs that are not needed"
    log "INFO" ""
    
    # ==========================================
    # FreeRDP Libraries (84 Critical CVEs)
    # ==========================================
    # gnome-remote-desktop pulls in FreeRDP but we don't need RDP support
    # in an installer ISO. Users can install it post-install if needed.
    log "INFO" "--- Removing FreeRDP (84 Critical CVEs) ---"
    remove_if_installed "gnome-remote-desktop" "RDP not needed in installer, pulls FreeRDP with 84 Critical CVEs"
    remove_if_installed "libfreerdp2-2" "FreeRDP library - CVE-2026-22852 through CVE-2026-22857"
    remove_if_installed "libfreerdp-server2-2" "FreeRDP server library"
    remove_if_installed "libwinpr2-2" "FreeRDP Windows portability library"
    
    # ==========================================
    # IPP-USB (Go 1.19.8 with 7 Critical CVEs)
    # ==========================================
    # ipp-usb is for IPP-over-USB printing. Not needed in installer.
    # Contains bundled Go 1.19.8 stdlib with CVE-2023-24531, CVE-2023-24540, etc.
    log "INFO" "--- Removing ipp-usb (Go 1.19.8 - 7 Critical CVEs) ---"
    remove_if_installed "ipp-usb" "IPP-over-USB daemon with old Go runtime (CVE-2023-24531, CVE-2024-24790)"
    
    # ==========================================
    # Build Tools (not needed in final ISO)
    # ==========================================
    # These are pulled in by linux-headers but not needed at runtime
    log "INFO" "--- Removing build tools (1676 High CVEs) ---"
    remove_if_installed "linux-kbuild-6.1" "Kernel build tools not needed at runtime"
    remove_if_installed "linux-compiler-gcc-12-x86" "Kernel compiler not needed at runtime"
    
    # ==========================================
    # Development headers (not needed in installer)
    # ==========================================
    log "INFO" "--- Removing development headers ---"
    remove_if_installed "linux-headers-amd64" "Kernel headers not needed in installer ISO"
    remove_if_installed "linux-headers-6.1.0-*" "Kernel headers not needed in installer ISO"
    
    # ==========================================
    # ImageMagick (6 Critical CVEs)
    # ==========================================
    # ImageMagick has a history of CVEs. Not needed in installer.
    log "INFO" "--- Removing ImageMagick (6 Critical CVEs) ---"
    remove_if_installed "imagemagick" "Image processing not needed in installer"
    remove_if_installed "imagemagick-6-common" "CVE-2023-5841 and others"
    remove_if_installed "libmagickcore-6.q16-6" "ImageMagick core library"
    remove_if_installed "libmagickcore-6.q16-6-extra" "ImageMagick extra codecs"
    remove_if_installed "libmagickwand-6.q16-6" "ImageMagick wand library"
    
    # ==========================================
    # PPP (2 Critical CVEs)
    # ==========================================
    # PPP is for dial-up/VPN connections. Not needed in installer.
    log "INFO" "--- Removing PPP (2 Critical CVEs) ---"
    remove_if_installed "ppp" "Point-to-Point Protocol daemon (CVE-2024-58250)"
    
    # ==========================================
    # Cleanup orphaned dependencies
    # ==========================================
    log "INFO" "--- Cleaning up orphaned dependencies ---"
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge" || true
    chroot_exec "apt-get clean" || true
    
    # ==========================================
    # Summary
    # ==========================================
    log "INFO" ""
    log "INFO" "=========================================="
    log "INFO" "Security Cleanup Complete"
    log "INFO" "=========================================="
    log "INFO" "Removed packages:"
    log "INFO" "  - gnome-remote-desktop (FreeRDP dependency - 84 Critical CVEs)"
    log "INFO" "  - libfreerdp*, libwinpr* (FreeRDP libraries)"
    log "INFO" "  - ipp-usb (Go 1.19.8 - 7 Critical CVEs)"
    log "INFO" "  - linux-kbuild, linux-compiler (build tools - 1676 High CVEs)"
    log "INFO" "  - linux-headers (development files)"
    log "INFO" "  - imagemagick (6 Critical CVEs)"
    log "INFO" "  - ppp (2 Critical CVEs)"
    log "INFO" ""
    log "INFO" "Remaining Critical CVEs are in core packages that require Debian updates:"
    log "INFO" "  - linux-kernel: Update via apt upgrade"
    log "INFO" "  - python3.11, openssl, libsoup: Await Debian security updates"
    log "INFO" ""
    log "INFO" "These packages can be installed post-install if needed:"
    log "INFO" "  apt install gnome-remote-desktop  # For RDP support"
    log "INFO" "  apt install ipp-usb               # For IPP-over-USB printing"
    log "INFO" "  apt install linux-headers-amd64   # For kernel module building"
    log "INFO" "  apt install imagemagick           # For image processing"
    log "INFO" "  apt install ppp                   # For PPP/dial-up connections"
    log "INFO" "=========================================="
}

main "$@"
