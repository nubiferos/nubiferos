#!/bin/bash
# Sync NubiferOS content to the website project
# This script copies branding, docs, and key files to the website project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEBSITE_PROJECT="${HOME}/Projects/Kiro/NubiferOS_Website"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Syncing NubiferOS content to website project..."
echo ""

# Check if website project exists
if [ ! -d "${WEBSITE_PROJECT}" ]; then
    echo -e "${YELLOW}Warning: Website project not found at ${WEBSITE_PROJECT}${NC}"
    echo "Create it or update WEBSITE_PROJECT path in this script."
    exit 1
fi

# Create directories
mkdir -p "${WEBSITE_PROJECT}/brand/icons"
mkdir -p "${WEBSITE_PROJECT}/brand/wallpapers"
mkdir -p "${WEBSITE_PROJECT}/docs/guides"

# Sync brand assets
echo "Syncing brand assets..."
cp "${PROJECT_ROOT}/brand/logo.svg" "${WEBSITE_PROJECT}/brand/"
cp "${PROJECT_ROOT}/brand/nubiferos-logo.png" "${WEBSITE_PROJECT}/brand/" 2>/dev/null || true
cp "${PROJECT_ROOT}/brand/brand.conf" "${WEBSITE_PROJECT}/brand/"
cp "${PROJECT_ROOT}/brand/README.md" "${WEBSITE_PROJECT}/brand/"
cp "${PROJECT_ROOT}/brand/brandideas.md" "${WEBSITE_PROJECT}/brand/"
cp "${PROJECT_ROOT}/brand/icons/"*.png "${WEBSITE_PROJECT}/brand/icons/" 2>/dev/null || true
cp "${PROJECT_ROOT}/brand/wallpapers/"*.svg "${WEBSITE_PROJECT}/brand/wallpapers/" 2>/dev/null || true

# Sync main files
echo "Syncing main files..."
cp "${PROJECT_ROOT}/README.md" "${WEBSITE_PROJECT}/"
cp "${PROJECT_ROOT}/CONTRIBUTING.md" "${WEBSITE_PROJECT}/"
cp "${PROJECT_ROOT}/LICENSE" "${WEBSITE_PROJECT}/"
cp "${PROJECT_ROOT}/VERSION" "${WEBSITE_PROJECT}/"

# Sync documentation
echo "Syncing documentation..."
cp "${PROJECT_ROOT}/docs/README.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/DESIGN_DECISIONS.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/SECURITY_SUMMARY.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/THREAT_MODEL.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/CREDENTIAL_SECURITY.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/QUICKSTART.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/WHY_NUBIFEROS.md" "${WEBSITE_PROJECT}/docs/"
cp "${PROJECT_ROOT}/docs/DASHBOARD_DESIGN.md" "${WEBSITE_PROJECT}/docs/" 2>/dev/null || true
cp "${PROJECT_ROOT}/docs/SECURITY_SCANNING.md" "${WEBSITE_PROJECT}/docs/" 2>/dev/null || true

# Sync guides
echo "Syncing guides..."
cp "${PROJECT_ROOT}/docs/guides/INCLUDED_TOOLS.md" "${WEBSITE_PROJECT}/docs/guides/" 2>/dev/null || true
cp "${PROJECT_ROOT}/docs/guides/BROWSER_CONFIGURATION.md" "${WEBSITE_PROJECT}/docs/guides/" 2>/dev/null || true
cp "${PROJECT_ROOT}/docs/guides/IDE_PLUGINS.md" "${WEBSITE_PROJECT}/docs/guides/" 2>/dev/null || true
cp "${PROJECT_ROOT}/docs/guides/QUICK_REFERENCE.md" "${WEBSITE_PROJECT}/docs/guides/" 2>/dev/null || true

# Sync components overview
cp "${PROJECT_ROOT}/components/README.md" "${WEBSITE_PROJECT}/docs/COMPONENTS.md"

# Update content guide with sync timestamp
cat > "${WEBSITE_PROJECT}/CONTENT_GUIDE.md" << 'EOF'
# NubiferOS Website Content Guide

**Last synced**: $(date '+%Y-%m-%d %H:%M:%S')
**Source**: CloudLinux project

This content is automatically synced from the main NubiferOS project.
Run `scripts/sync-website-content.sh` in the CloudLinux project to update.

## Contents

### Brand Assets (`brand/`)
- `logo.svg` - Main vector logo
- `nubiferos-logo.png` - PNG logo  
- `brand.conf` - Colors, taglines, URLs
- `README.md` - Branding guidelines
- `brandideas.md` - Brand identity & messaging
- `icons/` - Logo in various sizes
- `wallpapers/` - Cloud provider themed wallpapers

### Documentation (`docs/`)
- `README.md` - Documentation overview
- `WHY_NUBIFEROS.md` - Why choose NubiferOS (comparison with alternatives)
- `THREAT_MODEL.md` - What we protect against (and what we don't)
- `DESIGN_DECISIONS.md` - Why we made key choices
- `SECURITY_SUMMARY.md` - Security features overview
- `CREDENTIAL_SECURITY.md` - Credential management
- `QUICKSTART.md` - Getting started
- `SECURITY_SCANNING.md` - Vulnerability scanning and verification
- `COMPONENTS.md` - Component overview
- `guides/` - User guides

### Root Files
- `README.md` - Main project overview
- `CONTRIBUTING.md` - Contribution guidelines
- `LICENSE` - GPL-3.0
- `VERSION` - Current version
EOF

# Replace the placeholder date with actual date
sed -i "s/\$(date '+%Y-%m-%d %H:%M:%S')/$(date '+%Y-%m-%d %H:%M:%S')/" "${WEBSITE_PROJECT}/CONTENT_GUIDE.md"

echo ""
echo -e "${GREEN}✓ Sync complete!${NC}"
echo "  Destination: ${WEBSITE_PROJECT}"
echo ""
