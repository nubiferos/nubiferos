#!/bin/bash
# Generate Calamares package definition YAMLs from install-cloud-tools.sh
# This extracts all tools and creates organized package selections

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PKG_DIR="${PROJECT_ROOT}/installer/calamares/packages"

echo "=========================================="
echo "Generating Package Definitions"
echo "=========================================="
echo ""

# Create package definitions directory
mkdir -p "${PKG_DIR}"

# Always-installed base dependencies
cat > "${PKG_DIR}/base-dependencies.yaml" << 'EOF'
# Base dependencies always installed regardless of selections
# These are required for cloud development tools

dependencies:
  - id: python3
    name: "Python 3"
    description: "Python runtime and package manager"
    packages:
      - python3
      - python3-pip
      - python3-venv
      - python3-dev
    size_mb: 100
    always_install: true
    
  - id: nodejs
    name: "Node.js"
    description: "JavaScript runtime for CLI tools"
    packages:
      - nodejs
      - npm
    size_mb: 50
    always_install: true
    
  - id: build-essential
    name: "Build Tools"
    description: "Compilers and build tools"
    packages:
      - build-essential
      - gcc
      - g++
      - make
    size_mb: 200
    always_install: true
    
  - id: curl-wget
    name: "Download Tools"
    description: "curl and wget for downloading"
    packages:
      - curl
      - wget
      - ca-certificates
    size_mb: 10
    always_install: true
EOF

# AWS Tools
cat > "${PKG_DIR}/aws-tools.yaml" << 'EOF'
# AWS (Amazon Web Services) Tools

provider:
  id: aws
  name: "AWS (Amazon Web Services)"
  description: "Amazon Web Services cloud platform tools"
  
tools:
  - id: aws-cli
    name: "AWS CLI v2"
    description: "Official AWS command line interface"
    size_mb: 150
    install_script: |
      cd /tmp
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip -q awscliv2.zip
      ./aws/install --update
      rm -rf aws awscliv2.zip
    verify_command: "aws --version"
    dependencies:
      - python3
      - curl-wget
    bookmarks:
      - name: "AWS Console"
        url: "https://console.aws.amazon.com"
      - name: "AWS Documentation"
        url: "https://docs.aws.amazon.com"
      - name: "AWS CLI Reference"
        url: "https://awscli.amazonaws.com/v2/documentation/api/latest/index.html"
    
  - id: aws-sam
    name: "AWS SAM CLI"
    description: "AWS Serverless Application Model CLI"
    size_mb: 100
    packages:
      - aws-sam-cli
    pip_packages:
      - aws-sam-cli
    dependencies:
      - python3
      - aws-cli
    bookmarks:
      - name: "AWS SAM Documentation"
        url: "https://docs.aws.amazon.com/serverless-application-model/"
    
  - id: eksctl
    name: "eksctl"
    description: "Amazon EKS cluster management tool"
    size_mb: 50
    install_script: |
      cd /tmp
      curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
      tar -xzf eksctl_Linux_amd64.tar.gz
      mv eksctl /usr/local/bin/
      rm eksctl_Linux_amd64.tar.gz
    verify_command: "eksctl version"
    dependencies:
      - curl-wget
    bookmarks:
      - name: "eksctl Documentation"
        url: "https://eksctl.io"
    
  - id: aws-copilot
    name: "AWS Copilot"
    description: "AWS container deployment tool"
    size_mb: 50
    install_script: |
      cd /tmp
      curl -Lo copilot https://github.com/aws/copilot-cli/releases/latest/download/copilot-linux
      chmod +x copilot
      mv copilot /usr/local/bin/copilot
    verify_command: "copilot --version"
    dependencies:
      - curl-wget
    
  - id: aws-eb
    name: "AWS Elastic Beanstalk CLI"
    description: "AWS Elastic Beanstalk command line"
    size_mb: 50
    pip_packages:
      - awsebcli
    dependencies:
      - python3
      - aws-cli
    
  - id: boto3
    name: "AWS SDK for Python (boto3)"
    description: "Python library for AWS"
    size_mb: 100
    packages:
      - python3-boto3
    dependencies:
      - python3
EOF

# Azure Tools
cat > "${PKG_DIR}/azure-tools.yaml" << 'EOF'
# Microsoft Azure Tools

provider:
  id: azure
  name: "Microsoft Azure"
  description: "Microsoft Azure cloud platform tools"
  
tools:
  - id: azure-cli
    name: "Azure CLI"
    description: "Official Azure command line interface"
    size_mb: 250
    install_script: |
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    verify_command: "az --version"
    dependencies:
      - python3
      - curl-wget
    bookmarks:
      - name: "Azure Portal"
        url: "https://portal.azure.com"
      - name: "Azure Documentation"
        url: "https://docs.microsoft.com/azure"
      - name: "Azure CLI Reference"
        url: "https://docs.microsoft.com/cli/azure/"
    
  - id: azure-functions
    name: "Azure Functions Core Tools"
    description: "Azure Functions development tools"
    size_mb: 100
    install_script: |
      cd /tmp
      curl -sL https://aka.ms/func-core-tools-linux-x64 -o azure-functions.tar.gz
      mkdir -p /opt/azure-functions
      tar -xzf azure-functions.tar.gz -C /opt/azure-functions
      ln -sf /opt/azure-functions/func /usr/local/bin/func
      rm azure-functions.tar.gz
    verify_command: "func --version"
    dependencies:
      - curl-wget
    
  - id: bicep
    name: "Azure Bicep"
    description: "Azure infrastructure as code language"
    size_mb: 50
    install_script: |
      curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
      chmod +x bicep
      mv bicep /usr/local/bin/bicep
    verify_command: "bicep --version"
    dependencies:
      - curl-wget
EOF

# GCP Tools
cat > "${PKG_DIR}/gcp-tools.yaml" << 'EOF'
# Google Cloud Platform Tools

provider:
  id: gcp
  name: "Google Cloud Platform"
  description: "Google Cloud Platform tools"
  
tools:
  - id: gcloud-sdk
    name: "Google Cloud SDK"
    description: "Official Google Cloud command line tools"
    size_mb: 250
    install_script: |
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
      curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
      apt-get update
      apt-get install -y google-cloud-sdk
    verify_command: "gcloud --version"
    dependencies:
      - curl-wget
    bookmarks:
      - name: "Google Cloud Console"
        url: "https://console.cloud.google.com"
      - name: "Google Cloud Documentation"
        url: "https://cloud.google.com/docs"
      - name: "gcloud CLI Reference"
        url: "https://cloud.google.com/sdk/gcloud/reference"
EOF

# Infrastructure as Code Tools
cat > "${PKG_DIR}/iac-tools.yaml" << 'EOF'
# Infrastructure as Code Tools

category:
  id: iac
  name: "Infrastructure as Code"
  description: "Tools for managing infrastructure as code"
  
tools:
  - id: terraform
    name: "Terraform"
    description: "Infrastructure provisioning tool by HashiCorp"
    size_mb: 50
    install_script: |
      cd /tmp
      TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)
      curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
      unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
      mv terraform /usr/local/bin/
      rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    verify_command: "terraform --version"
    dependencies:
      - curl-wget
    bookmarks:
      - name: "Terraform Documentation"
        url: "https://www.terraform.io/docs"
      - name: "Terraform Registry"
        url: "https://registry.terraform.io"
    
  - id: pulumi
    name: "Pulumi"
    description: "Modern infrastructure as code platform"
    size_mb: 100
    install_script: |
      curl -fsSL https://get.pulumi.com | sh
      mv ~/.pulumi/bin/pulumi /usr/local/bin/
    verify_command: "pulumi version"
    dependencies:
      - curl-wget
    bookmarks:
      - name: "Pulumi Documentation"
        url: "https://www.pulumi.com/docs"
    
  - id: ansible
    name: "Ansible"
    description: "Configuration management and automation"
    size_mb: 50
    packages:
      - ansible
    dependencies:
      - python3
    bookmarks:
      - name: "Ansible Documentation"
        url: "https://docs.ansible.com"
EOF

# Container Tools
cat > "${PKG_DIR}/container-tools.yaml" << 'EOF'
# Container and Kubernetes Tools

category:
  id: containers
  name: "Containers & Kubernetes"
  description: "Container and orchestration tools"
  
tools:
  - id: docker
    name: "Docker"
    description: "Container platform"
    size_mb: 200
    packages:
      - docker.io
      - docker-compose
    post_install_script: |
      systemctl enable docker
      usermod -aG docker $INSTALL_USER
    conflicts_with:
      - podman
    dependencies:
      - build-essential
    bookmarks:
      - name: "Docker Documentation"
        url: "https://docs.docker.com"
      - name: "Docker Hub"
        url: "https://hub.docker.com"
    
  - id: podman
    name: "Podman"
    description: "Daemonless container engine"
    size_mb: 150
    packages:
      - podman
      - podman-compose
    conflicts_with:
      - docker
    bookmarks:
      - name: "Podman Documentation"
        url: "https://podman.io"
    
  - id: kubectl
    name: "kubectl"
    description: "Kubernetes command-line tool"
    size_mb: 50
    install_script: |
      cd /tmp
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      rm kubectl
    verify_command: "kubectl version --client"
    dependencies:
      - curl-wget
    bookmarks:
      - name: "Kubernetes Documentation"
        url: "https://kubernetes.io/docs"
    
  - id: helm
    name: "Helm"
    description: "Kubernetes package manager"
    size_mb: 50
    install_script: |
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    verify_command: "helm version"
    dependencies:
      - curl-wget
      - kubectl
    bookmarks:
      - name: "Helm Documentation"
        url: "https://helm.sh/docs"
    
  - id: minikube
    name: "Minikube"
    description: "Local Kubernetes development"
    size_mb: 100
    install_script: |
      cd /tmp
      curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
      install minikube-linux-amd64 /usr/local/bin/minikube
      rm minikube-linux-amd64
    verify_command: "minikube version"
    dependencies:
      - kubectl
      - docker  # or podman
    bookmarks:
      - name: "Minikube Documentation"
        url: "https://minikube.sigs.k8s.io/docs/"
    
  - id: argocd
    name: "ArgoCD CLI"
    description: "GitOps continuous delivery tool"
    size_mb: 30
    install_script: |
      cd /tmp
      curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      install -m 555 argocd /usr/local/bin/argocd
      rm argocd
    verify_command: "argocd version --client"
    dependencies:
      - kubectl
    bookmarks:
      - name: "ArgoCD Documentation"
        url: "https://argo-cd.readthedocs.io/"
      - name: "ArgoCD GitHub"
        url: "https://github.com/argoproj/argo-cd"
EOF

echo "✓ Package definitions created in: ${PKG_DIR}"
echo ""
echo "Files created:"
ls -1 "${PKG_DIR}"
echo ""
echo "Next steps:"
echo "1. Review package definitions"
echo "2. Create Calamares package selection module"
echo "3. Test installation with selections"
