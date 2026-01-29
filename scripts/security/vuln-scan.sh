#!/bin/bash
# NubiferOS Vulnerability Scanner
# Scans SBOM or filesystem for known CVEs using grype
#
# Usage: vuln-scan.sh [OPTIONS]
#   --sbom PATH      Scan using SBOM file (faster, recommended)
#   --dir PATH       Scan directory directly
#   --threshold LVL  Fail threshold: critical, high, medium, low (default: high)
#   --allowlist PATH Path to allowlist YAML (default: security/vuln-allowlist.yaml)
#   --output DIR     Output directory (default: output/)
#   --quiet          Suppress progress output
#   --json-only      Only output JSON, no table
#
# Exit codes:
#   0 - No vulnerabilities above threshold
#   1 - Vulnerabilities found above threshold
#   2 - Script error
#
# Requires: grype

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
SBOM_PATH=""
DIR_PATH=""
THRESHOLD="high"
ALLOWLIST_PATH=""
OUTPUT_DIR="output"
QUIET=false
JSON_ONLY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sbom)
            SBOM_PATH="$2"
            shift 2
            ;;
        --dir)
            DIR_PATH="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --allowlist)
            ALLOWLIST_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --json-only)
            JSON_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: vuln-scan.sh [OPTIONS]"
            echo "  --sbom PATH      Scan using SBOM file (faster, recommended)"
            echo "  --dir PATH       Scan directory directly"
            echo "  --threshold LVL  Fail threshold: critical, high, medium, low (default: high)"
            echo "  --allowlist PATH Path to allowlist YAML"
            echo "  --output DIR     Output directory (default: output/)"
            echo "  --quiet          Suppress progress output"
            echo "  --json-only      Only output JSON, no table"
            echo ""
            echo "Requires: grype, jq, yq (optional for allowlist)"
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

# Install grype if not present
install_grype() {
    if command -v grype &> /dev/null; then
        log "grype already installed: $(grype version 2>/dev/null | head -1)"
        return 0
    fi
    
    log "Installing grype..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
    
    if ! command -v grype &> /dev/null; then
        log_error "Failed to install grype"
        exit 2
    fi
    
    log_success "grype installed successfully"
}

# Convert threshold to grype severity level
get_severity_level() {
    case "$1" in
        critical) echo "Critical" ;;
        high)     echo "High" ;;
        medium)   echo "Medium" ;;
        low)      echo "Low" ;;
        *)        echo "High" ;;
    esac
}

# Load allowlist and return CVE IDs to ignore
load_allowlist() {
    local allowlist_file="$1"
    
    if [[ ! -f "$allowlist_file" ]]; then
        echo ""
        return
    fi
    
    # Parse YAML allowlist - extract CVE IDs
    # Check for expired entries
    local today
    today=$(date +%Y-%m-%d)
    
    if command -v yq &> /dev/null; then
        # Use yq if available
        yq -r '.vulnerabilities[]? | select(.expires == null or .expires >= "'"$today"'") | .id' "$allowlist_file" 2>/dev/null | tr '\n' '|' | sed 's/|$//'
    else
        # Fallback: simple grep for CVE IDs
        grep -oE 'CVE-[0-9]{4}-[0-9]+' "$allowlist_file" 2>/dev/null | tr '\n' '|' | sed 's/|$//'
    fi
}

# Filter vulnerabilities based on allowlist
filter_vulnerabilities() {
    local json_file="$1"
    local allowlist_pattern="$2"
    local output_file="$3"
    
    if [[ -z "$allowlist_pattern" ]]; then
        cp "$json_file" "$output_file"
        return
    fi
    
    # Filter out allowlisted CVEs
    jq --arg pattern "$allowlist_pattern" '
        .matches = [.matches[] | select(.vulnerability.id | test($pattern) | not)]
    ' "$json_file" > "$output_file"
}

# Count vulnerabilities by severity
count_by_severity() {
    local json_file="$1"
    local severity="$2"
    
    jq -r --arg sev "$severity" '[.matches[] | select(.vulnerability.severity == $sev)] | length' "$json_file"
}

# Check if any vulnerabilities exceed threshold
check_threshold() {
    local json_file="$1"
    local threshold="$2"
    
    local critical high medium low
    critical=$(count_by_severity "$json_file" "Critical")
    high=$(count_by_severity "$json_file" "High")
    medium=$(count_by_severity "$json_file" "Medium")
    low=$(count_by_severity "$json_file" "Low")
    
    case "$threshold" in
        critical)
            [[ $critical -gt 0 ]] && return 1
            ;;
        high)
            [[ $critical -gt 0 || $high -gt 0 ]] && return 1
            ;;
        medium)
            [[ $critical -gt 0 || $high -gt 0 || $medium -gt 0 ]] && return 1
            ;;
        low)
            [[ $critical -gt 0 || $high -gt 0 || $medium -gt 0 || $low -gt 0 ]] && return 1
            ;;
    esac
    
    return 0
}

# Generate human-readable report
generate_report() {
    local json_file="$1"
    local output_file="$2"
    
    local critical high medium low negligible
    critical=$(count_by_severity "$json_file" "Critical")
    high=$(count_by_severity "$json_file" "High")
    medium=$(count_by_severity "$json_file" "Medium")
    low=$(count_by_severity "$json_file" "Low")
    negligible=$(count_by_severity "$json_file" "Negligible")
    
    {
        echo "=========================================="
        echo "NubiferOS Vulnerability Scan Report"
        echo "=========================================="
        echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "Threshold: $THRESHOLD"
        echo ""
        echo "Summary:"
        echo "  Critical:   $critical"
        echo "  High:       $high"
        echo "  Medium:     $medium"
        echo "  Low:        $low"
        echo "  Negligible: $negligible"
        echo ""
        
        local total=$((critical + high + medium + low + negligible))
        if [[ $total -gt 0 ]]; then
            echo "Vulnerabilities:"
            echo ""
            jq -r '.matches[] | "  \(.vulnerability.severity): \(.vulnerability.id) - \(.artifact.name) \(.artifact.version)"' "$json_file" | sort
        else
            echo "No vulnerabilities found!"
        fi
        echo ""
        echo "=========================================="
    } > "$output_file"
}

# Main scan function
run_scan() {
    local target=""
    local target_type=""
    
    if [[ -n "$SBOM_PATH" ]]; then
        if [[ ! -f "$SBOM_PATH" ]]; then
            log_error "SBOM file not found: $SBOM_PATH"
            exit 2
        fi
        target="sbom:$SBOM_PATH"
        target_type="SBOM"
    elif [[ -n "$DIR_PATH" ]]; then
        if [[ ! -d "$DIR_PATH" ]]; then
            log_error "Directory not found: $DIR_PATH"
            exit 2
        fi
        target="dir:$DIR_PATH"
        target_type="directory"
    else
        # Try to find SBOM in output directory
        local found_sbom=""
        for f in "$OUTPUT_DIR"/nubiferos-*.sbom.json; do
            if [[ -f "$f" ]]; then
                found_sbom="$f"
                break
            fi
        done
        
        if [[ -n "$found_sbom" ]]; then
            SBOM_PATH="$found_sbom"
            target="sbom:$SBOM_PATH"
            target_type="SBOM"
            log "Using SBOM: $SBOM_PATH"
        elif [[ -d "$REPO_ROOT/work/chroot" ]]; then
            target="dir:$REPO_ROOT/work/chroot"
            target_type="directory"
            log "Using default chroot: $REPO_ROOT/work/chroot"
        else
            log_error "No target specified. Use --sbom or --dir"
            exit 2
        fi
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Determine output filename
    local output_prefix="nubiferos"
    if [[ -n "$SBOM_PATH" ]]; then
        output_prefix=$(basename "$SBOM_PATH" .sbom.json)
    fi
    
    local raw_json="$OUTPUT_DIR/${output_prefix}.vulns.raw.json"
    local filtered_json="$OUTPUT_DIR/${output_prefix}.vulns.json"
    local report_txt="$OUTPUT_DIR/${output_prefix}.vulns.txt"
    
    log ""
    log "=========================================="
    log "NubiferOS Vulnerability Scanner"
    log "=========================================="
    log ""
    log "Target: $target_type"
    log "Threshold: $THRESHOLD"
    
    # Load allowlist
    if [[ -z "$ALLOWLIST_PATH" ]]; then
        ALLOWLIST_PATH="$REPO_ROOT/security/vuln-allowlist.yaml"
    fi
    
    local allowlist_pattern=""
    if [[ -f "$ALLOWLIST_PATH" ]]; then
        allowlist_pattern=$(load_allowlist "$ALLOWLIST_PATH")
        if [[ -n "$allowlist_pattern" ]]; then
            log "Allowlist: $(echo "$allowlist_pattern" | tr '|' ', ')"
        fi
    fi
    
    log ""
    log "Running grype scan..."
    
    # Run grype
    grype "$target" -o json > "$raw_json" 2>/dev/null || {
        log_error "grype scan failed"
        exit 2
    }
    
    # Filter based on allowlist
    filter_vulnerabilities "$raw_json" "$allowlist_pattern" "$filtered_json"
    
    # Generate human-readable report
    if [[ "$JSON_ONLY" != "true" ]]; then
        generate_report "$filtered_json" "$report_txt"
        
        # Also generate table output
        log ""
        grype "$target" -o table 2>/dev/null || true
    fi
    
    # Count results
    local critical high medium low
    critical=$(count_by_severity "$filtered_json" "Critical")
    high=$(count_by_severity "$filtered_json" "High")
    medium=$(count_by_severity "$filtered_json" "Medium")
    low=$(count_by_severity "$filtered_json" "Low")
    
    log ""
    log "=========================================="
    log "Scan Results"
    log "=========================================="
    log ""
    log "  ${RED}Critical:${NC}   $critical"
    log "  ${YELLOW}High:${NC}       $high"
    log "  ${CYAN}Medium:${NC}     $medium"
    log "  Low:        $low"
    log ""
    log "Output files:"
    log "  - $filtered_json"
    if [[ "$JSON_ONLY" != "true" ]]; then
        log "  - $report_txt"
    fi
    log ""
    
    # Clean up raw file
    rm -f "$raw_json"
    
    # Check threshold
    if ! check_threshold "$filtered_json" "$THRESHOLD"; then
        log_error "Vulnerabilities exceed threshold ($THRESHOLD)"
        log ""
        log "To proceed, either:"
        log "  1. Fix the vulnerabilities"
        log "  2. Add exceptions to: $ALLOWLIST_PATH"
        log "  3. Lower the threshold with --threshold"
        log ""
        return 1
    fi
    
    log_success "No vulnerabilities above threshold"
    return 0
}

# Main execution
main() {
    # Check for jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 2
    fi
    
    # Install grype if needed
    install_grype
    
    # Run scan
    if run_scan; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
