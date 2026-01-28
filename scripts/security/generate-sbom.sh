#!/bin/bash
# NubiferOS SBOM Generator
# Generates Software Bill of Materials in CycloneDX and SPDX formats
#
# Usage: generate-sbom.sh [OPTIONS]
#   --chroot PATH    Generate SBOM from chroot directory
#   --iso PATH       Generate SBOM from mounted ISO
#   --output DIR     Output directory (default: output/)
#   --version VER    Override version string
#   --quiet          Suppress progress output
#
# Requires: syft (will be installed if not present)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CHROOT_PATH=""
ISO_PATH=""
OUTPUT_DIR="output"
VERSION=""
QUIET=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --chroot)
            CHROOT_PATH="$2"
            shift 2
            ;;
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            echo "Usage: generate-sbom.sh [OPTIONS]"
            echo "  --chroot PATH    Generate SBOM from chroot directory"
            echo "  --iso PATH       Generate SBOM from mounted ISO"
            echo "  --output DIR     Output directory (default: output/)"
            echo "  --version VER    Override version string"
            echo "  --quiet          Suppress progress output"
            echo ""
            echo "Requires: syft, jq"
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

# Install syft if not present
install_syft() {
    if command -v syft &> /dev/null; then
        log "syft already installed: $(syft version 2>/dev/null | head -1)"
        return 0
    fi
    
    log "Installing syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    
    if ! command -v syft &> /dev/null; then
        log_error "Failed to install syft"
        exit 1
    fi
    
    log_success "syft installed successfully"
}

# Get NubiferOS version from brand.conf
get_nubiferos_version() {
    if [[ -n "$VERSION" ]]; then
        echo "$VERSION"
        return
    fi
    
    local brand_conf="$REPO_ROOT/brand/brand.conf"
    if [[ -f "$brand_conf" ]]; then
        grep 'BRAND_VERSION=' "$brand_conf" | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

# Detect custom NubiferOS components and their versions
detect_custom_components() {
    local target_dir="$1"
    local components_json="[]"
    
    # Check for installed NubiferOS components
    local components=(
        "cli-wrappers:Cloud CLI security wrappers"
        "context-indicator:Desktop context indicator"
        "context-manager:Cloud context management daemon"
        "credential-manager:Secure credential storage"
        "first-boot-wizard:Initial setup wizard"
        "resource-viewer:Cloud resource browser"
        "security-dashboard:Security monitoring dashboard"
        "software-center:Cloud tools software center"
        "workspace-manager:Isolated workspace manager"
    )
    
    for component in "${components[@]}"; do
        local name="${component%%:*}"
        local desc="${component#*:}"
        
        # Check if component exists in target
        if [[ -d "$target_dir/usr/share/nubifer/$name" ]] || \
           [[ -f "$target_dir/usr/local/bin/nubifer-$name" ]] || \
           [[ -f "$target_dir/usr/bin/nubifer-$name" ]]; then
            components_json=$(echo "$components_json" | jq --arg name "nubifer-$name" \
                --arg desc "$desc" \
                --arg ver "$(get_nubiferos_version)" \
                '. += [{"name": $name, "version": $ver, "description": $desc, "type": "application"}]')
        fi
    done
    
    echo "$components_json"
}

# Generate SBOM from a directory (chroot or mounted ISO)
generate_sbom_from_dir() {
    local target_dir="$1"
    local output_prefix="$2"
    
    log "Generating SBOM from: $target_dir"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local nubifer_version
    nubifer_version=$(get_nubiferos_version)
    
    # Generate CycloneDX format
    log "Generating CycloneDX SBOM..."
    syft dir:"$target_dir" \
        -o cyclonedx-json="$OUTPUT_DIR/${output_prefix}.sbom.json" \
        --name "NubiferOS" \
        --version "$nubifer_version" \
        2>/dev/null || {
            log_error "Failed to generate CycloneDX SBOM"
            return 1
        }
    log_success "CycloneDX SBOM: $OUTPUT_DIR/${output_prefix}.sbom.json"
    
    # Generate SPDX format
    log "Generating SPDX SBOM..."
    syft dir:"$target_dir" \
        -o spdx-json="$OUTPUT_DIR/${output_prefix}.sbom.spdx.json" \
        --name "NubiferOS" \
        --version "$nubifer_version" \
        2>/dev/null || {
            log_error "Failed to generate SPDX SBOM"
            return 1
        }
    log_success "SPDX SBOM: $OUTPUT_DIR/${output_prefix}.sbom.spdx.json"
    
    # Add custom NubiferOS components to SBOM
    log "Detecting custom NubiferOS components..."
    local custom_components
    custom_components=$(detect_custom_components "$target_dir")
    
    if [[ "$custom_components" != "[]" ]]; then
        # Merge custom components into CycloneDX SBOM
        local sbom_file="$OUTPUT_DIR/${output_prefix}.sbom.json"
        local temp_file=$(mktemp)
        
        jq --argjson custom "$custom_components" \
            '.components += $custom' \
            "$sbom_file" > "$temp_file" && mv "$temp_file" "$sbom_file"
        
        local component_count
        component_count=$(echo "$custom_components" | jq 'length')
        log_success "Added $component_count custom NubiferOS components"
    fi
    
    # Generate summary
    local total_packages
    total_packages=$(jq '.components | length' "$OUTPUT_DIR/${output_prefix}.sbom.json")
    
    log ""
    log "=========================================="
    log "SBOM Generation Complete"
    log "=========================================="
    log "Version: $nubifer_version"
    log "Total components: $total_packages"
    log "Output files:"
    log "  - $OUTPUT_DIR/${output_prefix}.sbom.json (CycloneDX)"
    log "  - $OUTPUT_DIR/${output_prefix}.sbom.spdx.json (SPDX)"
    log ""
    
    return 0
}

# Mount ISO and generate SBOM
generate_sbom_from_iso() {
    local iso_path="$1"
    
    if [[ ! -f "$iso_path" ]]; then
        log_error "ISO file not found: $iso_path"
        exit 1
    fi
    
    log "Mounting ISO: $iso_path"
    
    local mount_point
    mount_point=$(mktemp -d)
    local squashfs_mount
    squashfs_mount=$(mktemp -d)
    
    # Cleanup function
    cleanup() {
        log "Cleaning up mount points..."
        sudo umount "$squashfs_mount" 2>/dev/null || true
        sudo umount "$mount_point" 2>/dev/null || true
        rmdir "$squashfs_mount" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
    }
    trap cleanup EXIT
    
    # Mount ISO
    sudo mount -o loop,ro "$iso_path" "$mount_point" || {
        log_error "Failed to mount ISO"
        exit 1
    }
    
    # Find and mount squashfs
    local squashfs_path=""
    for path in "$mount_point/live/filesystem.squashfs" \
                "$mount_point/casper/filesystem.squashfs" \
                "$mount_point/install/filesystem.squashfs"; do
        if [[ -f "$path" ]]; then
            squashfs_path="$path"
            break
        fi
    done
    
    if [[ -z "$squashfs_path" ]]; then
        log_error "Could not find squashfs filesystem in ISO"
        exit 1
    fi
    
    log "Found squashfs: $squashfs_path"
    sudo mount -o loop,ro "$squashfs_path" "$squashfs_mount" || {
        log_error "Failed to mount squashfs"
        exit 1
    }
    
    # Generate SBOM from mounted filesystem
    local iso_basename
    iso_basename=$(basename "$iso_path" .iso)
    generate_sbom_from_dir "$squashfs_mount" "$iso_basename"
}

# Main execution
main() {
    log "=========================================="
    log "NubiferOS SBOM Generator"
    log "=========================================="
    log ""
    
    # Check for jq (required for JSON manipulation)
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        log "Install with: apt-get install jq"
        exit 1
    fi
    
    # Install syft if needed
    install_syft
    
    # Determine what to scan
    if [[ -n "$CHROOT_PATH" ]]; then
        if [[ ! -d "$CHROOT_PATH" ]]; then
            log_error "Chroot directory not found: $CHROOT_PATH"
            exit 1
        fi
        generate_sbom_from_dir "$CHROOT_PATH" "nubiferos-$(get_nubiferos_version)"
        
    elif [[ -n "$ISO_PATH" ]]; then
        generate_sbom_from_iso "$ISO_PATH"
        
    else
        # Default: try to find chroot in work directory
        if [[ -d "$REPO_ROOT/work/chroot" ]]; then
            log "Using default chroot: $REPO_ROOT/work/chroot"
            generate_sbom_from_dir "$REPO_ROOT/work/chroot" "nubiferos-$(get_nubiferos_version)"
        else
            log_error "No target specified. Use --chroot or --iso"
            log "Usage: $0 --chroot PATH | --iso PATH"
            exit 1
        fi
    fi
    
    log_success "SBOM generation completed successfully"
}

main "$@"
