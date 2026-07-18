#!/bin/bash
# NubiferOS Build Configuration
# This file contains all configuration parameters for building NubiferOS

# ============================================================================
# Load Brand Configuration
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_ROOT}/brand/brand.conf"

# ============================================================================
# Distribution Information
# ============================================================================
DISTRO_NAME="${BRAND_NAME}"
DISTRO_VERSION=$(cat "${PROJECT_ROOT}/VERSION" 2>/dev/null | tr -d '\n')
DISTRO_VERSION="${DISTRO_VERSION:-${BRAND_VERSION}}"
DISTRO_CODENAME="${BRAND_CODENAME}"
DISTRO_DESCRIPTION="${BRAND_TAGLINE}"

# ============================================================================
# Base Distribution Settings
# ============================================================================
BASE_DISTRO="debian"
BASE_VERSION="12"  # Debian 12 (Bookworm)
BASE_CODENAME="bookworm"
ARCH="amd64"  # Debian uses 'amd64' not 'x86_64'
DEBIAN_MIRROR="https://deb.debian.org/debian"
DEBIAN_SECURITY="https://security.debian.org/debian-security"

# ============================================================================
# Desktop Environment
# ============================================================================
DESKTOP="gnome"
DESKTOP_VERSION="43"

# ============================================================================
# Security Configuration
# ============================================================================
SECURITY_LEVEL="hardened"
ENABLE_FULL_DISK_ENCRYPTION=true
ENABLE_SECURE_BOOT=true
ENABLE_APPARMOR=true
ENABLE_FIREWALL=true
ENABLE_AUTO_UPDATES=true
ENABLE_AUDIT_LOGGING=true
ENABLE_FAIL2BAN=true

# ============================================================================
# Build Paths
# ============================================================================
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
COMPONENTS_DIR="${PROJECT_ROOT}/components"
CONFIGS_DIR="${PROJECT_ROOT}/configs"
INSTALLER_DIR="${PROJECT_ROOT}/installer"
ISO_DIR="${PROJECT_ROOT}/iso"
OUTPUT_DIR="${PROJECT_ROOT}/output"
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

# ============================================================================
# Component Versions
# ============================================================================
CREDENTIAL_MANAGER_VERSION="1.0.0"
CONTEXT_MANAGER_VERSION="1.0.0"
RESOURCE_VIEWER_VERSION="1.0.0"
CONTEXT_INDICATOR_VERSION="1.0.0"

# ============================================================================
# Component Paths
# ============================================================================
CREDENTIAL_MANAGER_SRC="${COMPONENTS_DIR}/credential-manager/src"
CREDENTIAL_MANAGER_CONFIG="${COMPONENTS_DIR}/credential-manager/config"
CREDENTIAL_MANAGER_SYSTEMD="${COMPONENTS_DIR}/credential-manager/systemd"

CONTEXT_MANAGER_SRC="${COMPONENTS_DIR}/context-manager/src"
CONTEXT_MANAGER_DBUS="${COMPONENTS_DIR}/context-manager/dbus"
CONTEXT_MANAGER_SYSTEMD="${COMPONENTS_DIR}/context-manager/systemd"

RESOURCE_VIEWER_SRC="${COMPONENTS_DIR}/resource-viewer/src"

CONTEXT_INDICATOR_GNOME="${COMPONENTS_DIR}/context-indicator/gnome-extension"
CONTEXT_INDICATOR_KDE="${COMPONENTS_DIR}/context-indicator/kde-plasmoid"

# ============================================================================
# Cloud Tools Versions
# ============================================================================
AWS_CLI_VERSION="latest"
AZURE_CLI_VERSION="latest"
GCLOUD_SDK_VERSION="latest"
TERRAFORM_VERSION="latest"
PULUMI_VERSION="latest"
KUBECTL_VERSION="latest"
HELM_VERSION="latest"

# ============================================================================
# ISO Build Settings
# ============================================================================
ISO_NAME="${DISTRO_NAME}-${DISTRO_VERSION}-${ARCH}.iso"
ISO_LABEL="${DISTRO_NAME}_${DISTRO_VERSION}"
ISO_VOLUME_ID="${DISTRO_NAME}"

# ============================================================================
# Installation Settings
# ============================================================================
INSTALLER_FRAMEWORK="calamares"
DEFAULT_HOSTNAME="${BRAND_CLI_NAME}"
DEFAULT_USERNAME="${BRAND_CLI_NAME}user"

# ============================================================================
# Package Lists
# ============================================================================

# Base system packages
BASE_PACKAGES=(
    "linux-image-amd64"
    "linux-headers-amd64"
    "systemd"
    "udev"
    "dbus"
    "network-manager"
    "sudo"
    "bash-completion"
    "vim"
    "nano"
    "curl"
    "wget"
    "git"
    "gnupg"
    "ca-certificates"
    "apt-transport-https"
)

# Desktop environment packages
DESKTOP_PACKAGES=(
    "gnome-core"
    "gnome-shell"
    "gnome-terminal"
    "gnome-keyring"
    "nautilus"
    "gdm3"
    "xorg"
    "xserver-xorg-core"
)

# Security packages
SECURITY_PACKAGES=(
    "apparmor"
    "apparmor-utils"
    "apparmor-profiles"
    "fail2ban"
    "ufw"
    "unattended-upgrades"
    "auditd"
    "cryptsetup"
    "cryptsetup-initramfs"
    "pass"
    "gnupg"
    "python3-keyring"
    "python3-secretstorage"
    "tpm2-tools"
    "clevis"
    "clevis-tpm2"
    "clevis-luks"
    "clevis-initramfs"
)

# Development and build tools
DEV_PACKAGES=(
    "build-essential"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "python3-dbus"
    "python3-gi"
    "nodejs"
    "npm"
    "golang"
    "sqlite3"
    "libsqlite3-dev"
    "libsecret-1-dev"
    "libdbus-1-dev"
)

# Cloud tools dependencies
CLOUD_DEPS=(
    "jq"
    "unzip"
    "tar"
    "gzip"
    "python3-boto3"
    "python3-azure"
    "docker.io"
    "podman"
)

# ============================================================================
# Build Options
# ============================================================================
ENABLE_DEBUG=false
CLEAN_BUILD=true
VERIFY_CHECKSUMS=true
SIGN_ISO=true
GPG_KEY_ID=""

# ============================================================================
# Logging Configuration
# ============================================================================
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=true

# ============================================================================
# Functions
# ============================================================================

# Create necessary directories
init_build_dirs() {
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${ISO_DIR}"
    mkdir -p "${LOG_DIR}"
}

# Log message with timestamp
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Function to run commands in chroot
chroot_exec() {
    chroot "${CHROOT_DIR}" /bin/bash -c "$*"
}

# Export all configuration variables
export_config() {
    export DISTRO_NAME DISTRO_VERSION DISTRO_CODENAME
    export BASE_DISTRO BASE_VERSION BASE_CODENAME ARCH
    export DESKTOP DESKTOP_VERSION
    export SECURITY_LEVEL
    export PROJECT_ROOT BUILD_DIR COMPONENTS_DIR CONFIGS_DIR INSTALLER_DIR ISO_DIR OUTPUT_DIR
    export CREDENTIAL_MANAGER_VERSION CONTEXT_MANAGER_VERSION RESOURCE_VIEWER_VERSION
    export ISO_NAME ISO_LABEL ISO_VOLUME_ID
}

# Validate configuration
validate_config() {
    log "INFO" "Validating build configuration..."
    
    # Check required directories exist
    if [ ! -d "${PROJECT_ROOT}" ]; then
        log "ERROR" "Project root directory not found: ${PROJECT_ROOT}"
        return 1
    fi
    
    # Check architecture
    if [ "${ARCH}" != "amd64" ] && [ "${ARCH}" != "arm64" ]; then
        log "ERROR" "Unsupported architecture: ${ARCH}"
        return 1
    fi
    
    # Check base distro
    if [ "${BASE_DISTRO}" != "debian" ] && [ "${BASE_DISTRO}" != "ubuntu" ]; then
        log "ERROR" "Unsupported base distribution: ${BASE_DISTRO}"
        return 1
    fi
    
    log "INFO" "Configuration validation passed"
    return 0
}

# Print configuration summary
print_config() {
    cat << EOF

============================================================================
${DISTRO_NAME} Build Configuration Summary
============================================================================
Distribution:     ${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})
Tagline:          ${BRAND_TAGLINE}
Base:             ${BASE_DISTRO} ${BASE_VERSION} (${BASE_CODENAME})
Architecture:     ${ARCH}
Desktop:          ${DESKTOP} ${DESKTOP_VERSION}
Security Level:   ${SECURITY_LEVEL}
Output ISO:       ${ISO_NAME}
============================================================================

EOF
}

# Initialize configuration
init_config() {
    init_build_dirs
    export_config
    validate_config
    print_config
}
