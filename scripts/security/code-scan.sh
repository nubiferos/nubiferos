#!/bin/bash
# NubiferOS Code Quality Scanner
# Scans shell scripts for common issues using shellcheck
#
# Usage: code-scan.sh [OPTIONS]
#   --path PATH      Path to scan (default: current directory)
#   --output DIR     Output directory (default: output/)
#   --severity LVL   Minimum severity: error, warning, info, style (default: warning)
#   --exclude CODES  Comma-separated shellcheck codes to exclude
#   --quiet          Suppress progress output
#   --json           Output results as JSON
#   --fail-on-error  Exit with error if issues found (default: true)
#
# Exit codes:
#   0 - No issues found (or only below threshold)
#   1 - Issues found above threshold
#   2 - Script error
#
# Requires: shellcheck

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
SCAN_PATH="."
OUTPUT_DIR="output"
SEVERITY="warning"
EXCLUDE_CODES=""
QUIET=false
JSON_OUTPUT=false
FAIL_ON_ERROR=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            SCAN_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_CODES="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --no-fail)
            FAIL_ON_ERROR=false
            shift
            ;;
        -h|--help)
            echo "Usage: code-scan.sh [OPTIONS]"
            echo "  --path PATH      Path to scan (default: current directory)"
            echo "  --output DIR     Output directory (default: output/)"
            echo "  --severity LVL   Minimum severity: error, warning, info, style"
            echo "  --exclude CODES  Comma-separated shellcheck codes to exclude"
            echo "  --quiet          Suppress progress output"
            echo "  --json           Output results as JSON"
            echo "  --no-fail        Don't exit with error on findings"
            echo ""
            echo "Exit codes:"
            echo "  0 - No issues found"
            echo "  1 - Issues found"
            echo "  2 - Script error"
            echo ""
            echo "Requires: shellcheck"
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

# Install shellcheck if not present
install_shellcheck() {
    if command -v shellcheck &> /dev/null; then
        log "shellcheck already installed: $(shellcheck --version 2>/dev/null | head -2 | tail -1)"
        return 0
    fi
    
    log "Installing shellcheck..."
    
    # Try apt first (Debian/Ubuntu)
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq shellcheck
    # Try brew (macOS)
    elif command -v brew &> /dev/null; then
        brew install shellcheck
    # Try downloading binary
    else
        local version="0.9.0"
        local os arch
        os=$(uname -s | tr '[:upper:]' '[:lower:]')
        arch=$(uname -m)
        
        local url="https://github.com/koalaman/shellcheck/releases/download/v${version}/shellcheck-v${version}.${os}.${arch}.tar.xz"
        local tmp_dir
        tmp_dir=$(mktemp -d)
        
        curl -sSL "$url" | tar xJ -C "$tmp_dir"
        sudo mv "$tmp_dir/shellcheck-v${version}/shellcheck" /usr/local/bin/
        rm -rf "$tmp_dir"
    fi
    
    if ! command -v shellcheck &> /dev/null; then
        log_error "Failed to install shellcheck"
        exit 2
    fi
    
    log_success "shellcheck installed successfully"
}

# Find shell scripts
find_scripts() {
    local path="$1"
    
    # Find by extension
    find "$path" -type f \( -name "*.sh" -o -name "*.bash" \) 2>/dev/null
    
    # Find by shebang (files without extension)
    find "$path" -type f ! -name "*.*" -exec grep -l "^#!.*\(bash\|sh\)" {} \; 2>/dev/null || true
}

# Run shellcheck scan
run_scan() {
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local json_report="$OUTPUT_DIR/shellcheck.json"
    local text_report="$OUTPUT_DIR/shellcheck.txt"
    
    log ""
    log "=========================================="
    log "NubiferOS Code Scanner (shellcheck)"
    log "=========================================="
    log ""
    log "Scanning: $SCAN_PATH"
    log "Severity: $SEVERITY"
    log ""
    
    # Find all shell scripts
    local scripts
    scripts=$(find_scripts "$SCAN_PATH")
    
    local script_count
    script_count=$(echo "$scripts" | grep -c . || echo "0")
    
    if [[ $script_count -eq 0 ]]; then
        log_warn "No shell scripts found to scan"
        echo "[]" > "$json_report"
        return 0
    fi
    
    log "Found $script_count shell script(s)"
    log ""
    
    # Build shellcheck arguments
    local sc_args=()
    sc_args+=("--severity=$SEVERITY")
    sc_args+=("--format=json")
    
    if [[ -n "$EXCLUDE_CODES" ]]; then
        sc_args+=("--exclude=$EXCLUDE_CODES")
    fi
    
    # Run shellcheck on all scripts
    local exit_code=0
    echo "$scripts" | xargs shellcheck "${sc_args[@]}" > "$json_report" 2>/dev/null || exit_code=$?
    
    # Also generate text report
    echo "$scripts" | xargs shellcheck --severity="$SEVERITY" ${EXCLUDE_CODES:+--exclude=$EXCLUDE_CODES} > "$text_report" 2>&1 || true
    
    # Count issues by severity
    local errors warnings infos styles total
    errors=$(jq '[.[] | select(.level == "error")] | length' "$json_report" 2>/dev/null || echo "0")
    warnings=$(jq '[.[] | select(.level == "warning")] | length' "$json_report" 2>/dev/null || echo "0")
    infos=$(jq '[.[] | select(.level == "info")] | length' "$json_report" 2>/dev/null || echo "0")
    styles=$(jq '[.[] | select(.level == "style")] | length' "$json_report" 2>/dev/null || echo "0")
    total=$(jq 'length' "$json_report" 2>/dev/null || echo "0")
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cat "$json_report"
        if [[ $total -gt 0 && "$FAIL_ON_ERROR" == "true" ]]; then
            return 1
        fi
        return 0
    fi
    
    log "=========================================="
    log "Scan Results"
    log "=========================================="
    log ""
    log "  ${RED}Errors:${NC}   $errors"
    log "  ${YELLOW}Warnings:${NC} $warnings"
    log "  ${CYAN}Info:${NC}     $infos"
    log "  Style:    $styles"
    log "  ─────────────────"
    log "  Total:    $total"
    log ""
    
    if [[ $total -eq 0 ]]; then
        log_success "No issues found!"
        return 0
    fi
    
    # Show top issues
    log "Top issues:"
    jq -r '.[:10] | .[] | "  \(.level): \(.file):\(.line) - SC\(.code): \(.message)"' "$json_report" 2>/dev/null || true
    
    if [[ $total -gt 10 ]]; then
        log "  ... and $((total - 10)) more"
    fi
    
    log ""
    log "Full report: $text_report"
    log "JSON report: $json_report"
    log ""
    
    # Determine if we should fail
    local should_fail=false
    case "$SEVERITY" in
        error)
            [[ $errors -gt 0 ]] && should_fail=true
            ;;
        warning)
            [[ $errors -gt 0 || $warnings -gt 0 ]] && should_fail=true
            ;;
        info)
            [[ $errors -gt 0 || $warnings -gt 0 || $infos -gt 0 ]] && should_fail=true
            ;;
        style)
            [[ $total -gt 0 ]] && should_fail=true
            ;;
    esac
    
    if [[ "$should_fail" == "true" && "$FAIL_ON_ERROR" == "true" ]]; then
        log_error "Issues found above threshold ($SEVERITY)"
        return 1
    fi
    
    log_success "No issues above threshold"
    return 0
}

# Main execution
main() {
    # Validate scan path
    if [[ ! -d "$SCAN_PATH" ]]; then
        log_error "Scan path not found: $SCAN_PATH"
        exit 2
    fi
    
    # Install shellcheck if needed
    install_shellcheck
    
    # Run scan
    if run_scan; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
