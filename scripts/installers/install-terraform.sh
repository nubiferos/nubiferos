#!/bin/bash
# Install Terraform - Infrastructure as Code
# Part of NubiferOS installer scripts

set -e

echo "Installing Terraform..."

# Add HashiCorp GPG key and repository
wget -q -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" | tee /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y terraform

echo "✓ Terraform installed"
terraform --version
