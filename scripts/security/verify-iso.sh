#!/bin/bash
# NubiferOS ISO Verification Script
# Verifies ISO signature against public key
#
# Usage: verify-iso.sh [OPTIONS]
#   --iso PATH       Path to ISO file (required)
#   --sig PATH       Path to signature file (default: ISO.sig)
#   --key PATH       Path to public key file (optional)
#   --key-id ID      GPG key ID to use for verification
#   --fetch-key      Fetch key from keyserver if not found
#   --quiet          Suppress progress output
#   --json           Output result as JSON
#
# Exit codes:
#   0 - Signature valid
#   1 - Signature invalid or verification failed
#   2 - Script error (missing files, etc.)
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
SIG_PATH=""
KEY_PATH=""
KEY_ID=""
FETCH_KEY=false
QUIET=false
JSON_OUTPUT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --sig)
            SIG_PATH="$2"
            shift 2
            ;;
        --key)
            KEY_PATH="$2"
            shift 2
            ;;
        --key-id)
            KEY_ID="$2"
            shift 2
            ;;
        --fetch-key)
            FETCH_KEY=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            QUIET=true
            shift
            ;;
        -h|--help)
            echo "Usage: verify-iso.sh [OPTIONS]"
            echo "  --iso PATH       Path to ISO file (required)"
            echo "  --sig PATH       Path to signature file (default: ISO.sig)"
            echo "  --key PATH       Path to public key file"
            echo "  --key-id ID      GPG key ID for verification"
            echo "  --fetch-key      Fetch key from keyserver if not found"
            echo "  --quiet          Suppress progress output"
            echo "  --json           Output result as JSON"
            echo ""
            echo "Exit codes:"
            echo "  0 - Signature valid"
            echo "  1 - Signature invalid"
            echo "  2 - Script error"
            echo ""
            echo "Requires: gpg"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

log() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "$1"
    fi
}

log_error() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${RED}ERROR: $1${NC}" >&2
    fi
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warn() {
    log "${YELLOW}⚠ $1${NC}"
}

# Output JSON result
output_json() {
    local valid="$1"
    local message="$2"
    local key_id="${3:-}"
    local iso_name="${4:-}"
    
    cat << EOF
{
  "valid": $valid,
  "message": "$message",
  "key_id": "$key_id",
  "iso": "$iso_name",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Import public key from file
import_key() {
    local key_file="$1"
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Key file not found: $key_file"
        return 1
    fi
    
    log "Importing public key from: $key_file"
    
    if gpg --import "$key_file" 2>/dev/null; then
        log_success "Public key imported"
        return 0
    else
        log_error "Failed to import public key"
        return 1
    fi
}

# Fetch key from keyserver
fetch_key() {
    local key_id="$1"
    
    log "Fetching key from keyserver: $key_id"
    
    # Try multiple keyservers
    local keyservers=(
        "hkps://keys.openpgp.org"
        "hkps://keyserver.ubuntu.com"
        "hkps://pgp.mit.edu"
    )
    
    for server in "${keyservers[@]}"; do
        if gpg --keyserver "$server" --recv-keys "$key_id" 2>/dev/null; then
            log_success "Key fetched from $server"
            return 0
        fi
    done
    
    log_error "Could not fetch key from any keyserver"
    return 1
}

# Verify the ISO signature
verify_signature() {
    local iso="$1"
    local sig="$2"
    
    log "Verifying signature..."
    log "  ISO: $(basename "$iso")"
    log "  Signature: $(basename "$sig")"
    log ""
    
    # Capture verification output
    local verify_output
    local verify_status
    
    verify_output=$(gpg --verify "$sig" "$iso" 2>&1) && verify_status=0 || verify_status=$?
    
    if [[ $verify_status -eq 0 ]]; then
        # Extract key ID from output
        local signing_key
        signing_key=$(echo "$verify_output" | grep -oE '[A-F0-9]{16}' | head -1 || echo "unknown")
        
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "true" "Signature is valid" "$signing_key" "$(basename "$iso")"
        else
            log_success "Signature is VALID"
            log ""
            log "Signing key: $signing_key"
            
            # Show key info
            log ""
            log "Key information:"
            gpg --list-keys "$signing_key" 2>/dev/null | head -10 || true
        fi
        
        return 0
    else
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "false" "Signature verification failed" "" "$(basename "$iso")"
        else
            log_error "Signature is INVALID"
            log ""
            log "Verification output:"
            echo "$verify_output"
        fi
        
        return 1
    fi
}

# Calculate and display checksums
show_checksums() {
    local iso="$1"
    
    log ""
    log "ISO Checksums:"
    log "  SHA256: $(sha256sum "$iso" | awk '{print $1}')"
    log "  MD5:    $(md5sum "$iso" | awk '{print $1}')"
}

# Main execution
main() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        log ""
        log "=========================================="
        log "NubiferOS ISO Verification"
        log "=========================================="
        log ""
    fi
    
    # Check for GPG
    if ! command -v gpg &> /dev/null; then
        log_error "gpg is required but not installed"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "false" "gpg not installed" "" ""
        fi
        exit 2
    fi
    
    # Validate ISO path
    if [[ -z "$ISO_PATH" ]]; then
        log_error "ISO path is required. Use --iso PATH"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "false" "ISO path not specified" "" ""
        fi
        exit 2
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        log_error "ISO file not found: $ISO_PATH"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "false" "ISO file not found" "" "$(basename "$ISO_PATH")"
        fi
        exit 2
    fi
    
    # Determine signature path
    if [[ -z "$SIG_PATH" ]]; then
        SIG_PATH="${ISO_PATH}.sig"
    fi
    
    if [[ ! -f "$SIG_PATH" ]]; then
        log_error "Signature file not found: $SIG_PATH"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "false" "Signature file not found" "" "$(basename "$ISO_PATH")"
        fi
        exit 2
    fi
    
    # Import key if provided
    if [[ -n "$KEY_PATH" ]]; then
        if ! import_key "$KEY_PATH"; then
            exit 2
        fi
    fi
    
    # Fetch key if requested and key ID provided
    if [[ "$FETCH_KEY" == "true" && -n "$KEY_ID" ]]; then
        if ! fetch_key "$KEY_ID"; then
            log_warn "Could not fetch key, trying verification anyway..."
        fi
    fi
    
    # Verify signature
    if verify_signature "$ISO_PATH" "$SIG_PATH"; then
        if [[ "$JSON_OUTPUT" != "true" ]]; then
            show_checksums "$ISO_PATH"
            log ""
            log "=========================================="
            log "Verification: ${GREEN}PASSED${NC}"
            log "=========================================="
            log ""
        fi
        exit 0
    else
        if [[ "$JSON_OUTPUT" != "true" ]]; then
            log ""
            log "=========================================="
            log "Verification: ${RED}FAILED${NC}"
            log "=========================================="
            log ""
            log "The ISO signature could not be verified."
            log "This could mean:"
            log "  1. The ISO has been modified"
            log "  2. The signature is corrupted"
            log "  3. The signing key is not in your keyring"
            log ""
            log "If you trust the source, you can import the key with:"
            log "  gpg --import nubiferos-signing-key.asc"
            log ""
        fi
        exit 1
    fi
}

main "$@"
