#!/bin/bash
# Install Trivy vulnerability scanner
set -e

echo "Installing Trivy..."

# Add Trivy repo
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor -o /usr/share/keyrings/trivy.gpg

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
    tee /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y trivy

echo "✓ Trivy installed"
trivy version
