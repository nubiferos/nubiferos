#!/bin/bash
# Install NubiferOS Credential Manager

set -e

echo "Installing NubiferOS Credential Manager..."

# Install pass (password-store) and GPG
echo "Installing pass and GPG..."
sudo apt-get install -y pass gnupg

# Make credential manager executable
chmod +x nubifer-creds

# Install to system
sudo cp nubifer-creds /usr/local/bin/

# Create audit log directory
mkdir -p ~/.nubifer
chmod 700 ~/.nubifer

echo "✓ Credential Manager installed successfully"
echo ""
echo "Next steps:"
echo "1. Generate GPG key (if you don't have one):"
echo "   gpg --full-generate-key"
echo ""
echo "2. Initialize pass:"
echo "   pass init <your-gpg-key-id>"
echo ""
echo "3. Add credentials:"
echo "   nubifer-creds add --type aws --name production"
echo ""
echo "Documentation:"
echo "  - /usr/share/doc/nubifer/CREDENTIAL_SECURITY.md"
echo "  - /usr/share/doc/nubifer/CREDENTIAL_SOLUTIONS_COMPARISON.md"
