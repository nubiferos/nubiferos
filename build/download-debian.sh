#!/bin/bash
# Download and verify Debian base ISO
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

log "INFO" "Starting Debian base ISO download"

# Debian download configuration
# Using explicit version from config.sh
DEBIAN_ARCH="amd64"
DEBIAN_VERSION="${BASE_VERSION:-12}"
DEBIAN_CODENAME="${BASE_CODENAME:-bookworm}"

# Try multiple mirror paths in order of preference
# 1. Archive path for specific Debian 12 releases
# 2. Current stable symlink
DEBIAN_MIRROR_PATHS=(
    "https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}.8.0/${DEBIAN_ARCH}/iso-cd"
    "https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}.7.0/${DEBIAN_ARCH}/iso-cd"
    "https://cdimage.debian.org/cdimage/release/${DEBIAN_VERSION}.8.0/${DEBIAN_ARCH}/iso-cd"
    "https://cdimage.debian.org/cdimage/release/current/${DEBIAN_ARCH}/iso-cd"
)

# We'll discover the actual ISO name from the directory listing
# This makes the script resilient to minor version changes
DEBIAN_ISO_PATTERN="debian-*-${DEBIAN_ARCH}-netinst.iso"

# Download directory
DOWNLOAD_DIR="${PROJECT_ROOT}/downloads"
mkdir -p "${DOWNLOAD_DIR}"

CHECKSUM_PATH="${DOWNLOAD_DIR}/SHA256SUMS"
CHECKSUM_SIGN_PATH="${DOWNLOAD_DIR}/SHA256SUMS.sign"

# Function to download file with progress
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    log "INFO" "Downloading ${description}..."
    
    if [ -f "${output}" ]; then
        log "INFO" "File already exists: ${output}"
        if [ "$NON_INTERACTIVE" = "true" ]; then
            log "INFO" "Non-interactive mode: using existing file"
            return 0
        fi
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Skipping download"
            return 0
        fi
        rm -f "${output}"
    fi
    
    if command -v wget &> /dev/null; then
        wget --progress=bar:force -O "${output}" "${url}"
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar -o "${output}" "${url}"
    else
        log "ERROR" "Neither wget nor curl found. Please install one of them."
        return 1
    fi
    
    log "INFO" "Download complete: ${output}"
}

# Function to verify checksum
verify_checksum() {
    local iso_file="$1"
    local checksum_file="$2"
    
    log "INFO" "Verifying ISO checksum..."
    
    # Extract the checksum for our ISO
    local expected_checksum=$(grep "${DEBIAN_ISO_NAME}" "${checksum_file}" | awk '{print $1}')
    
    if [ -z "${expected_checksum}" ]; then
        log "ERROR" "Could not find checksum for ${DEBIAN_ISO_NAME}"
        return 1
    fi
    
    log "INFO" "Expected SHA256: ${expected_checksum}"
    
    # Calculate actual checksum
    log "INFO" "Calculating SHA256 of downloaded ISO (this may take a minute)..."
    local actual_checksum=$(sha256sum "${iso_file}" | awk '{print $1}')
    
    log "INFO" "Actual SHA256:   ${actual_checksum}"
    
    if [ "${expected_checksum}" = "${actual_checksum}" ]; then
        log "INFO" "✓ Checksum verification PASSED"
        return 0
    else
        log "ERROR" "✗ Checksum verification FAILED"
        log "ERROR" "The downloaded ISO may be corrupted or tampered with"
        return 1
    fi
}

# Function to verify GPG signature (optional but recommended)
verify_signature() {
    local checksum_file="$1"
    local signature_file="$2"
    
    log "INFO" "Verifying GPG signature..."
    
    if ! command -v gpg &> /dev/null; then
        log "WARN" "GPG not found. Skipping signature verification."
        log "WARN" "Install gnupg for enhanced security: sudo apt-get install gnupg"
        return 0
    fi
    
    # Import Debian signing keys (if not already imported)
    log "INFO" "Importing Debian signing keys..."
    gpg --keyserver keyring.debian.org --recv-keys \
        "DF9B9C49EAA9298432589D76DA87E80D6294BE9B" \
        "6294BE9B" 2>/dev/null || log "WARN" "Could not import all keys"
    
    # Verify signature
    if gpg --verify "${signature_file}" "${checksum_file}" 2>&1 | grep -q "Good signature"; then
        log "INFO" "✓ GPG signature verification PASSED"
        return 0
    else
        log "WARN" "✗ GPG signature verification FAILED or INCONCLUSIVE"
        log "WARN" "Proceeding with checksum verification only"
        return 0  # Don't fail build, just warn
    fi
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Debian Base ISO Download"
    log "INFO" "=========================================="
    log "INFO" "Target: Debian ${DEBIAN_VERSION} (${DEBIAN_CODENAME})"
    log "INFO" "Architecture: ${DEBIAN_ARCH}"
    log "INFO" "=========================================="
    
    # Try each mirror path until we find one that works
    local mirror_found=false
    local DEBIAN_MIRROR=""
    
    for mirror_path in "${DEBIAN_MIRROR_PATHS[@]}"; do
        log "INFO" "Trying mirror: ${mirror_path}"
        
        local test_url="${mirror_path}/SHA256SUMS"
        if wget --spider -q "${test_url}" 2>/dev/null || curl -s -f -I "${test_url}" >/dev/null 2>&1; then
            DEBIAN_MIRROR="${mirror_path}"
            mirror_found=true
            log "INFO" "✓ Found working mirror: ${DEBIAN_MIRROR}"
            break
        else
            log "WARN" "✗ Mirror not available: ${mirror_path}"
        fi
    done
    
    if [ "${mirror_found}" = false ]; then
        log "ERROR" "Could not find a working Debian mirror"
        log "ERROR" "Tried the following paths:"
        for mirror_path in "${DEBIAN_MIRROR_PATHS[@]}"; do
            log "ERROR" "  - ${mirror_path}"
        done
        log "ERROR" ""
        log "ERROR" "You can manually download Debian 12 netinst ISO from:"
        log "ERROR" "  https://www.debian.org/CD/netinst/"
        log "ERROR" "And place it in: ${DOWNLOAD_DIR}/"
        exit 1
    fi
    
    DEBIAN_CHECKSUM_URL="${DEBIAN_MIRROR}/SHA256SUMS"
    DEBIAN_CHECKSUM_SIGN_URL="${DEBIAN_MIRROR}/SHA256SUMS.sign"
    
    # Download checksums first to discover the actual ISO filename
    log "INFO" "Downloading checksums to discover exact Debian version..."
    download_file "${DEBIAN_CHECKSUM_URL}" "${CHECKSUM_PATH}" "SHA256 checksums"
    
    # Extract the actual ISO filename from checksums
    DEBIAN_ISO_NAME=$(grep -oP "debian-[0-9.]+-${DEBIAN_ARCH}-netinst\.iso" "${CHECKSUM_PATH}" | head -1)
    
    if [ -z "${DEBIAN_ISO_NAME}" ]; then
        log "ERROR" "Could not determine Debian ISO filename from checksums"
        exit 1
    fi
    
    DETECTED_VERSION=$(echo "${DEBIAN_ISO_NAME}" | grep -oP "[0-9.]+")
    ISO_PATH="${DOWNLOAD_DIR}/${DEBIAN_ISO_NAME}"
    DEBIAN_ISO_URL="${DEBIAN_MIRROR}/${DEBIAN_ISO_NAME}"
    
    log "INFO" "Detected version: ${DETECTED_VERSION}"
    log "INFO" "ISO filename: ${DEBIAN_ISO_NAME}"
    log "INFO" "=========================================="
    
    # Download ISO
    download_file "${DEBIAN_ISO_URL}" "${ISO_PATH}" "Debian ISO"
    
    # Download signature
    download_file "${DEBIAN_CHECKSUM_SIGN_URL}" "${CHECKSUM_SIGN_PATH}" "GPG signature"
    
    # Verify signature (optional)
    verify_signature "${CHECKSUM_PATH}" "${CHECKSUM_SIGN_PATH}"
    
    # Verify checksum (required)
    if ! verify_checksum "${ISO_PATH}" "${CHECKSUM_PATH}"; then
        log "ERROR" "ISO verification failed. Aborting."
        exit 1
    fi
    
    log "INFO" "=========================================="
    log "INFO" "Debian ISO ready: ${ISO_PATH}"
    log "INFO" "=========================================="
    
    # Save ISO path for other scripts
    echo "${ISO_PATH}" > "${DOWNLOAD_DIR}/debian-iso-path.txt"
    
    log "INFO" "Next step: Run ./build/extract-debian.sh"
}

# Run main function
main "$@"
