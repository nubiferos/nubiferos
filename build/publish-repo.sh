#!/bin/bash
# Publish .deb packages to S3-hosted APT repository
# Usage: ./build/publish-repo.sh [--bucket BUCKET] [--gpg-key KEY_ID]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEB_DIR="${PROJECT_ROOT}/output/debs"
REPO_DIR="${PROJECT_ROOT}/output/apt-repo"
BUCKET="${APT_BUCKET:-nubiferos-packages}"
DIST="bookworm"
COMPONENT="main"
ARCH="all"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --bucket) BUCKET="$2"; shift 2 ;;
        --gpg-key) GPG_KEY="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=========================================="
echo "Publishing to APT Repository"
echo "Bucket: s3://${BUCKET}/"
echo "Distribution: ${DIST}"
echo "=========================================="

# Verify debs exist
if ! ls "$DEB_DIR"/*.deb 1>/dev/null 2>&1; then
    echo "ERROR: No .deb files found in $DEB_DIR"
    echo "Run build/build-debs.sh first"
    exit 1
fi

# Create repo structure
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR/pool/main/n"
mkdir -p "$REPO_DIR/dists/${DIST}/${COMPONENT}/binary-${ARCH}"
mkdir -p "$REPO_DIR/dists/${DIST}/${COMPONENT}/binary-amd64"

# Copy debs to pool
for deb in "$DEB_DIR"/*.deb; do
    pkg_name=$(dpkg-deb -f "$deb" Package)
    mkdir -p "$REPO_DIR/pool/main/n/${pkg_name}"
    cp "$deb" "$REPO_DIR/pool/main/n/${pkg_name}/"
    echo "  Added: $(basename "$deb")"
done

# Generate Packages index
cd "$REPO_DIR"
dpkg-scanpackages --arch "$ARCH" pool/ > "dists/${DIST}/${COMPONENT}/binary-${ARCH}/Packages"
gzip -k "dists/${DIST}/${COMPONENT}/binary-${ARCH}/Packages"

# Copy to binary-amd64 so amd64 systems can find arch:all packages
cp "dists/${DIST}/${COMPONENT}/binary-${ARCH}/Packages" "dists/${DIST}/${COMPONENT}/binary-amd64/Packages"
gzip -k "dists/${DIST}/${COMPONENT}/binary-amd64/Packages"

echo "  Generated Packages index ($(wc -l < "dists/${DIST}/${COMPONENT}/binary-${ARCH}/Packages") lines)"

# Generate Release file
cd "dists/${DIST}"
cat > Release << EOF
Origin: NubiferOS
Label: NubiferOS
Suite: ${DIST}
Codename: ${DIST}
Version: 1.0
Architectures: ${ARCH} amd64
Components: ${COMPONENT}
Description: NubiferOS package repository
Date: $(date -Ru)
EOF

# Add checksums to Release
{
    echo "MD5Sum:"
    find "${COMPONENT}" -type f | while read -r f; do
        echo " $(md5sum "$f" | cut -d' ' -f1) $(stat -c%s "$f") $f"
    done
    echo "SHA256:"
    find "${COMPONENT}" -type f | while read -r f; do
        echo " $(sha256sum "$f" | cut -d' ' -f1) $(stat -c%s "$f") $f"
    done
} >> Release

# Sign Release file if GPG key is available
if [ -n "${GPG_KEY:-}" ]; then
    echo "  Signing Release with key ${GPG_KEY}..."
    gpg --default-key "$GPG_KEY" --armor --detach-sign --output Release.gpg Release
    gpg --default-key "$GPG_KEY" --armor --clearsign --output InRelease Release
    echo "  -> Release.gpg, InRelease created"

    # Export public key for client machines
    gpg --armor --export "$GPG_KEY" > "$REPO_DIR/nubiferos-apt-key.gpg"
    echo "  -> Exported signing public key"
elif [ -n "${GPG_PASSPHRASE:-}" ] && [ -n "${GNUPGHOME:-}" ]; then
    # CI mode: use passphrase from env
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)
    if [ -n "$KEY_ID" ]; then
        echo "  Signing Release (CI mode)..."
        echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
            --default-key "$KEY_ID" --armor --detach-sign --output Release.gpg Release
        echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
            --default-key "$KEY_ID" --armor --clearsign --output InRelease Release
        gpg --armor --export "$KEY_ID" > "$REPO_DIR/nubiferos-apt-key.gpg"
        echo "  -> Signed and exported key"
    else
        echo "  WARNING: No GPG key found, repo will be unsigned"
    fi
else
    echo "  WARNING: No GPG key provided, repo will be unsigned"
    echo "  Use --gpg-key KEY_ID or set GPG_KEY env var"
fi

cd "$REPO_DIR"

# Upload to S3
echo ""
echo "Uploading to s3://${BUCKET}/..."

# Upload pool (debs) with normal caching
aws s3 sync "$REPO_DIR/pool/" "s3://${BUCKET}/pool/" \
    --cache-control "max-age=86400" \
    --exclude ".git/*"

# Upload dists (metadata) with no caching to prevent hash mismatches
aws s3 sync "$REPO_DIR/dists/" "s3://${BUCKET}/dists/" \
    --delete \
    --cache-control "no-cache, no-store, must-revalidate" \
    --exclude ".git/*"

# Upload signing key
if [ -f "$REPO_DIR/nubiferos-apt-key.gpg" ]; then
    aws s3 cp "$REPO_DIR/nubiferos-apt-key.gpg" "s3://${BUCKET}/nubiferos-apt-key.gpg" \
        --cache-control "max-age=3600"
fi

# Invalidate CloudFront cache so clients get fresh metadata immediately
CF_DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?contains(Aliases.Items, 'packages.nubiferos.org')].Id" \
    --output text 2>/dev/null || true)
if [ -z "$CF_DIST_ID" ] || [ "$CF_DIST_ID" = "None" ]; then
    # Fallback: try without alias filter
    CF_DIST_ID=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[0].Id" \
        --output text 2>/dev/null || true)
fi
if [ -n "$CF_DIST_ID" ] && [ "$CF_DIST_ID" != "None" ]; then
    echo "Invalidating CloudFront cache (${CF_DIST_ID})..."
    aws cloudfront create-invalidation --distribution-id "$CF_DIST_ID" \
        --paths "/dists/*" "/pool/*" "/nubiferos-apt-key.gpg" 2>/dev/null && \
        echo "  -> Cache invalidation started" || \
        echo "  -> Cache invalidation failed (non-critical)"
else
    echo "  WARNING: No CloudFront distribution found, skipping invalidation"
fi

echo ""
echo "=========================================="
echo "APT Repository Published!"
echo "=========================================="
echo ""
echo "Repository URL: https://packages.nubiferos.org"
echo "S3 Bucket: s3://${BUCKET}/"
echo ""
echo "Client configuration:"
echo "  deb [signed-by=/etc/apt/keyrings/nubiferos.gpg] https://packages.nubiferos.org bookworm main"
echo ""
