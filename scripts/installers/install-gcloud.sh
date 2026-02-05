#!/bin/bash
# Install Google Cloud SDK
set -e

echo "Installing Google Cloud SDK..."

# Add Google Cloud SDK repo
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Import Google Cloud public key
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Install
apt-get update
apt-get install -y google-cloud-cli

echo "✓ Google Cloud SDK installed"
gcloud version
