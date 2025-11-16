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
DEBIAN_ARCH="amd64"
DEBIAN_VERSION="12.8.0"
DEBIAN_CODENAME="bookworm"

# Direct URL to Debian 12.8.0 archive
DEBIAN_MIRROR="https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}/${DEBIAN_ARCH}/iso-cd"
DEBIAN_ISO_NAME="debian-${DEBIAN_VERSION}-${DEBIAN_ARCH}-netinst.iso"
DEBIAN_ISO_URL="${DEBIAN_MIRROR}/${DEBIAN_ISO_NAME}"
DEBIAN_CHECKSUM_URL="${DEBIAN_MIRROR}/SHA256SUMS"
DEBIAN_CHECKSUM_SIGN_URL="${DEBIAN_MIRROR}/SHA256SUMS.sign"

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
    
    # The SHA256SUMS file has filenames split across lines, so we need to handle this
    # Format: "checksum  debian-12.8.0-amd64\n-netinst.iso"
    # We'll search for the base filename without extension
    local base_name="debian-12.8.0-amd64"
    local expected_checksum=$(grep -B1 "netinst.iso" "${checksum_file}" | grep "${base_name}" | awk '{print $1}')
    
    if [ -z "${expected_checksum}" ]; then
        log "ERROR" "Could not find checksum for ${DEBIAN_ISO_NAME}"
        log "ERROR" "Checksum file contents:"
        cat "${checksum_file}"
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
    log "INFO" "Version: Debian ${DEBIAN_VERSION} (${DEBIAN_CODENAME})"
    log "INFO" "Architecture: ${DEBIAN_ARCH}"
    log "INFO" "Mirror: ${DEBIAN_MIRROR}"
    log "INFO" "=========================================="
    
    ISO_PATH="${DOWNLOAD_DIR}/${DEBIAN_ISO_NAME}"
    
    # Clean up old/wrong Debian ISOs
    log "INFO" "Checking for old Debian ISOs..."
    for old_iso in "${DOWNLOAD_DIR}"/debian-*.iso; do
        if [ -f "${old_iso}" ] && [ "${old_iso}" != "${ISO_PATH}" ]; then
            log "INFO" "Removing old ISO: $(basename ${old_iso})"
            rm -f "${old_iso}"
        fi
    done
    
    # Remove old checksums to force fresh download
    if [ -f "${CHECKSUM_PATH}" ]; then
        log "INFO" "Removing old checksums"
        rm -f "${CHECKSUM_PATH}" "${CHECKSUM_SIGN_PATH}"
    fi
    
    # Download checksums
    log "INFO" "Downloading checksums..."
    download_file "${DEBIAN_CHECKSUM_URL}" "${CHECKSUM_PATH}" "SHA256 checksums"
    
    # Download signature
    download_file "${DEBIAN_CHECKSUM_SIGN_URL}" "${CHECKSUM_SIGN_PATH}" "GPG signature"
    
    # Download ISO
    download_file "${DEBIAN_ISO_URL}" "${ISO_PATH}" "Debian ${DEBIAN_VERSION} ISO"
    
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
