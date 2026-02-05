#!/bin/bash
# Validate kiosk mode configuration
# Part of NubiferOS build system - Kiosk Mode Implementation
#
# This script validates that all kiosk mode configuration files
# are present and correctly configured before ISO creation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

log "INFO" "=========================================="
log "INFO" "Validating Kiosk Mode Configuration"
log "INFO" "=========================================="

# Directories
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

# Verify chroot exists
if [ ! -d "${CHROOT_DIR}/bin" ]; then
    log "ERROR" "Chroot directory not found: ${CHROOT_DIR}"
    exit 1
fi

# Function to run commands in chroot
chroot_exec() {
    chroot "${CHROOT_DIR}" /bin/bash -c "$*"
}

# Track validation status
VALIDATION_PASSED=true

# Check required files exist
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "${CHROOT_DIR}${file}" ]; then
        log "INFO" "  ✓ ${description}"
    else
        log "ERROR" "  ✗ ${description} - MISSING: ${file}"
        VALIDATION_PASSED=false
    fi
}

# Check required directories exist
check_dir() {
    local dir="$1"
    local description="$2"
    
    if [ -d "${CHROOT_DIR}${dir}" ]; then
        log "INFO" "  ✓ ${description}"
    else
        log "ERROR" "  ✗ ${description} - MISSING: ${dir}"
        VALIDATION_PASSED=false
    fi
}

# Check systemd service is masked
check_masked() {
    local service="$1"
    
    if chroot_exec "systemctl is-enabled ${service} 2>/dev/null" | grep -q "masked"; then
        log "INFO" "  ✓ ${service} is masked"
    else
        log "WARN" "  ⚠ ${service} may not be masked"
    fi
}

# Check package is NOT installed
check_not_installed() {
    local package="$1"
    
    if chroot_exec "dpkg -l ${package} 2>/dev/null" | grep -q "^ii"; then
        log "ERROR" "  ✗ Forbidden package installed: ${package}"
        VALIDATION_PASSED=false
    else
        log "INFO" "  ✓ ${package} not installed"
    fi
}

# Check package IS installed
check_installed() {
    local package="$1"
    
    if chroot_exec "dpkg -l ${package} 2>/dev/null" | grep -q "^ii"; then
        log "INFO" "  ✓ ${package} installed"
    else
        log "ERROR" "  ✗ Required package missing: ${package}"
        VALIDATION_PASSED=false
    fi
}

# Validate session files
log "INFO" ""
log "INFO" "Checking session files..."
check_file "/home/installer/.bash_profile" ".bash_profile (auto-start X)"
check_file "/home/installer/.xinitrc" ".xinitrc (minimal X session)"
check_file "/home/installer/.bash_logout" ".bash_logout (fallback reboot)"

# Validate systemd configuration
log "INFO" ""
log "INFO" "Checking systemd configuration..."
check_file "/etc/systemd/system/getty@tty1.service.d/autologin.conf" "Getty auto-login config"
check_masked "getty@tty2.service"
check_masked "getty@tty3.service"
check_masked "getty@tty4.service"
check_masked "getty@tty5.service"
check_masked "getty@tty6.service"
check_masked "ctrl-alt-del.target"

# Validate X server configuration
log "INFO" ""
log "INFO" "Checking X server configuration..."
check_file "/etc/X11/xorg.conf.d/10-no-vt-switch.conf" "X server VT lockdown"

# Validate sysctl configuration
log "INFO" ""
log "INFO" "Checking sysctl configuration..."
check_file "/etc/sysctl.d/99-kiosk-lockdown.conf" "SysRq lockdown"

# Validate sudoers configuration
log "INFO" ""
log "INFO" "Checking sudoers configuration..."
check_file "/etc/sudoers.d/installer-kiosk" "Installer sudo config"

# Validate required packages
log "INFO" ""
log "INFO" "Checking required packages..."
check_installed "xserver-xorg-core"
check_installed "xinit"
check_installed "calamares"

# Validate forbidden packages
log "INFO" ""
log "INFO" "Checking forbidden packages..."
check_not_installed "gnome-shell"
check_not_installed "gnome-session"
check_not_installed "gdm3"
check_not_installed "lightdm"
check_not_installed "gnome-terminal"
check_not_installed "xterm"

# Check default systemd target
log "INFO" ""
log "INFO" "Checking systemd default target..."
DEFAULT_TARGET=$(chroot_exec "systemctl get-default")
if [ "$DEFAULT_TARGET" = "multi-user.target" ]; then
    log "INFO" "  ✓ Default target is multi-user.target"
else
    log "ERROR" "  ✗ Default target is ${DEFAULT_TARGET} (should be multi-user.target)"
    VALIDATION_PASSED=false
fi

# Final result
log "INFO" ""
log "INFO" "=========================================="
if [ "$VALIDATION_PASSED" = true ]; then
    log "INFO" "✓ Kiosk mode validation PASSED"
    log "INFO" "=========================================="
    exit 0
else
    log "ERROR" "✗ Kiosk mode validation FAILED"
    log "ERROR" "=========================================="
    log "ERROR" "Fix the issues above before building the ISO"
    exit 1
fi
