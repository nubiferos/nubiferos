#!/bin/bash
# Install Grype vulnerability scanner
set -e

echo "Installing Grype..."

curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

echo "✓ Grype installed"
grype version
