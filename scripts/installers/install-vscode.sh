#!/bin/bash
# Install Visual Studio Code
# Part of NubiferOS installer scripts

set -e

echo "Installing Visual Studio Code..."

# Add Microsoft GPG key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
rm /tmp/packages.microsoft.gpg

# Add VS Code repository
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

# Install
apt-get update
apt-get install -y code

# Create desktop shortcut for new users
if [ -d /etc/skel/Desktop ]; then
    cat > /etc/skel/Desktop/code.desktop << 'EOF'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/usr/bin/code %F
Icon=vscode
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=Development;IDE;
MimeType=text/plain;
EOF
    chmod +x /etc/skel/Desktop/code.desktop
fi

echo "✓ Visual Studio Code installed"
code --version
