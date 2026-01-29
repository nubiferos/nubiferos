#!/bin/bash
# NubiferOS Secret Scanner
# Scans repository for hardcoded secrets using gitleaks
#
# Usage: secret-scan.sh [OPTIONS]
#   --path PATH      Path to scan (default: current directory)
#   --config PATH    Path to gitleaks config (default: security/gitleaks.toml)
#   --output DIR     Output directory (default: output/)
#   --baseline PATH  Path to baseline file for ignoring known issues
#   --quiet          Suppress progress output
#   --json-only      Only output JSON, no summary
#   --fail-on-leak   Exit with error if secrets found (default: true)
#
# Exit codes:
#   0 - No secrets found
#   1 - Secrets found
#   2 - Script error
#
# Requires: gitleaks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
SCAN_PATH="."
CONFIG_PATH=""
OUTPUT_DIR="output"
BASELINE_PATH=""
QUIET=false
JSON_ONLY=false
FAIL_ON_LEAK=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Gitleaks version to install
GITLEAKS_VERSION="8.18.4"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            SCAN_PATH="$2"
            shift 2
            ;;
        --config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --baseline)
            BASELINE_PATH="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --json-only)
            JSON_ONLY=true
            QUIET=true
            shift
            ;;
        --no-fail)
            FAIL_ON_LEAK=false
            shift
            ;;
        -h|--help)
            echo "Usage: secret-scan.sh [OPTIONS]"
            echo "  --path PATH      Path to scan (default: current directory)"
            echo "  --config PATH    Path to gitleaks config"
            echo "  --output DIR     Output directory (default: output/)"
            echo "  --baseline PATH  Baseline file for known issues"
            echo "  --quiet          Suppress progress output"
            echo "  --json-only      Only output JSON"
            echo "  --no-fail        Don't exit with error on findings"
            echo ""
            echo "Exit codes:"
            echo "  0 - No secrets found"
            echo "  1 - Secrets found"
            echo "  2 - Script error"
            echo ""
            echo "Requires: gitleaks"
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
    echo -e "${RED}ERROR: $1${NC}" >&2
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warn() {
    log "${YELLOW}⚠ $1${NC}"
}

# Install gitleaks if not present
install_gitleaks() {
    if command -v gitleaks &> /dev/null; then
        log "gitleaks already installed: $(gitleaks version 2>/dev/null)"
        return 0
    fi
    
    log "Installing gitleaks v${GITLEAKS_VERSION}..."
    
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    case "$arch" in
        x86_64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $arch"; exit 2 ;;
    esac
    
    local url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    curl -sSL "$url" | tar xz -C "$tmp_dir"
    sudo mv "$tmp_dir/gitleaks" /usr/local/bin/
    rm -rf "$tmp_dir"
    
    if ! command -v gitleaks &> /dev/null; then
        log_error "Failed to install gitleaks"
        exit 2
    fi
    
    log_success "gitleaks installed successfully"
}

# Run secret scan
run_scan() {
    local scan_args=()
    
    # Set scan path
    scan_args+=("--source" "$SCAN_PATH")
    
    # Use custom config if provided
    if [[ -z "$CONFIG_PATH" ]]; then
        CONFIG_PATH="$REPO_ROOT/security/gitleaks.toml"
    fi
    
    if [[ -f "$CONFIG_PATH" ]]; then
        scan_args+=("--config" "$CONFIG_PATH")
        log "Using config: $CONFIG_PATH"
    fi
    
    # Use baseline if provided
    if [[ -n "$BASELINE_PATH" && -f "$BASELINE_PATH" ]]; then
        scan_args+=("--baseline-path" "$BASELINE_PATH")
        log "Using baseline: $BASELINE_PATH"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local json_report="$OUTPUT_DIR/secrets.json"
    local sarif_report="$OUTPUT_DIR/secrets.sarif"
    
    log ""
    log "=========================================="
    log "NubiferOS Secret Scanner"
    log "=========================================="
    log ""
    log "Scanning: $SCAN_PATH"
    log ""
    
    # Run gitleaks
    local exit_code=0
    gitleaks detect "${scan_args[@]}" \
        --report-format json \
        --report-path "$json_report" \
        --exit-code 0 \
        2>/dev/null || exit_code=$?
    
    # Also generate SARIF for GitHub integration
    gitleaks detect "${scan_args[@]}" \
        --report-format sarif \
        --report-path "$sarif_report" \
        --exit-code 0 \
        2>/dev/null || true
    
    # Count findings
    local finding_count=0
    if [[ -f "$json_report" ]]; then
        finding_count=$(jq 'length' "$json_report" 2>/dev/null || echo "0")
    fi
    
    if [[ "$JSON_ONLY" == "true" ]]; then
        cat "$json_report"
        if [[ $finding_count -gt 0 && "$FAIL_ON_LEAK" == "true" ]]; then
            return 1
        fi
        return 0
    fi
    
    log ""
    log "=========================================="
    log "Scan Results"
    log "=========================================="
    log ""
    
    if [[ $finding_count -eq 0 ]]; then
        log_success "No secrets found!"
        log ""
        log "Output: $json_report"
        return 0
    else
        log_error "Found $finding_count potential secret(s)!"
        log ""
        
        # Show summary of findings
        log "Findings:"
        jq -r '.[] | "  - \(.RuleID): \(.File):\(.StartLine) - \(.Description)"' "$json_report" 2>/dev/null | head -20
        
        if [[ $finding_count -gt 20 ]]; then
            log "  ... and $((finding_count - 20)) more"
        fi
        
        log ""
        log "Full report: $json_report"
        log ""
        log "To fix:"
        log "  1. Remove the secrets from the code"
        log "  2. Rotate any exposed credentials"
        log "  3. Add false positives to baseline with:"
        log "     gitleaks detect --baseline-path $OUTPUT_DIR/secrets-baseline.json"
        log ""
        
        if [[ "$FAIL_ON_LEAK" == "true" ]]; then
            return 1
        fi
        return 0
    fi
}

# Main execution
main() {
    # Validate scan path
    if [[ ! -d "$SCAN_PATH" ]]; then
        log_error "Scan path not found: $SCAN_PATH"
        exit 2
    fi
    
    # Install gitleaks if needed
    install_gitleaks
    
    # Run scan
    if run_scan; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
