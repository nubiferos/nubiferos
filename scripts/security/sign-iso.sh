#!/bin/bash
# NubiferOS ISO Signing Script
# Signs ISO with GPG key for integrity verification
#
# Usage: sign-iso.sh [OPTIONS]
#   --iso PATH       Path to ISO file (required)
#   --output DIR     Output directory for signature (default: same as ISO)
#   --key-id ID      GPG key ID to use (optional if only one key)
#   --export-key     Also export public key to output directory
#   --quiet          Suppress progress output
#
# Environment (for CI):
#   GPG_PRIVATE_KEY  ASCII-armored private key (base64 encoded)
#   GPG_PASSPHRASE   Key passphrase
#
# In CI mode, the key is imported temporarily and removed after signing.
# The passphrase is passed via file descriptor, never via command line.
#
# Requires: gpg

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
ISO_PATH=""
OUTPUT_DIR=""
KEY_ID=""
EXPORT_KEY=false
QUIET=false
CI_MODE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --key-id)
            KEY_ID="$2"
            shift 2
            ;;
        --export-key)
            EXPORT_KEY=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            echo "Usage: sign-iso.sh [OPTIONS]"
            echo "  --iso PATH       Path to ISO file (required)"
            echo "  --output DIR     Output directory for signature"
            echo "  --key-id ID      GPG key ID to use"
            echo "  --export-key     Also export public key"
            echo "  --quiet          Suppress progress output"
            echo ""
            echo "Environment (CI mode):"
            echo "  GPG_PRIVATE_KEY  Base64-encoded ASCII-armored private key"
            echo "  GPG_PASSPHRASE   Key passphrase"
            echo ""
            echo "Requires: gpg"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "$1"
    fi
}

log_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warn() {
    log "${YELLOW}⚠ $1${NC}"
}

# Cleanup function for CI mode
cleanup_ci_key() {
    if [[ "$CI_MODE" == "true" && -n "$KEY_ID" ]]; then
        log "Cleaning up temporary GPG key..."
        gpg --batch --yes --delete-secret-keys "$KEY_ID" 2>/dev/null || true
        gpg --batch --yes --delete-keys "$KEY_ID" 2>/dev/null || true
    fi
}

# Import GPG key from environment (CI mode)
import_ci_key() {
    if [[ -z "${GPG_PRIVATE_KEY:-}" ]]; then
        return 1
    fi
    
    CI_MODE=true
    log "CI mode detected - importing GPG key from environment"
    
    # Create temporary file for key (more secure than pipe for large keys)
    local key_file
    key_file=$(mktemp)
    chmod 600 "$key_file"
    
    # Decode base64 key
    echo "$GPG_PRIVATE_KEY" | base64 -d > "$key_file" 2>/dev/null || {
        # Try without base64 decode (might already be plain text)
        echo "$GPG_PRIVATE_KEY" > "$key_file"
    }
    
    # Import key with passphrase if provided
    if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
        # Use passphrase via pinentry-mode loopback
        gpg --batch --yes --pinentry-mode loopback \
            --passphrase-fd 3 \
            --import "$key_file" 3<<< "$GPG_PASSPHRASE" 2>/dev/null || {
            log_error "Failed to import GPG key"
            rm -f "$key_file"
            return 1
        }
    else
        gpg --batch --yes --import "$key_file" 2>/dev/null || {
            log_error "Failed to import GPG key"
            rm -f "$key_file"
            return 1
        }
    fi
    
    # Securely remove key file
    shred -u "$key_file" 2>/dev/null || rm -f "$key_file"
    
    # Get the key ID if not specified
    if [[ -z "$KEY_ID" ]]; then
        KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | \
                 grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    fi
    
    if [[ -z "$KEY_ID" ]]; then
        log_error "Could not determine GPG key ID"
        return 1
    fi
    
    log_success "GPG key imported: $KEY_ID"
    
    # Set up cleanup trap
    trap cleanup_ci_key EXIT
    
    return 0
}

# Get default key ID if not specified
get_default_key_id() {
    if [[ -n "$KEY_ID" ]]; then
        echo "$KEY_ID"
        return
    fi
    
    # Get the first available secret key
    local key
    key=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | \
          grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    
    if [[ -z "$key" ]]; then
        log_error "No GPG secret keys found"
        log "Generate a key with: gpg --full-generate-key"
        return 1
    fi
    
    echo "$key"
}

# Sign the ISO file
sign_iso() {
    local iso="$1"
    local output="$2"
    local key="$3"
    
    local sig_file="$output/$(basename "$iso").sig"
    
    log "Signing ISO: $(basename "$iso")"
    log "Using key: $key"
    
    # Sign with detached signature
    if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
        # CI mode with passphrase
        gpg --batch --yes --pinentry-mode loopback \
            --passphrase-fd 3 \
            --default-key "$key" \
            --armor --detach-sign \
            --output "$sig_file" \
            "$iso" 3<<< "$GPG_PASSPHRASE" || {
            log_error "Failed to sign ISO"
            return 1
        }
    else
        # Interactive mode (may prompt for passphrase)
        gpg --batch --yes \
            --default-key "$key" \
            --armor --detach-sign \
            --output "$sig_file" \
            "$iso" || {
            log_error "Failed to sign ISO"
            return 1
        }
    fi
    
    log_success "Signature created: $sig_file"
    
    # Verify the signature we just created
    log "Verifying signature..."
    if gpg --verify "$sig_file" "$iso" 2>/dev/null; then
        log_success "Signature verified successfully"
    else
        log_error "Signature verification failed!"
        return 1
    fi
    
    return 0
}

# Export public key
export_public_key() {
    local output="$1"
    local key="$2"
    
    local key_file="$output/nubiferos-signing-key.asc"
    
    log "Exporting public key..."
    
    gpg --armor --export "$key" > "$key_file" || {
        log_error "Failed to export public key"
        return 1
    }
    
    log_success "Public key exported: $key_file"
    
    # Also create a fingerprint file
    local fp_file="$output/nubiferos-signing-key.fingerprint"
    gpg --fingerprint "$key" > "$fp_file" 2>/dev/null
    
    log_success "Key fingerprint: $fp_file"
    
    return 0
}

# Main execution
main() {
    log ""
    log "=========================================="
    log "NubiferOS ISO Signing"
    log "=========================================="
    log ""
    
    # Check for GPG
    if ! command -v gpg &> /dev/null; then
        log_error "gpg is required but not installed"
        exit 1
    fi
    
    # Validate ISO path
    if [[ -z "$ISO_PATH" ]]; then
        log_error "ISO path is required. Use --iso PATH"
        exit 2
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        log_error "ISO file not found: $ISO_PATH"
        exit 1
    fi
    
    # Set output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR=$(dirname "$ISO_PATH")
    fi
    mkdir -p "$OUTPUT_DIR"
    
    # Try CI mode first, then fall back to local keys
    if ! import_ci_key 2>/dev/null; then
        log "Using local GPG keyring"
    fi
    
    # Get key ID
    KEY_ID=$(get_default_key_id) || exit 1
    
    # Sign the ISO
    if ! sign_iso "$ISO_PATH" "$OUTPUT_DIR" "$KEY_ID"; then
        exit 1
    fi
    
    # Export public key if requested
    if [[ "$EXPORT_KEY" == "true" ]]; then
        if ! export_public_key "$OUTPUT_DIR" "$KEY_ID"; then
            log_warn "Failed to export public key (non-fatal)"
        fi
    fi
    
    log ""
    log "=========================================="
    log "Signing Complete"
    log "=========================================="
    log ""
    log "ISO: $(basename "$ISO_PATH")"
    log "Signature: $(basename "$ISO_PATH").sig"
    log "Key ID: $KEY_ID"
    log ""
    log "To verify:"
    log "  gpg --verify $(basename "$ISO_PATH").sig $(basename "$ISO_PATH")"
    log ""
    
    exit 0
}

main "$@"
