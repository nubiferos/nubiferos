#!/bin/bash
# Install additional cloud SDKs not available in Debian repos
# Run this after installation if you need GCP or other cloud tools

set -e

echo "=========================================="
echo "NubiferOS Cloud SDK Installer"
echo "=========================================="
echo ""
echo "This script installs cloud SDKs not available in Debian repos:"
echo "  • Google Cloud SDK"
echo "  • Additional Azure tools"
echo "  • Terraform"
echo "  • Kubernetes tools"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Don't run this as root. Run as your regular user."
    exit 1
fi

# Install Google Cloud SDK
install_gcp_sdk() {
    echo "Installing Google Cloud SDK..."
    
    # Add Google Cloud SDK repository
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    
    sudo apt-get update
    sudo apt-get install -y google-cloud-cli
    
    echo "✓ Google Cloud SDK installed"
}

# Install additional Python cloud libraries via pip
install_python_cloud_libs() {
    echo "Installing additional Python cloud libraries..."
    
    # Create virtual environment for cloud tools
    python3 -m venv ~/.local/share/cloud-env
    source ~/.local/share/cloud-env/bin/activate
    
    # Install cloud libraries
    pip install --upgrade pip
    pip install google-cloud-storage
    pip install google-cloud-compute
    pip install azure-cli
    pip install azure-storage-blob
    
    # Create activation script
    cat > ~/.local/bin/activate-cloud-env << 'EOF'
#!/bin/bash
# Activate cloud tools virtual environment
source ~/.local/share/cloud-env/bin/activate
echo "✓ Cloud tools environment activated"
echo "Available tools: gcloud, az, python cloud libraries"
EOF
    chmod +x ~/.local/bin/activate-cloud-env
    
    deactivate
    echo "✓ Python cloud libraries installed in virtual environment"
    echo "  Run 'activate-cloud-env' to use them"
}

# Install Terraform
install_terraform() {
    echo "Installing Terraform..."
    
    # Add HashiCorp repository
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    sudo apt-get update
    sudo apt-get install -y terraform
    
    echo "✓ Terraform installed"
}

# Install Kubernetes tools
install_k8s_tools() {
    echo "Installing Kubernetes tools..."
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    # Install helm
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
    
    echo "✓ Kubernetes tools installed"
}

# Main menu
echo "Select what to install:"
echo "1) Google Cloud SDK"
echo "2) Python cloud libraries (virtual env)"
echo "3) Terraform"
echo "4) Kubernetes tools (kubectl, helm)"
echo "5) All of the above"
echo "6) Exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        install_gcp_sdk
        ;;
    2)
        install_python_cloud_libs
        ;;
    3)
        install_terraform
        ;;
    4)
        install_k8s_tools
        ;;
    5)
        install_gcp_sdk
        install_python_cloud_libs
        install_terraform
        install_k8s_tools
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "✓ Cloud SDK installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  • Run 'gcloud init' to configure Google Cloud"
echo "  • Run 'az login' to configure Azure"
echo "  • Run 'activate-cloud-env' for Python cloud libraries"
echo "  • Run 'terraform --version' to verify Terraform"
echo "  • Run 'kubectl version --client' to verify Kubernetes tools"
echo ""