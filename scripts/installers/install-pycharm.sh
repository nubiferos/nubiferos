#!/bin/bash
# Install PyCharm Community Edition
# Part of NubiferOS installer scripts

set -e

echo "Installing PyCharm Community Edition..."
echo "This may take a few minutes (downloading ~500MB)..."

cd /tmp

# Get latest version
PYCHARM_VERSION="2024.3"
PYCHARM_URL="https://download.jetbrains.com/python/pycharm-community-${PYCHARM_VERSION}.tar.gz"

# Download and extract
wget -q --show-progress "$PYCHARM_URL" -O pycharm.tar.gz
tar -xzf pycharm.tar.gz -C /opt
rm pycharm.tar.gz

# Find extracted directory and rename
PYCHARM_DIR=$(ls -d /opt/pycharm-community-* 2>/dev/null | head -1)
if [ -d "$PYCHARM_DIR" ]; then
    rm -rf /opt/pycharm-community
    mv "$PYCHARM_DIR" /opt/pycharm-community
fi

# Create desktop entry
cat > /usr/share/applications/pycharm.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=PyCharm Community
Icon=/opt/pycharm-community/bin/pycharm.svg
Exec=/opt/pycharm-community/bin/pycharm %f
Comment=Python IDE for Professional Developers
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-pycharm-ce
EOF

# Create symlink
ln -sf /opt/pycharm-community/bin/pycharm /usr/local/bin/pycharm

# Create desktop shortcut for new users
if [ -d /etc/skel/Desktop ]; then
    cp /usr/share/applications/pycharm.desktop /etc/skel/Desktop/
    chmod +x /etc/skel/Desktop/pycharm.desktop
fi

echo "✓ PyCharm Community Edition installed"
echo "  Launch with: pycharm"
