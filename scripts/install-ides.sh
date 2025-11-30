#!/bin/bash
# Install IDEs not available in Debian repos
# Run this after system installation

set -e

echo "=========================================="
echo "NubiferOS IDE Installer"
echo "=========================================="
echo ""
echo "This script installs IDEs not available in Debian repos:"
echo "  - VS Code (Microsoft)"
echo "  - IntelliJ IDEA Community"
echo "  - PyCharm Community"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Function to install VS Code
install_vscode() {
    echo "Installing VS Code..."
    
    # Add Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    rm packages.microsoft.gpg
    
    # Add VS Code repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    # Install
    apt-get update
    apt-get install -y code
    
    echo "✓ VS Code installed"
}

# Function to install IntelliJ IDEA Community
install_intellij() {
    echo "Installing IntelliJ IDEA Community..."
    
    # Download latest version
    IDEA_VERSION="2024.3"
    IDEA_BUILD="243.21565.193"
    IDEA_URL="https://download.jetbrains.com/idea/ideaIC-${IDEA_VERSION}.tar.gz"
    
    # Download and extract
    cd /opt
    wget -q "$IDEA_URL" -O idea.tar.gz
    tar -xzf idea.tar.gz
    rm idea.tar.gz
    
    # Find extracted directory
    IDEA_DIR=$(ls -d idea-IC-* | head -1)
    mv "$IDEA_DIR" intellij-idea-community
    
    # Create desktop entry
    cat > /usr/share/applications/intellij-idea.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Community
Icon=/opt/intellij-idea-community/bin/idea.svg
Exec=/opt/intellij-idea-community/bin/idea.sh %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea-ce
EOF
    
    # Create symlink
    ln -sf /opt/intellij-idea-community/bin/idea.sh /usr/local/bin/idea
    
    echo "✓ IntelliJ IDEA Community installed"
}

# Function to install PyCharm Community
install_pycharm() {
    echo "Installing PyCharm Community..."
    
    # Download latest version
    PYCHARM_VERSION="2024.3"
    PYCHARM_URL="https://download.jetbrains.com/python/pycharm-community-${PYCHARM_VERSION}.tar.gz"
    
    # Download and extract
    cd /opt
    wget -q "$PYCHARM_URL" -O pycharm.tar.gz
    tar -xzf pycharm.tar.gz
    rm pycharm.tar.gz
    
    # Find extracted directory
    PYCHARM_DIR=$(ls -d pycharm-community-* | head -1)
    mv "$PYCHARM_DIR" pycharm-community
    
    # Create desktop entry
    cat > /usr/share/applications/pycharm.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=PyCharm Community
Icon=/opt/pycharm-community/bin/pycharm.svg
Exec=/opt/pycharm-community/bin/pycharm.sh %f
Comment=Python IDE for Professional Developers
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-pycharm-ce
EOF
    
    # Create symlink
    ln -sf /opt/pycharm-community/bin/pycharm.sh /usr/local/bin/pycharm
    
    echo "✓ PyCharm Community installed"
}

# Menu
echo "Select IDEs to install:"
echo "  1) VS Code"
echo "  2) IntelliJ IDEA Community"
echo "  3) PyCharm Community"
echo "  4) All of the above"
echo "  5) Cancel"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        install_vscode
        ;;
    2)
        install_intellij
        ;;
    3)
        install_pycharm
        ;;
    4)
        install_vscode
        install_intellij
        install_pycharm
        ;;
    5)
        echo "Cancelled"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Installed IDEs:"
[ -f /usr/bin/code ] && echo "  ✓ VS Code (command: code)"
[ -f /usr/local/bin/idea ] && echo "  ✓ IntelliJ IDEA (command: idea)"
[ -f /usr/local/bin/pycharm ] && echo "  ✓ PyCharm (command: pycharm)"
echo ""
echo "Run the IDE plugin installer to configure extensions:"
echo "  sudo /usr/local/bin/install-ide-plugins"
echo ""
