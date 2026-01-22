#!/bin/bash
# Configure NubiferOS branding - /etc/os-release, /etc/issue, etc.
# This makes the system identify as NubiferOS instead of Debian

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

log "INFO" "Configuring NubiferOS system branding..."

# Create /etc/os-release
log "INFO" "Creating /etc/os-release..."
cat > "${CHROOT_DIR}/etc/os-release" << EOF
PRETTY_NAME="${BRAND_NAME} ${BRAND_VERSION} (${BRAND_CODENAME})"
NAME="${BRAND_NAME}"
VERSION_ID="${BRAND_VERSION}"
VERSION="${BRAND_VERSION} (${BRAND_CODENAME})"
VERSION_CODENAME=${BRAND_CODENAME,,}
ID=nubiferos
ID_LIKE=debian
HOME_URL="${BRAND_WEBSITE}"
SUPPORT_URL="https://github.com/jessetop/nubiferOS/issues"
BUG_REPORT_URL="https://github.com/jessetop/nubiferOS/issues"
EOF

# Create /etc/lsb-release for tools that use it
log "INFO" "Creating /etc/lsb-release..."
cat > "${CHROOT_DIR}/etc/lsb-release" << EOF
DISTRIB_ID=${BRAND_NAME}
DISTRIB_RELEASE=${BRAND_VERSION}
DISTRIB_CODENAME=${BRAND_CODENAME,,}
DISTRIB_DESCRIPTION="${BRAND_NAME} ${BRAND_VERSION} (${BRAND_CODENAME})"
EOF

# Create /etc/issue (shown at console login)
log "INFO" "Creating /etc/issue..."
cat > "${CHROOT_DIR}/etc/issue" << EOF
${BRAND_NAME} ${BRAND_VERSION} (${BRAND_CODENAME}) - ${BRAND_TAGLINE}
Kernel \\r on \\m (\\l)

EOF

# Create /etc/issue.net (shown for network logins)
log "INFO" "Creating /etc/issue.net..."
cat > "${CHROOT_DIR}/etc/issue.net" << EOF
${BRAND_NAME} ${BRAND_VERSION} (${BRAND_CODENAME})
EOF

# Create /etc/motd (message of the day)
log "INFO" "Creating /etc/motd..."
cat > "${CHROOT_DIR}/etc/motd" << EOF

Welcome to ${BRAND_NAME} ${BRAND_VERSION} (${BRAND_CODENAME})
${BRAND_TAGLINE}

  * Documentation: ${BRAND_WEBSITE}
  * Support:       https://github.com/jessetop/nubiferOS/issues

System information as of \$(date)

EOF

# Update hostname template
log "INFO" "Setting default hostname..."
echo "nubiferos" > "${CHROOT_DIR}/etc/hostname"

log "INFO" "✓ NubiferOS branding configured"
log "INFO" "  - /etc/os-release"
log "INFO" "  - /etc/lsb-release"
log "INFO" "  - /etc/issue"
log "INFO" "  - /etc/issue.net"
log "INFO" "  - /etc/motd"
