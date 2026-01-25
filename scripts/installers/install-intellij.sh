#!/bin/bash
# Install IntelliJ IDEA Community Edition
# Part of NubiferOS installer scripts

set -e

echo "Installing IntelliJ IDEA Community Edition..."
echo "This may take a few minutes (downloading ~800MB)..."

cd /tmp

# Get latest version info
IDEA_VERSION="2024.3"
IDEA_URL="https://download.jetbrains.com/idea/ideaIC-${IDEA_VERSION}.tar.gz"

# Download and extract
wget -q --show-progress "$IDEA_URL" -O idea.tar.gz
tar -xzf idea.tar.gz -C /opt
rm idea.tar.gz

# Find extracted directory and rename
IDEA_DIR=$(ls -d /opt/idea-IC-* 2>/dev/null | head -1)
if [ -d "$IDEA_DIR" ]; then
    rm -rf /opt/intellij-idea-community
    mv "$IDEA_DIR" /opt/intellij-idea-community
fi

# Create desktop entry
cat > /usr/share/applications/intellij-idea.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Community
Icon=/opt/intellij-idea-community/bin/idea.svg
Exec=/opt/intellij-idea-community/bin/idea %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea-ce
EOF

# Create symlink
ln -sf /opt/intellij-idea-community/bin/idea /usr/local/bin/idea

# Create desktop shortcut for new users
if [ -d /etc/skel/Desktop ]; then
    cp /usr/share/applications/intellij-idea.desktop /etc/skel/Desktop/
    chmod +x /etc/skel/Desktop/intellij-idea.desktop
fi

echo "✓ IntelliJ IDEA Community Edition installed"
echo "  Launch with: idea"
