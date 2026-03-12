#!/bin/bash
# Install Trivy vulnerability scanner
set -e

echo "Installing Trivy..."

# Add Trivy repo
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor -o /usr/share/keyrings/trivy.gpg

# Use upstream Debian codename (not NubiferOS codename) since Trivy
# only publishes for standard Debian/Ubuntu releases
DEBIAN_CODENAME=$(grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || echo "bookworm")
# Map NubiferOS codenames to upstream Debian
case "$DEBIAN_CODENAME" in
    nimbus|nubifer*) DEBIAN_CODENAME="bookworm" ;;
esac

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb ${DEBIAN_CODENAME} main" | \
    tee /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y trivy

echo "✓ Trivy installed"
trivy version
