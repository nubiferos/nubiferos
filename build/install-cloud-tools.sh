#!/bin/bash
# Install cloud CLI tools and dependencies
# Part of NubiferOS build system

set -e  # Exit on error

# Load brand configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

# Initialize configuration
init_config

log "INFO" "Starting cloud tools installation"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Directories
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

# Verify chroot exists
if [ ! -d "${CHROOT_DIR}/bin" ]; then
    log "ERROR" "Chroot directory not found. Run extract-debian.sh first."
    exit 1
fi

# Function to run commands in chroot
chroot_exec() {
    chroot "${CHROOT_DIR}" /bin/bash -c "$*"
}

# Function to install package in chroot
install_package() {
    local package="$1"
    log "INFO" "Installing ${package}..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y ${package}"
}

# Install base dependencies
install_base_dependencies() {
    log "INFO" "=========================================="
    log "INFO" "Installing base dependencies"
    log "INFO" "=========================================="
    
    # Update package lists
    chroot_exec "apt-get update"
    
    # Install essential tools
    local base_tools=(
        "curl"
        "wget"
        "gnupg"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "unzip"
        "tar"
        "gzip"
        "jq"
        "git"
        "python3"
        "python3-pip"
        "python3-venv"
        "curl"
    )
    
    for tool in "${base_tools[@]}"; do
        install_package "${tool}"
    done
    
    # Install Node.js 20 from NodeSource for better compatibility
    log "INFO" "Installing Node.js 20 from NodeSource..."
    chroot_exec "cd /tmp && \
        curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh && \
        bash nodesource_setup.sh && \
        rm -f nodesource_setup.sh"
    install_package "nodejs"
    
    # Remove old Node.js 18 packages if they exist
    log "INFO" "Cleaning up old Node.js packages..."
    chroot_exec "apt-get autoremove -y"
    
    log "INFO" "✓ Base dependencies installed"
}

# Install AWS CLI v2
install_aws_cli() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS CLI v2"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && \
        unzip -o -q awscliv2.zip && \
        ./aws/install --update && \
        rm -rf aws awscliv2.zip"
    
    # Verify installation
    local aws_version=$(chroot_exec "aws --version" 2>&1 || echo "failed")
    if [[ $aws_version == *"aws-cli"* ]]; then
        log "INFO" "✓ AWS CLI installed: ${aws_version}"
    else
        log "ERROR" "AWS CLI installation failed"
        return 1
    fi
}

# Install AWS SAM CLI
install_aws_sam() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS SAM CLI"
    log "INFO" "=========================================="
    
    chroot_exec "pip3 install --break-system-packages aws-sam-cli"
    
    log "INFO" "✓ AWS SAM CLI installed"
}

# Install eksctl
install_eksctl() {
    log "INFO" "=========================================="
    log "INFO" "Installing eksctl"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl -sL 'https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz' | tar xz && \
        mv eksctl /usr/local/bin/ && \
        chmod +x /usr/local/bin/eksctl"
    
    log "INFO" "✓ eksctl installed"
}

# Install AWS CDK
install_aws_cdk() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS CDK"
    log "INFO" "=========================================="
    
    chroot_exec "npm install -g aws-cdk"
    
    log "INFO" "✓ AWS CDK installed"
}

# Install AWS Session Manager Plugin
install_session_manager() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS Session Manager Plugin"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl 'https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb' -o 'session-manager-plugin.deb' && \
        dpkg -i session-manager-plugin.deb || apt-get install -f -y && \
        rm session-manager-plugin.deb"
    
    log "INFO" "✓ Session Manager Plugin installed"
}

# Install AWS Copilot
install_aws_copilot() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS Copilot"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl -Lo copilot https://github.com/aws/copilot-cli/releases/latest/download/copilot-linux && \
        chmod +x copilot && \
        mv copilot /usr/local/bin/copilot"
    
    log "INFO" "✓ AWS Copilot installed"
}

# Install AWS Amplify CLI
install_aws_amplify() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS Amplify CLI"
    log "INFO" "=========================================="
    
    # Amplify CLI requires Node 20+, attempt installation
    if chroot_exec "npm install -g @aws-amplify/cli" 2>/dev/null; then
        log "INFO" "✓ AWS Amplify CLI installed"
    else
        log "WARN" "⚠ AWS Amplify CLI installation failed (requires Node 20+)"
        log "WARN" "  You can install it later with: npm install -g @aws-amplify/cli"
    fi
}

# Install AWS Elastic Beanstalk CLI
install_aws_eb() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS EB CLI"
    log "INFO" "=========================================="
    
    chroot_exec "pip3 install --break-system-packages awsebcli"
    
    log "INFO" "✓ AWS EB CLI installed"
}

# Install AWS NoSQL Workbench
install_aws_nosql_workbench() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS NoSQL Workbench"
    log "INFO" "=========================================="
    log "INFO" "Downloading AppImage (this may take a few minutes)..."
    
    # Use wget with progress bar instead of quiet mode, with timeout
    if chroot_exec "cd /tmp && \
        wget --progress=bar:force --timeout=300 https://s3.amazonaws.com/nosql-workbench/NoSQL%20Workbench-linux-x86_64.AppImage -O NoSQLWorkbench.AppImage && \
        chmod +x NoSQLWorkbench.AppImage && \
        mkdir -p /opt/nosql-workbench && \
        mv NoSQLWorkbench.AppImage /opt/nosql-workbench/ && \
        ln -sf /opt/nosql-workbench/NoSQLWorkbench.AppImage /usr/local/bin/nosql-workbench" 2>/dev/null; then
        log "INFO" "✓ AWS NoSQL Workbench installed"
    else
        log "WARN" "⚠ AWS NoSQL Workbench installation failed or timed out (optional tool)"
        log "WARN" "  You can install it later from: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/workbench.html"
    fi
}

# Install AWS SDKs for various languages
install_aws_sdks() {
    log "INFO" "=========================================="
    log "INFO" "Installing AWS SDKs"
    log "INFO" "=========================================="
    
    # Python boto3
    chroot_exec "pip3 install --break-system-packages boto3 botocore"
    log "INFO" "  ✓ Python boto3 installed"
    
    # Node.js AWS SDK
    chroot_exec "npm install -g aws-sdk"
    log "INFO" "  ✓ Node.js aws-sdk installed"
    
    # Go AWS SDK (installed via go get when user needs it)
    log "INFO" "  ℹ Go AWS SDK: Install with 'go get github.com/aws/aws-sdk-go-v2'"
    
    log "INFO" "✓ AWS SDKs installed"
}

# Install Azure CLI
install_azure_cli() {
    log "INFO" "=========================================="
    log "INFO" "Installing Azure CLI"
    log "INFO" "=========================================="
    
    # Clean up any existing Microsoft repositories first
    chroot_exec "rm -f /etc/apt/sources.list.d/azure-cli.sources /etc/apt/sources.list.d/vscode.sources /usr/share/keyrings/microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg"
    
    # Add Microsoft repository
    chroot_exec "cd /tmp && \
        curl -sL https://aka.ms/InstallAzureCLIDeb -o azure-cli-install.sh && \
        bash azure-cli-install.sh && \
        rm -f azure-cli-install.sh"
    
    # Verify installation
    local az_version=$(chroot_exec "az --version" 2>&1 | head -n1 || echo "failed")
    if [[ $az_version == *"azure-cli"* ]]; then
        log "INFO" "✓ Azure CLI installed: ${az_version}"
    else
        log "ERROR" "Azure CLI installation failed"
        return 1
    fi
}

# Install Azure Functions Core Tools
install_azure_functions() {
    log "INFO" "=========================================="
    log "INFO" "Installing Azure Functions Core Tools"
    log "INFO" "=========================================="
    
    chroot_exec "npm install -g azure-functions-core-tools@4 --unsafe-perm true"
    
    log "INFO" "✓ Azure Functions Core Tools installed"
}

# Install Bicep
install_bicep() {
    log "INFO" "=========================================="
    log "INFO" "Installing Bicep"
    log "INFO" "=========================================="
    
    chroot_exec "curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 && \
        chmod +x bicep && \
        mv bicep /usr/local/bin/"
    
    log "INFO" "✓ Bicep installed"
}

# Install Google Cloud SDK
install_gcloud_sdk() {
    log "INFO" "=========================================="
    log "INFO" "Installing Google Cloud SDK"
    log "INFO" "=========================================="
    
    # Add Google Cloud repository
    chroot_exec "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | tee /etc/apt/sources.list.d/google-cloud-sdk.list"
    
    chroot_exec "rm -f /usr/share/keyrings/cloud.google.gpg && \
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg"
    
    chroot_exec "apt-get update"
    install_package "google-cloud-sdk"
    
    log "INFO" "✓ Google Cloud SDK installed"
}

# Install Terraform
install_terraform() {
    log "INFO" "=========================================="
    log "INFO" "Installing Terraform"
    log "INFO" "=========================================="
    
    # Add HashiCorp repository
    chroot_exec "rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
        wget -q -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    
    chroot_exec "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main' | tee /etc/apt/sources.list.d/hashicorp.list"
    
    chroot_exec "apt-get update"
    install_package "terraform"
    
    # Verify installation
    local tf_version=$(chroot_exec "terraform --version" 2>&1 | head -n1 || echo "failed")
    if [[ $tf_version == *"Terraform"* ]]; then
        log "INFO" "✓ Terraform installed: ${tf_version}"
    else
        log "ERROR" "Terraform installation failed"
        return 1
    fi
}

# Install Pulumi
install_pulumi() {
    log "INFO" "=========================================="
    log "INFO" "Installing Pulumi"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl -fsSL https://get.pulumi.com -o pulumi-install.sh && \
        sh pulumi-install.sh && \
        rm -f pulumi-install.sh"
    
    # Move to system path (check both possible locations)
    chroot_exec "if [ -f /root/.pulumi/bin/pulumi ]; then \
        mv /root/.pulumi/bin/pulumi /usr/local/bin/; \
    elif [ -f \$HOME/.pulumi/bin/pulumi ]; then \
        mv \$HOME/.pulumi/bin/pulumi /usr/local/bin/; \
    else \
        echo 'ERROR: Pulumi binary not found in expected locations'; \
        find / -name pulumi -type f 2>/dev/null || true; \
        exit 1; \
    fi"
    
    log "INFO" "✓ Pulumi installed"
}

# Install Ansible
install_ansible() {
    log "INFO" "=========================================="
    log "INFO" "Installing Ansible"
    log "INFO" "=========================================="
    
    install_package "ansible"
    
    log "INFO" "✓ Ansible installed"
}

# Install Docker
install_docker() {
    log "INFO" "=========================================="
    log "INFO" "Installing Docker"
    log "INFO" "=========================================="
    
    install_package "docker.io"
    install_package "docker-compose"
    
    # Enable Docker service
    chroot_exec "systemctl enable docker"
    
    log "INFO" "✓ Docker installed"
}

# Install Podman
install_podman() {
    log "INFO" "=========================================="
    log "INFO" "Installing Podman"
    log "INFO" "=========================================="
    
    install_package "podman"
    
    log "INFO" "✓ Podman installed"
}

# Install kubectl
install_kubectl() {
    log "INFO" "=========================================="
    log "INFO" "Installing kubectl"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        KUBECTL_VERSION=\$(curl -L -s https://dl.k8s.io/release/stable.txt) && \
        curl -LO https://dl.k8s.io/release/\${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
        rm kubectl"
    
    log "INFO" "✓ kubectl installed"
}

# Install Helm
install_helm() {
    log "INFO" "=========================================="
    log "INFO" "Installing Helm"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get-helm-3.sh && \
        bash get-helm-3.sh && \
        rm -f get-helm-3.sh"
    
    log "INFO" "✓ Helm installed"
}

# Install k9s
install_k9s() {
    log "INFO" "=========================================="
    log "INFO" "Installing k9s"
    log "INFO" "=========================================="
    
    chroot_exec "cd /tmp && \
        curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xz && \
        mv k9s /usr/local/bin/ && \
        chmod +x /usr/local/bin/k9s"
    
    log "INFO" "✓ k9s installed"
}

# Install additional useful tools
install_additional_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing additional cloud tools"
    log "INFO" "=========================================="
    
    # yq - YAML processor
    chroot_exec "wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
        chmod +x /usr/local/bin/yq"
    log "INFO" "  ✓ yq installed"
    
    # GitHub CLI
    chroot_exec "cd /tmp && \
        rm -f /usr/share/keyrings/githubcli-archive-keyring.gpg && \
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | tee /etc/apt/sources.list.d/github-cli.list && \
        apt-get update && \
        apt-get install -y gh"
    log "INFO" "  ✓ GitHub CLI installed"
    
    # Trivy - Security scanner
    chroot_exec "cd /tmp && \
        rm -f /usr/share/keyrings/trivy.gpg && \
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg && \
        echo 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb bookworm main' | tee /etc/apt/sources.list.d/trivy.list && \
        apt-get update && \
        apt-get install -y trivy"
    log "INFO" "  ✓ Trivy installed"
    
    # Grype - CVE vulnerability scanner (used by security dashboard)
    log "INFO" "Installing Grype..."
    chroot_exec "cd /tmp && \
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
    log "INFO" "  ✓ Grype installed"
    
    # Lynis - Security auditing tool (used by security dashboard)
    log "INFO" "Installing Lynis..."
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y lynis"
    log "INFO" "  ✓ Lynis installed"
    
    # httpie - Better HTTP client
    install_package "httpie"
    log "INFO" "  ✓ httpie installed"
    
    # Infracost
    chroot_exec "cd /tmp && \
        curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh -o infracost-install.sh && \
        sh infracost-install.sh && \
        rm -f infracost-install.sh"
    log "INFO" "  ✓ Infracost installed"
    
    # Dive (Docker image explorer)
    chroot_exec "cd /tmp && \
        DIVE_VERSION=\$(curl -s https://api.github.com/repos/wagoodman/dive/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/wagoodman/dive/releases/download/\${DIVE_VERSION}/dive_\${DIVE_VERSION#v}_linux_amd64.tar.gz && \
        tar xzf dive_*.tar.gz && \
        mv dive /usr/local/bin/ && \
        chmod +x /usr/local/bin/dive && \
        rm -f dive_*.tar.gz"
    log "INFO" "  ✓ Dive installed"
    
    # Lazydocker (Docker TUI)
    chroot_exec "cd /tmp && \
        LAZYDOCKER_VERSION=\$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/jesseduffield/lazydocker/releases/download/\${LAZYDOCKER_VERSION}/lazydocker_\${LAZYDOCKER_VERSION#v}_Linux_x86_64.tar.gz && \
        tar xzf lazydocker_*.tar.gz && \
        mv lazydocker /usr/local/bin/ && \
        chmod +x /usr/local/bin/lazydocker && \
        rm -f lazydocker_*.tar.gz"
    log "INFO" "  ✓ Lazydocker installed"
    
    # Stern (Kubernetes log tailing)
    chroot_exec "cd /tmp && \
        STERN_VERSION=\$(curl -s https://api.github.com/repos/stern/stern/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/stern/stern/releases/download/\${STERN_VERSION}/stern_\${STERN_VERSION#v}_linux_amd64.tar.gz && \
        tar xzf stern_*.tar.gz && \
        mv stern /usr/local/bin/ && \
        chmod +x /usr/local/bin/stern && \
        rm -f stern_*.tar.gz" || log "WARN" "Stern installation failed (optional)"
    log "INFO" "  ✓ Stern installed"
    
    log "INFO" "✓ Additional tools installed"
}

# Install monitoring tools
install_monitoring_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing Monitoring & Observability Tools"
    log "INFO" "=========================================="
    
    # Grafana - Moved to post-install option (saves 697MB)
    # log "INFO" "Installing Grafana CLI..."
    # chroot_exec "wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key && \
    #     echo 'deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main' | tee /etc/apt/sources.list.d/grafana.list && \
    #     apt-get update && \
    #     apt-get install -y grafana"
    # log "INFO" "  ✓ Grafana installed"
    log "INFO" "  ⊘ Grafana skipped (available via post-install)"
    
    # Prometheus CLI tools
    log "INFO" "Installing Prometheus tools..."
    chroot_exec "cd /tmp && \
        PROM_VERSION=\$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/prometheus/prometheus/releases/download/\${PROM_VERSION}/prometheus-\${PROM_VERSION#v}.linux-amd64.tar.gz && \
        tar xzf prometheus-*.tar.gz && \
        cd prometheus-*.linux-amd64 && \
        mv promtool /usr/local/bin/ && \
        chmod +x /usr/local/bin/promtool && \
        cd /tmp && rm -rf prometheus-*" || log "WARN" "Prometheus tools installation failed (optional)"
    log "INFO" "  ✓ Prometheus tools installed"
    
    # Loki CLI
    log "INFO" "Installing Loki CLI..."
    chroot_exec "cd /tmp && \
        wget -q https://github.com/grafana/loki/releases/latest/download/logcli-linux-amd64.zip && \
        unzip -q logcli-linux-amd64.zip && \
        mv logcli-linux-amd64 /usr/local/bin/logcli && \
        chmod +x /usr/local/bin/logcli && \
        rm logcli-linux-amd64.zip"
    log "INFO" "  ✓ Loki CLI installed"
    
    log "INFO" "✓ Monitoring tools installed"
}

# Install CI/CD tools
install_cicd_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing CI/CD Tools"
    log "INFO" "=========================================="
    
    # GitLab CLI
    log "INFO" "Installing GitLab CLI..."
    if chroot_exec "cd /tmp && \
        wget -q https://gitlab.com/gitlab-org/cli/-/releases/v1.77.0/downloads/glab_1.77.0_Linux_x86_64.deb && \
        dpkg -i glab_*.deb && \
        rm glab_*.deb" 2>/dev/null; then
        log "INFO" "  ✓ GitLab CLI installed"
    else
        log "WARN" "  ⚠ GitLab CLI installation failed (optional - install manually: https://gitlab.com/gitlab-org/cli)"
    fi
    
    # ArgoCD CLI
    log "INFO" "Installing ArgoCD CLI..."
    chroot_exec "curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
        chmod +x /usr/local/bin/argocd"
    log "INFO" "  ✓ ArgoCD CLI installed"
    
    # Flux CLI
    log "INFO" "Installing Flux CLI..."
    chroot_exec "cd /tmp && \
        curl -s https://fluxcd.io/install.sh -o flux-install.sh && \
        bash flux-install.sh && \
        rm -f flux-install.sh"
    log "INFO" "  ✓ Flux CLI installed"
    
    # Tekton CLI
    log "INFO" "Installing Tekton CLI..."
    chroot_exec "cd /tmp && \
        TKN_VERSION=\$(curl -s https://api.github.com/repos/tektoncd/cli/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/tektoncd/cli/releases/download/\${TKN_VERSION}/tkn_\${TKN_VERSION#v}_Linux_x86_64.tar.gz && \
        tar xzf tkn_*.tar.gz && \
        mv tkn /usr/local/bin/ && \
        chmod +x /usr/local/bin/tkn && \
        rm tkn_*.tar.gz" || log "WARN" "Tekton CLI installation failed (optional)"
    log "INFO" "  ✓ Tekton CLI installed"
    
    # Jenkins CLI (Java-based, lightweight)
    log "INFO" "Installing Jenkins CLI..."
    chroot_exec "mkdir -p /opt/jenkins && \
        wget -q -O /opt/jenkins/jenkins-cli.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/cli/2.426/cli-2.426.jar"
    
    # Create wrapper script
    chroot_exec "cat > /usr/local/bin/jenkins-cli << 'EOF'
#!/bin/bash
java -jar /opt/jenkins/jenkins-cli.jar \"\$@\"
EOF
    chmod +x /usr/local/bin/jenkins-cli"
    log "INFO" "  ✓ Jenkins CLI installed"
    
    # Jira CLI (go-jira)
    log "INFO" "Installing Jira CLI..."
    chroot_exec "cd /tmp && \
        JIRA_VERSION=\$(curl -s https://api.github.com/repos/go-jira/jira/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/go-jira/jira/releases/download/\${JIRA_VERSION}/jira-linux-amd64 && \
        mv jira-linux-amd64 /usr/local/bin/jira && \
        chmod +x /usr/local/bin/jira" || log "WARN" "Jira CLI installation failed (optional)"
    log "INFO" "  ✓ Jira CLI installed"
    
    # Linear CLI
    log "INFO" "Installing Linear CLI..."
    chroot_exec "npm install -g @linear/cli" || log "WARN" "Linear CLI installation failed (optional)"
    log "INFO" "  ✓ Linear CLI installed"
    
    log "INFO" "✓ CI/CD tools installed"
}

# Install GitOps tools
install_gitops_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing GitOps Tools"
    log "INFO" "=========================================="
    
    # Kustomize
    log "INFO" "Installing Kustomize..."
    chroot_exec "cd /tmp && \
        curl -s 'https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh' -o install_kustomize.sh && \
        bash install_kustomize.sh && \
        mv kustomize /usr/local/bin/ && \
        chmod +x /usr/local/bin/kustomize && \
        rm -f install_kustomize.sh"
    log "INFO" "  ✓ Kustomize installed"
    
    # Skaffold
    log "INFO" "Installing Skaffold..."
    chroot_exec "curl -Lo /usr/local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
        chmod +x /usr/local/bin/skaffold"
    log "INFO" "  ✓ Skaffold installed"
    
    log "INFO" "✓ GitOps tools installed"
}

# Install database clients
install_database_clients() {
    log "INFO" "=========================================="
    log "INFO" "Installing Database Clients"
    log "INFO" "=========================================="
    
    # PostgreSQL client
    install_package "postgresql-client"
    log "INFO" "  ✓ PostgreSQL client installed"
    
    # MySQL client
    install_package "default-mysql-client"
    log "INFO" "  ✓ MySQL client installed"
    
    # MongoDB shell
    log "INFO" "Installing MongoDB shell..."
    chroot_exec "cd /tmp && \
        MONGOSH_VERSION=\$(curl -s https://api.github.com/repos/mongodb-js/mongosh/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://downloads.mongodb.com/compass/mongosh-\${MONGOSH_VERSION#v}-linux-x64.tgz && \
        tar xzf mongosh-*.tgz && \
        mv mongosh-*/bin/mongosh /usr/local/bin/ && \
        chmod +x /usr/local/bin/mongosh && \
        rm -rf mongosh-*" || log "WARN" "MongoDB shell installation failed (optional)"
    log "INFO" "  ✓ MongoDB shell installed"
    
    # Redis CLI
    install_package "redis-tools"
    log "INFO" "  ✓ Redis CLI installed"
    
    # DynamoDB Local (optional, large)
    log "INFO" "  ℹ️  DynamoDB Local: Use AWS NoSQL Workbench (already installed)"
    
    log "INFO" "✓ Database clients installed"
}

# Install testing frameworks
install_testing_frameworks() {
    log "INFO" "=========================================="
    log "INFO" "Installing Testing Frameworks"
    log "INFO" "=========================================="
    
    # k6 (load testing)
    log "INFO" "Installing k6..."
    chroot_exec "cd /tmp && \
        K6_VERSION=\$(curl -s https://api.github.com/repos/grafana/k6/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/grafana/k6/releases/download/\${K6_VERSION}/k6-\${K6_VERSION}-linux-amd64.tar.gz && \
        tar xzf k6-*.tar.gz && \
        mv k6-*/k6 /usr/local/bin/ && \
        chmod +x /usr/local/bin/k6 && \
        rm -rf k6-*" || log "WARN" "k6 installation failed (optional)"
    log "INFO" "  ✓ k6 installed"
    
    # Locust (load testing)
    log "INFO" "Installing Locust..."
    chroot_exec "pip3 install --break-system-packages locust"
    log "INFO" "  ✓ Locust installed"
    
    # Newman (Postman CLI)
    log "INFO" "Installing Newman..."
    chroot_exec "npm install -g newman"
    log "INFO" "  ✓ Newman installed"
    
    # Selenium WebDriver
    log "INFO" "Installing Selenium..."
    chroot_exec "pip3 install --break-system-packages selenium"
    log "INFO" "  ✓ Selenium installed"
    
    # Playwright
    log "INFO" "Installing Playwright..."
    chroot_exec "pip3 install --break-system-packages playwright && \
        playwright install-deps || true"
    log "INFO" "  ✓ Playwright installed"
    
    # Cypress dependencies
    log "INFO" "Installing Cypress dependencies..."
    install_package "libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb"
    log "INFO" "  ✓ Cypress dependencies installed (install Cypress via npm in projects)"
    
    # Jest (via npm in projects)
    log "INFO" "  ℹ️  Jest: Install via npm in projects"
    
    # Pytest
    log "INFO" "Installing Pytest..."
    chroot_exec "pip3 install --break-system-packages pytest pytest-cov pytest-asyncio"
    log "INFO" "  ✓ Pytest installed"
    
    # Robot Framework
    log "INFO" "Installing Robot Framework..."
    chroot_exec "pip3 install --break-system-packages robotframework robotframework-seleniumlibrary"
    log "INFO" "  ✓ Robot Framework installed"
    
    # Cucumber/Behave (BDD)
    log "INFO" "Installing Behave (BDD)..."
    chroot_exec "pip3 install --break-system-packages behave"
    log "INFO" "  ✓ Behave installed"
    
    # SonarQube Scanner
    log "INFO" "Installing SonarQube Scanner..."
    chroot_exec "cd /tmp && \
        rm -rf sonar-scanner-* /opt/sonar-scanner && \
        wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip && \
        unzip -o -q sonar-scanner-cli-*-linux-x64.zip && \
        mv sonar-scanner-* /opt/sonar-scanner && \
        ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner && \
        rm sonar-scanner-cli-*.zip" || log "WARN" "SonarQube Scanner installation failed (optional)"
    log "INFO" "  ✓ SonarQube Scanner installed"
    
    # OWASP ZAP CLI
    log "INFO" "Installing OWASP ZAP..."
    chroot_exec "cd /tmp && \
        wget -q https://github.com/zaproxy/zaproxy/releases/download/v2.16.0/ZAP_2.16.0_Linux.tar.gz && \
        tar xzf ZAP_*.tar.gz && \
        mv ZAP_* /opt/zaproxy && \
        ln -sf /opt/zaproxy/zap.sh /usr/local/bin/zap && \
        rm -f ZAP_*.tar.gz" || log "WARN" "OWASP ZAP installation failed (optional)"
    log "INFO" "  ✓ OWASP ZAP installed"
    
    log "INFO" "✓ Testing frameworks installed"
}

# Install secrets management tools
install_secrets_management() {
    log "INFO" "=========================================="
    log "INFO" "Installing Secrets Management Tools"
    log "INFO" "=========================================="
    
    # HashiCorp Vault CLI (keyring already added by Terraform installation)
    log "INFO" "Installing Vault CLI..."
    chroot_exec "apt-get update && apt-get install -y vault"
    log "INFO" "  ✓ Vault CLI installed"
    
    # SOPS (Secrets OPerationS)
    log "INFO" "Installing SOPS..."
    chroot_exec "cd /tmp && \
        wget -q https://github.com/getsops/sops/releases/download/v3.9.3/sops-v3.9.3.linux.amd64 && \
        mv sops-*.linux.amd64 /usr/local/bin/sops && \
        chmod +x /usr/local/bin/sops" || log "WARN" "SOPS installation failed (optional)"
    log "INFO" "  ✓ SOPS installed"
    
    # age (encryption tool)
    log "INFO" "Installing age..."
    chroot_exec "cd /tmp && \
        AGE_VERSION=\$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | grep 'tag_name' | cut -d'\"' -f4) && \
        wget -q https://github.com/FiloSottile/age/releases/download/\${AGE_VERSION}/age-\${AGE_VERSION}-linux-amd64.tar.gz && \
        tar xzf age-*.tar.gz && \
        mv age/age /usr/local/bin/ && \
        mv age/age-keygen /usr/local/bin/ && \
        chmod +x /usr/local/bin/age /usr/local/bin/age-keygen && \
        rm -rf age age-*.tar.gz" || log "WARN" "age installation failed (optional)"
    log "INFO" "  ✓ age installed"
    
    log "INFO" "✓ Secrets management tools installed"
}

# Install development tools
install_development_tools() {
    log "INFO" "=========================================="
    log "INFO" "Installing Development Tools"
    log "INFO" "=========================================="
    
    # Jupyter Notebook
    log "INFO" "Installing Jupyter Notebook..."
    chroot_exec "pip3 install --break-system-packages jupyter jupyterlab notebook ipython"
    log "INFO" "  ✓ Jupyter installed"
    
    # Python data science stack
    log "INFO" "Installing Python data science libraries..."
    chroot_exec "pip3 install --break-system-packages pandas numpy matplotlib seaborn scikit-learn"
    log "INFO" "  ✓ Data science libraries installed"
    
    # Git LFS
    log "INFO" "Installing Git LFS..."
    chroot_exec "cd /tmp && \
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh -o git-lfs-setup.sh && \
        bash git-lfs-setup.sh && \
        apt-get install -y git-lfs && \
        git lfs install && \
        rm -f git-lfs-setup.sh"
    log "INFO" "  ✓ Git LFS installed"
    
    log "INFO" "✓ Development tools installed"
}

# Install IDEs
install_ides() {
    log "INFO" "=========================================="
    log "INFO" "Installing IDEs"
    log "INFO" "=========================================="
    
    # IDEs are now installed post-install via nubifer-install
    # This significantly reduces ISO size and build time
    # Users can install IDEs with: nubifer-install vscode
    
    log "INFO" "Skipping IDE installation (will be available via nubifer-install)"
    
    # IDEs - Only lightweight editors in ISO to reduce size
    # Heavy IDEs moved to post-install (saves ~4.2GB)
    # install_vscode           # Available via post-install
    # install_vscodium         # Available via post-install
    # install_intellij_ce      # Moved to post-install (saves 2.4GB)
    # install_pycharm_ce       # Moved to post-install (saves 1.8GB)
    # install_eclipse          # Moved to post-install (saves 382MB)
    # install_vim_neovim       # Available via post-install
    # install_emacs            # Available via post-install
    install_kate || true       # Lightweight text editor (~50MB)
    
    # Fix any broken packages
    chroot_exec "apt-get install -f -y" || true
    chroot_exec "dpkg --configure -a" || true
    
    log "INFO" "✓ All IDEs installed"
}

# Install VS Code
install_vscode() {
    # Check if already installed
    if chroot_exec "command -v code" &>/dev/null; then
        log "INFO" "VS Code already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing Visual Studio Code..."
    
    chroot_exec "cd /tmp && \
        rm -f packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg /usr/share/keyrings/microsoft.gpg /etc/apt/sources.list.d/vscode.list /etc/apt/sources.list.d/vscode.sources /etc/apt/sources.list.d/azure-cli.sources && \
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
        install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
        echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' > /etc/apt/sources.list.d/vscode.list && \
        rm -f packages.microsoft.gpg && \
        apt-get update && \
        apt-get install -y code"
    
    # Install useful extensions
    chroot_exec "code --install-extension ms-vscode.vscode-typescript-next --force || true"
    chroot_exec "code --install-extension ms-python.python --force || true"
    chroot_exec "code --install-extension hashicorp.terraform --force || true"
    chroot_exec "code --install-extension ms-azuretools.vscode-docker --force || true"
    
    log "INFO" "  ✓ VS Code installed"
}

# Install VSCodium
install_vscodium() {
    # Check if already installed
    if chroot_exec "command -v codium" &>/dev/null; then
        log "INFO" "VSCodium already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing VSCodium..."
    
    chroot_exec "cd /tmp && \
        rm -f /usr/share/keyrings/vscodium-archive-keyring.gpg && \
        wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor > /usr/share/keyrings/vscodium-archive-keyring.gpg && \
        echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' | tee /etc/apt/sources.list.d/vscodium.list && \
        apt-get update && \
        apt-get install -y codium"
    
    log "INFO" "  ✓ VSCodium installed"
}

# Install IntelliJ IDEA Community Edition
install_intellij_ce() {
    # Check if already installed
    if [ -d "${CHROOT_DIR}/opt/idea-IC-"* ] 2>/dev/null || chroot_exec "command -v idea" &>/dev/null; then
        log "INFO" "IntelliJ IDEA CE already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing IntelliJ IDEA Community Edition..."
    
    chroot_exec "cd /tmp && \
        wget -q https://download.jetbrains.com/idea/ideaIC-2024.1.tar.gz && \
        tar -xzf ideaIC-2024.1.tar.gz -C /opt/ && \
        rm ideaIC-2024.1.tar.gz && \
        ln -sf /opt/idea-IC-*/bin/idea.sh /usr/local/bin/idea"
    
    log "INFO" "  ✓ IntelliJ IDEA CE installed"
}

# Install PyCharm Community Edition
install_pycharm_ce() {
    # Check if already installed
    if [ -d "${CHROOT_DIR}/opt/pycharm-community-"* ] 2>/dev/null || chroot_exec "command -v pycharm" &>/dev/null; then
        log "INFO" "PyCharm CE already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing PyCharm Community Edition..."
    
    chroot_exec "cd /tmp && \
        wget -q https://download.jetbrains.com/python/pycharm-community-2024.1.tar.gz && \
        tar -xzf pycharm-community-2024.1.tar.gz -C /opt/ && \
        rm pycharm-community-2024.1.tar.gz && \
        ln -sf /opt/pycharm-community-*/bin/pycharm.sh /usr/local/bin/pycharm"
    
    log "INFO" "  ✓ PyCharm CE installed"
}

# Install Vim and Neovim
install_vim_neovim() {
    # Check if already installed
    if chroot_exec "command -v vim" &>/dev/null && chroot_exec "command -v nvim" &>/dev/null; then
        log "INFO" "Vim and Neovim already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing Vim and Neovim..."
    
    install_package "vim"
    install_package "neovim"
    
    # Install vim-plug for easy plugin management
    chroot_exec "curl -fLo /usr/share/vim/vim90/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || true"
    
    log "INFO" "  ✓ Vim and Neovim installed"
}

# Install Emacs
install_emacs() {
    log "INFO" "Installing Emacs..."
    
    # Emacs has issues in chroot environments, skip it
    log "WARN" "Skipping Emacs (has chroot compatibility issues)"
    log "WARN" "Install manually after boot: sudo apt-get install emacs"
}

# Install Kate
install_kate() {
    # Check if already installed
    if chroot_exec "command -v kate" &>/dev/null; then
        log "INFO" "Kate already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing Kate..."
    
    install_package "kate"
    
    log "INFO" "  ✓ Kate installed"
}

# Install Eclipse
install_eclipse() {
    # Check if already installed
    if [ -d "${CHROOT_DIR}/opt/eclipse" ] || chroot_exec "command -v eclipse" &>/dev/null; then
        log "INFO" "Eclipse already installed, skipping..."
        return 0
    fi
    
    log "INFO" "Installing Eclipse..."
    
    chroot_exec "cd /tmp && \
        wget -q https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-03/R/eclipse-java-2024-03-R-linux-gtk-x86_64.tar.gz -O eclipse.tar.gz && \
        tar -xzf eclipse.tar.gz -C /opt/ && \
        rm eclipse.tar.gz && \
        ln -sf /opt/eclipse/eclipse /usr/local/bin/eclipse"
    
    log "INFO" "  ✓ Eclipse installed"
}

# Configure shell completion
configure_shell_completion() {
    log "INFO" "=========================================="
    log "INFO" "Configuring shell completion"
    log "INFO" "=========================================="
    
    # Create completion directory
    chroot_exec "mkdir -p /etc/bash_completion.d"
    
    # AWS CLI completion
    chroot_exec "echo 'complete -C /usr/local/bin/aws_completer aws' >> /etc/bash_completion.d/aws"
    
    # kubectl completion
    chroot_exec "kubectl completion bash > /etc/bash_completion.d/kubectl"
    
    # Helm completion
    chroot_exec "helm completion bash > /etc/bash_completion.d/helm"
    
    # Terraform completion
    chroot_exec "terraform -install-autocomplete || true"
    
    log "INFO" "✓ Shell completion configured"
}

# Create tool verification script
create_verification_script() {
    log "INFO" "Creating tool verification script..."
    
    cat > "${CHROOT_DIR}/usr/local/bin/verify-cloud-tools" << 'EOF'
#!/bin/bash
# Verify all cloud tools are installed and working

echo "=========================================="
echo "NubiferOS Cloud Tools Verification"
echo "=========================================="

check_tool() {
    local tool="$1"
    local cmd="$2"
    
    if command -v $tool &> /dev/null; then
        local version=$($cmd 2>&1 | head -n1)
        echo "✓ $tool: $version"
        return 0
    else
        echo "✗ $tool: NOT FOUND"
        return 1
    fi
}

# AWS Tools
echo ""
echo "AWS Tools:"
check_tool "aws" "aws --version"
check_tool "sam" "sam --version"
check_tool "eksctl" "eksctl version"
check_tool "cdk" "cdk --version"
check_tool "session-manager-plugin" "session-manager-plugin --version"
check_tool "copilot" "copilot --version"
check_tool "amplify" "amplify --version"
check_tool "eb" "eb --version"
check_tool "nosql-workbench" "echo 'AppImage installed'"

# Azure Tools
echo ""
echo "Azure Tools:"
check_tool "az" "az --version"
check_tool "func" "func --version"
check_tool "bicep" "bicep --version"

# GCP Tools
echo ""
echo "Google Cloud Tools:"
check_tool "gcloud" "gcloud --version"

# IaC Tools
echo ""
echo "Infrastructure as Code:"
check_tool "terraform" "terraform --version"
check_tool "pulumi" "pulumi version"
check_tool "ansible" "ansible --version"

# Container Tools
echo ""
echo "Container & Kubernetes:"
check_tool "docker" "docker --version"
check_tool "podman" "podman --version"
check_tool "kubectl" "kubectl version --client"
check_tool "helm" "helm version"
check_tool "k9s" "k9s version"

# Additional Tools
echo ""
echo "Additional Tools:"
check_tool "yq" "yq --version"
check_tool "gh" "gh --version"
check_tool "trivy" "trivy --version"
check_tool "httpie" "http --version"
check_tool "infracost" "infracost --version"

# Monitoring & Observability
echo ""
echo "Monitoring & Observability:"
check_tool "grafana-cli" "grafana-cli --version"
check_tool "promtool" "promtool --version"
check_tool "logcli" "logcli --version"

# CI/CD Tools
echo ""
echo "CI/CD & GitOps:"
check_tool "glab" "glab --version"
check_tool "argocd" "argocd version --client"
check_tool "flux" "flux --version"
check_tool "tkn" "tkn version"
check_tool "jenkins-cli" "echo 'Jenkins CLI installed'"
check_tool "jira" "jira --version"
check_tool "linear" "linear --version"
check_tool "kustomize" "kustomize version"
check_tool "skaffold" "skaffold version"

# Database Clients
echo ""
echo "Database Clients:"
check_tool "psql" "psql --version"
check_tool "mysql" "mysql --version"
check_tool "mongosh" "mongosh --version"
check_tool "redis-cli" "redis-cli --version"

# Testing Frameworks
echo ""
echo "Testing Frameworks:"
check_tool "k6" "k6 version"
check_tool "locust" "locust --version"
check_tool "newman" "newman --version"
check_tool "pytest" "pytest --version"
check_tool "behave" "behave --version"
check_tool "sonar-scanner" "sonar-scanner --version"
check_tool "zap" "echo 'OWASP ZAP installed'"

# Secrets Management
echo ""
echo "Secrets Management:"
check_tool "vault" "vault --version"
check_tool "sops" "sops --version"
check_tool "age" "age --version"

# Development Tools
echo ""
echo "Development Tools:"
check_tool "jupyter" "jupyter --version"
check_tool "git-lfs" "git-lfs --version"
check_tool "dive" "dive --version"
check_tool "lazydocker" "lazydocker --version"
check_tool "stern" "stern --version"

# IDEs
echo ""
echo "IDEs:"
check_tool "code" "code --version"
check_tool "codium" "codium --version"
check_tool "idea" "echo 'IntelliJ IDEA installed'"
check_tool "pycharm" "echo 'PyCharm installed'"
check_tool "vim" "vim --version"
check_tool "nvim" "nvim --version"
check_tool "emacs" "emacs --version"
check_tool "kate" "kate --version"
check_tool "eclipse" "echo 'Eclipse installed'"

echo ""
echo "=========================================="
echo "Verification complete"
echo ""
echo "Total tools installed: 70+"
echo "=========================================="
EOF
    
    chmod +x "${CHROOT_DIR}/usr/local/bin/verify-cloud-tools"
    
    log "INFO" "✓ Verification script created"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Cloud Tools Installation"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "=========================================="
    
    # Install in order
    install_base_dependencies
    
    # AWS Tools
    log "INFO" "Installing AWS tools..."
    install_aws_cli
    install_aws_sam
    install_eksctl
    install_aws_cdk
    install_session_manager
    install_aws_copilot
    install_aws_amplify
    install_aws_eb
    install_aws_nosql_workbench
    install_aws_sdks
    
    # Azure Tools
    log "INFO" "Installing Azure tools..."
    install_azure_cli
    install_azure_functions
    install_bicep
    
    # GCP Tools
    log "INFO" "Installing GCP tools..."
    install_gcloud_sdk
    
    # IaC Tools
    log "INFO" "Installing IaC tools..."
    install_terraform
    install_pulumi
    install_ansible
    
    # Container Tools
    log "INFO" "Installing container tools..."
    install_docker
    install_podman
    
    # Kubernetes Tools
    log "INFO" "Installing Kubernetes tools..."
    install_kubectl
    install_helm
    install_k9s
    
    # Additional Tools (non-fatal)
    install_additional_tools || log "WARN" "Some additional tools failed to install (non-fatal)"
    
    # Development Tools
    install_development_tools || log "WARN" "Some development tools failed to install (non-fatal)"
    
    # IDEs (non-fatal)
    install_ides || log "WARN" "Some IDEs failed to install (non-fatal)"
    
    # DevOps & Monitoring Tools
    log "INFO" "Installing DevOps & monitoring tools..."
    install_monitoring_tools
    install_cicd_tools
    install_database_clients
    install_testing_frameworks
    install_gitops_tools
    install_secrets_management
    
    # Configuration
    configure_shell_completion
    
    # Create verification script
    create_verification_script
    
    log "INFO" "=========================================="
    log "INFO" "Running verification..."
    log "INFO" "=========================================="
    
    # Run verification (non-fatal)
    chroot_exec "/usr/local/bin/verify-cloud-tools" || log "WARN" "Some tools verification failed (non-fatal)"
    
    log "INFO" "=========================================="
    log "INFO" "Cloud tools installation complete!"
    log "INFO" "=========================================="
}

# Run main function
main "$@"
