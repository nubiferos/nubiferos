#!/bin/bash
# Brand Configuration Loader
# Source this file in any script to load brand variables
#
# Usage:
#   source /path/to/brand/load-brand.sh
#   echo "Building ${BRAND_NAME}..."

# Determine the script's directory
if [ -n "${BASH_SOURCE[0]}" ]; then
    BRAND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${0}" ]; then
    BRAND_SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
else
    echo "Error: Cannot determine script directory" >&2
    return 1
fi

# Load brand configuration
BRAND_CONF_FILE="${BRAND_SCRIPT_DIR}/brand.conf"

if [ ! -f "${BRAND_CONF_FILE}" ]; then
    echo "Error: Brand configuration file not found: ${BRAND_CONF_FILE}" >&2
    return 1
fi

# Source the brand configuration
source "${BRAND_CONF_FILE}"

# Export all brand variables so they're available to child processes
export BRAND_NAME BRAND_SHORT_NAME BRAND_CLI_NAME BRAND_TAGLINE
export BRAND_VERSION BRAND_CODENAME
export BRAND_DOMAIN BRAND_WEBSITE BRAND_DOCS_URL BRAND_REPO_URL
export BRAND_EMAIL BRAND_SUPPORT_EMAIL BRAND_TWITTER BRAND_DISCORD
export BRAND_COPYRIGHT BRAND_LICENSE BRAND_TRADEMARK
export BRAND_PRIMARY_COLOR BRAND_SECONDARY_COLOR BRAND_ACCENT_COLOR
export BRAND_AWS_COLOR BRAND_AZURE_COLOR BRAND_GCP_COLOR
export BRAND_LOGO_PATH BRAND_ICON_PATH BRAND_WALLPAPER_PATH
export BRAND_PACKAGE_PREFIX BRAND_SERVICE_PREFIX BRAND_DBUS_NAMESPACE
export BRAND_CONFIG_DIR BRAND_DATA_DIR BRAND_LIB_DIR BRAND_LOG_DIR BRAND_CACHE_DIR
export BRAND_USER_CONFIG_DIR BRAND_USER_DATA_DIR BRAND_USER_CACHE_DIR
export BRAND_ISO_NAME BRAND_ISO_LABEL
export BRAND_DESKTOP_NAME BRAND_SESSION_NAME
export BRAND_CREDENTIAL_MANAGER BRAND_CONTEXT_MANAGER
export BRAND_RESOURCE_VIEWER BRAND_CONTEXT_INDICATOR
export BRAND_WELCOME_MESSAGE BRAND_BOOT_MESSAGE BRAND_SHUTDOWN_MESSAGE

# Provide a function to substitute brand variables in files
brand_substitute() {
    local input_file="$1"
    local output_file="$2"
    
    if [ -z "${input_file}" ] || [ ! -f "${input_file}" ]; then
        echo "Error: Input file not found: ${input_file}" >&2
        return 1
    fi
    
    if [ -z "${output_file}" ]; then
        output_file="${input_file}"
    fi
    
    # Use envsubst to substitute all BRAND_* variables
    envsubst < "${input_file}" > "${output_file}.tmp" && mv "${output_file}.tmp" "${output_file}"
}

# Provide a function to print brand info
brand_info() {
    cat << EOF
============================================================================
Brand Information
============================================================================
Name:             ${BRAND_NAME}
Short Name:       ${BRAND_SHORT_NAME}
CLI Name:         ${BRAND_CLI_NAME}
Tagline:          ${BRAND_TAGLINE}
Version:          ${BRAND_VERSION}
Codename:         ${BRAND_CODENAME}
Website:          ${BRAND_WEBSITE}
Repository:       ${BRAND_REPO_URL}
License:          ${BRAND_LICENSE}
============================================================================
EOF
}

# If script is executed directly (not sourced), print brand info
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    brand_info
fi
