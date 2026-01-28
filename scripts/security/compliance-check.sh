#!/bin/bash
# NubiferOS Hardening Compliance Check
# Runs CIS-style security audit using lynis
#
# Usage: compliance-check.sh [OPTIONS]
#   --chroot PATH    Audit chroot directory
#   --live           Audit live/running system
#   --min-score N    Minimum acceptable score (default: 70)
#   --baseline PATH  Path to baseline config (default: security/compliance-baseline.yaml)
#   --output DIR     Output directory (default: output/)
#   --quiet          Suppress progress output
#   --json           Output results as JSON
#
# Exit codes:
#   0 - Compliance check passed (score >= min-score)
#   1 - Compliance check failed (score < min-score)
#   2 - Script error
#
# Requires: lynis

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
CHROOT_PATH=""
LIVE_MODE=false
MIN_SCORE=70
BASELINE_PATH=""
OUTPUT_DIR="output"
QUIET=false
JSON_OUTPUT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --chroot)
            CHROOT_PATH="$2"
            shift 2
            ;;
        --live)
            LIVE_MODE=true
            shift
            ;;
        --min-score)
            MIN_SCORE="$2"
            shift 2
            ;;
        --baseline)
            BASELINE_PATH="$2"
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
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: compliance-check.sh [OPTIONS]"
            echo "  --chroot PATH    Audit chroot directory"
            echo "  --live           Audit live/running system"
            echo "  --min-score N    Minimum acceptable score (default: 70)"
            echo "  --baseline PATH  Path to baseline config"
            echo "  --output DIR     Output directory (default: output/)"
            echo "  --quiet          Suppress progress output"
            echo "  --json           Output results as JSON"
            echo ""
            echo "Exit codes:"
            echo "  0 - Passed (score >= min-score)"
            echo "  1 - Failed (score < min-score)"
            echo "  2 - Script error"
            echo ""
            echo "Requires: lynis"
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

# Install lynis if not present
install_lynis() {
    if command -v lynis &> /dev/null; then
        log "lynis already installed: $(lynis --version 2>/dev/null | head -1)"
        return 0
    fi
    
    log "Installing lynis..."
    
    # Try apt first (Debian/Ubuntu)
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq lynis
    # Try yum (RHEL/CentOS)
    elif command -v yum &> /dev/null; then
        sudo yum install -y lynis
    # Try downloading directly
    else
        log "Downloading lynis from GitHub..."
        local lynis_dir="/usr/local/lynis"
        sudo git clone https://github.com/CISOfy/lynis.git "$lynis_dir" 2>/dev/null
        sudo ln -sf "$lynis_dir/lynis" /usr/local/bin/lynis
    fi
    
    if ! command -v lynis &> /dev/null; then
        log_error "Failed to install lynis"
        exit 2
    fi
    
    log_success "lynis installed successfully"
}

# Load baseline configuration
load_baseline() {
    local baseline_file="$1"
    
    if [[ ! -f "$baseline_file" ]]; then
        return
    fi
    
    # Extract min_score from baseline if not overridden
    if command -v yq &> /dev/null; then
        local baseline_score
        baseline_score=$(yq -r '.min_score // empty' "$baseline_file" 2>/dev/null)
        if [[ -n "$baseline_score" && "$MIN_SCORE" == "70" ]]; then
            MIN_SCORE="$baseline_score"
            log "Using baseline min_score: $MIN_SCORE"
        fi
    fi
}

# Parse lynis output to extract hardening index
parse_hardening_index() {
    local report_file="$1"
    
    # Extract hardening index from lynis report
    local score
    score=$(grep -E "Hardening index\s*:" "$report_file" 2>/dev/null | \
            grep -oE '[0-9]+' | head -1)
    
    if [[ -z "$score" ]]; then
        # Try alternative format
        score=$(grep -E "hardening_index=" "$report_file" 2>/dev/null | \
                grep -oE '[0-9]+' | head -1)
    fi
    
    echo "${score:-0}"
}

# Parse lynis output for warnings and suggestions
parse_findings() {
    local report_file="$1"
    local output_file="$2"
    
    {
        echo "# NubiferOS Compliance Report"
        echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        
        # Extract warnings
        echo "## Warnings"
        grep -E "^\s*\* " "$report_file" 2>/dev/null | head -20 || echo "  None"
        echo ""
        
        # Extract suggestions
        echo "## Suggestions"
        grep -E "^\s*- " "$report_file" 2>/dev/null | head -30 || echo "  None"
        echo ""
        
    } > "$output_file"
}

# Generate JSON output
generate_json_report() {
    local score="$1"
    local passed="$2"
    local report_file="$3"
    local output_file="$4"
    
    local warnings suggestions
    warnings=$(grep -cE "^\s*\* " "$report_file" 2>/dev/null || echo "0")
    suggestions=$(grep -cE "^\s*- " "$report_file" 2>/dev/null || echo "0")
    
    cat > "$output_file" << EOF
{
  "score": $score,
  "min_score": $MIN_SCORE,
  "passed": $passed,
  "warnings": $warnings,
  "suggestions": $suggestions,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "mode": "$(if [[ "$LIVE_MODE" == "true" ]]; then echo "live"; else echo "chroot"; fi)"
}
EOF
}

# Run lynis audit
run_audit() {
    local target_args=()
    local audit_mode=""
    
    if [[ "$LIVE_MODE" == "true" ]]; then
        audit_mode="live"
        log "Running live system audit..."
    elif [[ -n "$CHROOT_PATH" ]]; then
        if [[ ! -d "$CHROOT_PATH" ]]; then
            log_error "Chroot directory not found: $CHROOT_PATH"
            exit 2
        fi
        audit_mode="chroot"
        target_args+=("--rootdir" "$CHROOT_PATH")
        log "Running chroot audit: $CHROOT_PATH"
    else
        # Default: try work/chroot
        if [[ -d "$REPO_ROOT/work/chroot" ]]; then
            CHROOT_PATH="$REPO_ROOT/work/chroot"
            audit_mode="chroot"
            target_args+=("--rootdir" "$CHROOT_PATH")
            log "Using default chroot: $CHROOT_PATH"
        else
            log_error "No target specified. Use --chroot PATH or --live"
            exit 2
        fi
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local report_file="$OUTPUT_DIR/lynis-report.txt"
    local log_file="$OUTPUT_DIR/lynis-audit.log"
    
    log ""
    log "=========================================="
    log "NubiferOS Compliance Check"
    log "=========================================="
    log ""
    log "Mode: $audit_mode"
    log "Minimum score: $MIN_SCORE"
    log ""
    
    # Run lynis audit
    log "Running lynis audit (this may take a few minutes)..."
    
    # Lynis needs to run as root for full audit
    local lynis_cmd="lynis audit system"
    lynis_cmd+=" ${target_args[*]}"
    lynis_cmd+=" --no-colors"
    lynis_cmd+=" --quiet"
    lynis_cmd+=" --report-file $report_file"
    lynis_cmd+=" --log-file $log_file"
    
    if [[ $EUID -eq 0 ]]; then
        eval "$lynis_cmd" 2>/dev/null || true
    else
        # Try with sudo
        sudo $lynis_cmd 2>/dev/null || {
            log_warn "Running without sudo - some tests may be skipped"
            eval "$lynis_cmd" 2>/dev/null || true
        }
    fi
    
    # Check if report was generated
    if [[ ! -f "$report_file" ]]; then
        # Lynis might put report in default location
        local default_report="/var/log/lynis-report.dat"
        if [[ -f "$default_report" ]]; then
            cp "$default_report" "$report_file"
        else
            log_error "Lynis report not generated"
            exit 2
        fi
    fi
    
    # Parse results
    local score
    score=$(parse_hardening_index "$report_file")
    
    log ""
    log "=========================================="
    log "Audit Results"
    log "=========================================="
    log ""
    
    # Color-code the score
    local score_color="$RED"
    if [[ $score -ge $MIN_SCORE ]]; then
        score_color="$GREEN"
    elif [[ $score -ge $((MIN_SCORE - 10)) ]]; then
        score_color="$YELLOW"
    fi
    
    log "Hardening Index: ${score_color}${score}${NC} / 100"
    log "Minimum Required: $MIN_SCORE"
    log ""
    
    # Generate reports
    local summary_file="$OUTPUT_DIR/compliance-summary.txt"
    parse_findings "$report_file" "$summary_file"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local json_file="$OUTPUT_DIR/compliance.json"
        local passed="false"
        [[ $score -ge $MIN_SCORE ]] && passed="true"
        generate_json_report "$score" "$passed" "$report_file" "$json_file"
        cat "$json_file"
    fi
    
    log "Output files:"
    log "  - $report_file (full report)"
    log "  - $summary_file (summary)"
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        log "  - $OUTPUT_DIR/compliance.json"
    fi
    log ""
    
    # Check against minimum score
    if [[ $score -ge $MIN_SCORE ]]; then
        log_success "Compliance check PASSED (score: $score >= $MIN_SCORE)"
        return 0
    else
        log_error "Compliance check FAILED (score: $score < $MIN_SCORE)"
        log ""
        log "To improve the score:"
        log "  1. Review warnings in: $summary_file"
        log "  2. Apply recommended hardening measures"
        log "  3. Or lower the threshold with --min-score"
        return 1
    fi
}

# Main execution
main() {
    # Set default baseline path
    if [[ -z "$BASELINE_PATH" ]]; then
        BASELINE_PATH="$REPO_ROOT/security/compliance-baseline.yaml"
    fi
    
    # Load baseline configuration
    if [[ -f "$BASELINE_PATH" ]]; then
        load_baseline "$BASELINE_PATH"
    fi
    
    # Install lynis if needed
    install_lynis
    
    # Run audit
    if run_audit; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
