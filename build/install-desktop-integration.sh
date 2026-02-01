#!/bin/bash
# Install NubiferOS desktop integration
# - Menu categories (like Kali)
# - Cloud console launchers
# - Tool launcher GUI
# - Custom icons

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Directories
WORK_DIR="${PROJECT_ROOT}/work"
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

main() {
    log "INFO" "=========================================="
    log "INFO" "Installing NubiferOS Desktop Integration"
    log "INFO" "=========================================="
    
    # Create directories in chroot
    log "INFO" "Creating directories..."
    chroot_exec "mkdir -p /usr/share/desktop-directories"
    chroot_exec "mkdir -p /usr/share/applications"
    chroot_exec "mkdir -p /etc/xdg/menus/applications-merged"
    chroot_exec "mkdir -p /usr/share/icons/hicolor/scalable/apps"
    chroot_exec "mkdir -p /usr/local/bin"
    
    # ==========================================
    # Install directory entries (menu categories)
    # ==========================================
    log "INFO" "Installing menu categories..."
    
    for dir_file in "${PROJECT_ROOT}/configs/desktop/applications/"*.directory; do
        if [ -f "$dir_file" ]; then
            filename=$(basename "$dir_file")
            cp "$dir_file" "${CHROOT_DIR}/usr/share/desktop-directories/$filename"
            log "INFO" "  Installed: $filename"
        fi
    done
    
    # ==========================================
    # Install menu file
    # ==========================================
    log "INFO" "Installing menu configuration..."
    
    if [ -f "${PROJECT_ROOT}/configs/desktop/menus/nubiferos-applications.menu" ]; then
        cp "${PROJECT_ROOT}/configs/desktop/menus/nubiferos-applications.menu" \
           "${CHROOT_DIR}/etc/xdg/menus/applications-merged/"
        log "INFO" "  Installed: nubiferos-applications.menu"
    fi
    
    # ==========================================
    # Install desktop files (launchers)
    # ==========================================
    log "INFO" "Installing application launchers..."
    
    for desktop_file in "${PROJECT_ROOT}/configs/desktop/applications/"*.desktop; do
        if [ -f "$desktop_file" ]; then
            filename=$(basename "$desktop_file")
            cp "$desktop_file" "${CHROOT_DIR}/usr/share/applications/$filename"
            log "INFO" "  Installed: $filename"
        fi
    done
    
    # ==========================================
    # Install Cloud Tools Launcher
    # ==========================================
    log "INFO" "Installing Cloud Tools Launcher..."
    
    if [ -f "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools" ]; then
        cp "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools" \
           "${CHROOT_DIR}/usr/local/bin/nubifer-tools"
        chmod +x "${CHROOT_DIR}/usr/local/bin/nubifer-tools"
        log "INFO" "  Installed: nubifer-tools"
    fi
    
    if [ -f "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools.desktop" ]; then
        cp "${PROJECT_ROOT}/components/cloud-tools-launcher/nubifer-tools.desktop" \
           "${CHROOT_DIR}/usr/share/applications/"
        log "INFO" "  Installed: nubifer-tools.desktop"
    fi
    
    # ==========================================
    # Install custom icons
    # ==========================================
    log "INFO" "Installing custom icons..."
    
    # Copy NubiferOS logo as icon
    if [ -f "${PROJECT_ROOT}/brand/logo.svg" ]; then
        cp "${PROJECT_ROOT}/brand/logo.svg" \
           "${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps/nubiferos.svg"
        log "INFO" "  Installed: nubiferos.svg"
    fi
    
    # Create simple cloud provider icons if not present
    # These are placeholders - real icons should be added to brand/icons/
    for provider in aws azure google-cloud oracle terraform kubernetes docker podman helm; do
        icon_path="${CHROOT_DIR}/usr/share/icons/hicolor/scalable/apps/${provider}.svg"
        if [ ! -f "$icon_path" ]; then
            # Check if we have a custom icon
            if [ -f "${PROJECT_ROOT}/brand/icons/${provider}.svg" ]; then
                cp "${PROJECT_ROOT}/brand/icons/${provider}.svg" "$icon_path"
                log "INFO" "  Installed: ${provider}.svg"
            fi
        fi
    done
    
    # ==========================================
    # Update icon cache
    # ==========================================
    log "INFO" "Updating icon cache..."
    chroot_exec "gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true"
    
    # ==========================================
    # Update desktop database
    # ==========================================
    log "INFO" "Updating desktop database..."
    chroot_exec "update-desktop-database /usr/share/applications 2>/dev/null || true"
    
    log "INFO" ""
    log "INFO" "=========================================="
    log "INFO" "Desktop Integration Complete"
    log "INFO" "=========================================="
    log "INFO" ""
    log "INFO" "Installed:"
    log "INFO" "  - Menu categories (Cloud Providers, Kubernetes, etc.)"
    log "INFO" "  - Cloud console launchers (AWS, Azure, GCP, Oracle)"
    log "INFO" "  - Tool launchers (k9s, Terraform Registry, etc.)"
    log "INFO" "  - Cloud Tools Launcher GUI (nubifer-tools)"
    log "INFO" ""
}

main "$@"
