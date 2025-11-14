# NubiferOS Included Tools

This document lists all tools, SDKs, and IDEs included in NubiferOS.

## Cloud CLI Tools

### AWS Tools (11 tools)
- **AWS CLI v2** - Primary AWS command-line interface
- **SAM CLI** - Serverless Application Model for Lambda
- **eksctl** - Amazon EKS cluster management
- **AWS CDK** - Cloud Development Kit for infrastructure as code
- **Session Manager Plugin** - Secure shell access to EC2 instances
- **AWS Copilot** - Container deployment on ECS/Fargate
- **AWS Amplify CLI** - Full-stack app development
- **EB CLI** - Elastic Beanstalk deployment
- **AWS NoSQL Workbench** - DynamoDB GUI tool (AppImage)
- **AWS Vault** - Secure credential storage (optional)
- **Lightsail CLI** - Lightsail management (optional)

### AWS SDKs
- **Python (boto3)** - AWS SDK for Python
- **Node.js (aws-sdk)** - AWS SDK for JavaScript/TypeScript
- **Go (aws-sdk-go-v2)** - Available via go get (not pre-installed)
- **Java** - Available via Maven/Gradle (not pre-installed)
- **.NET** - Available via NuGet (not pre-installed)

### Azure Tools (3 tools)
- **Azure CLI** - Primary Azure command-line interface
- **Azure Functions Core Tools** - Serverless function development
- **Bicep** - Azure infrastructure as code

### Google Cloud Tools (1 tool)
- **gcloud SDK** - Google Cloud command-line interface
  - Includes: gcloud, gsutil, bq

## Infrastructure as Code

- **Terraform** - Multi-cloud infrastructure provisioning
- **Pulumi** - Modern infrastructure as code
- **Ansible** - Configuration management and automation

## Container & Kubernetes Tools

- **Docker** - Container runtime and CLI
- **Podman** - Daemonless container engine
- **kubectl** - Kubernetes command-line tool
- **Helm** - Kubernetes package manager
- **k9s** - Terminal UI for Kubernetes

## Monitoring & Observability Tools

- **Grafana** - Visualization and dashboards
- **Prometheus (promtool)** - Metrics collection and querying
- **Loki (logcli)** - Log aggregation
- **Trivy** - Security scanner for containers and IaC

## CI/CD & GitOps Tools

- **GitHub CLI (gh)** - GitHub command-line interface
- **GitLab CLI (glab)** - GitLab command-line interface
- **ArgoCD** - GitOps continuous delivery for Kubernetes
- **Flux** - GitOps toolkit for Kubernetes
- **Tekton CLI (tkn)** - Cloud-native CI/CD pipelines
- **Jenkins CLI** - Connect to Jenkins servers
- **Kustomize** - Kubernetes configuration management
- **Skaffold** - Kubernetes development workflow

## Database Clients

- **psql** - PostgreSQL client
- **mysql** - MySQL/MariaDB client
- **mongosh** - MongoDB shell
- **redis-cli** - Redis client
- **AWS NoSQL Workbench** - DynamoDB GUI (already listed above)

## Testing Frameworks

### Load & Performance Testing
- **k6** - Modern load testing tool
- **Locust** - Python-based load testing
- **Newman** - Postman CLI for API testing

### Browser & E2E Testing
- **Selenium** - Browser automation
- **Playwright** - Modern browser testing
- **Cypress** - Dependencies installed (install Cypress via npm)

### Unit & Integration Testing
- **Pytest** - Python testing framework
- **Robot Framework** - Keyword-driven testing
- **Behave** - BDD testing for Python
- **Jest** - JavaScript testing (install via npm in projects)

### Security & Quality Testing
- **SonarQube Scanner** - Code quality and security
- **OWASP ZAP** - Security testing and scanning
- **Trivy** - Container and IaC security scanning

## Secrets Management

- **HashiCorp Vault** - Secrets management
- **SOPS** - Encrypted secrets in Git
- **age** - Modern file encryption

## Additional DevOps Tools

- **yq** - YAML processor (like jq for YAML)
- **httpie** - User-friendly HTTP client
- **Infracost** - Cost estimation for Terraform/IaC
- **Dive** - Docker image layer explorer
- **Lazydocker** - Docker terminal UI
- **Stern** - Kubernetes log tailing
- **Git LFS** - Large file storage for Git

## Development Tools

- **Jupyter Notebook** - Interactive Python notebooks
- **JupyterLab** - Full IDE for notebooks
- **Python Data Science Stack** - pandas, numpy, matplotlib, seaborn, scikit-learn

## Integrated Development Environments (IDEs)

**Note**: NubiferOS automatically installs IDE plugins for cloud development tools. Run `/usr/local/bin/install-ide-plugins` to configure plugins for your installed IDEs. See [IDE Plugins Documentation](IDE_PLUGINS.md) for details.

### Core IDEs (Installed by default)
1. **Visual Studio Code** (~200MB)
   - Most popular, best cloud extensions
   - Auto-configured extensions: AWS Toolkit, Azure Tools, Google Cloud Code, Terraform, Docker, Kubernetes, Python, Go
   - License: MIT (Open Source)

2. **Vim/Neovim** (~10MB)
   - Lightweight, terminal-based
   - Always available, fast
   - License: Vim License / Apache 2.0

### Optional IDEs (Selectable during installation)

3. **VSCodium** (~200MB)
   - VS Code without Microsoft telemetry
   - Privacy-focused alternative
   - License: MIT (Open Source)

4. **IntelliJ IDEA Community Edition** (~800MB)
   - Best for Java, Kotlin, Scala
   - Excellent for enterprise development
   - License: Apache 2.0 (Open Source)

5. **PyCharm Community Edition** (~600MB)
   - Best Python IDE
   - Great for data science and ML
   - License: Apache 2.0 (Open Source)

6. **Emacs** (~50MB)
   - Highly extensible editor
   - Terminal and GUI modes
   - License: GPL (Open Source)

7. **Kate** (~30MB)
   - KDE's advanced text editor
   - Lightweight, feature-rich
   - License: GPL (Open Source)

8. **Eclipse** (~500MB)
   - Java/enterprise development
   - Extensive plugin ecosystem
   - License: EPL (Open Source)

## Development Tools

### Languages & Runtimes
- **Python 3** - With pip and venv
- **Node.js** - With npm
- **Go** - Available via apt (optional)
- **Java** - Available via apt (optional)

### Version Control
- **Git** - Distributed version control
- **GitHub CLI** - GitHub integration

### Build Tools
- **Make** - Build automation
- **npm** - Node.js package manager
- **pip** - Python package manager

### Utilities
- **curl** - Data transfer tool
- **wget** - File downloader
- **jq** - JSON processor
- **yq** - YAML processor
- **unzip/tar/gzip** - Archive tools

## Security Tools

- **Trivy** - Vulnerability scanner
- **AppArmor** - Mandatory access control
- **fail2ban** - Intrusion prevention
- **ufw** - Uncomplicated firewall
- **auditd** - System auditing

## NubiferOS Custom Components

- **Credential Manager** - Secure credential storage
- **Context Manager** - Workspace isolation
- **Resource Viewer** - GUI for cloud resources
- **Context Indicator** - Visual context display
- **AI Assistant** - Optional AI integration

## Installation Size Estimates

### Minimal Installation
- Base system + core tools: ~2GB
- Includes: AWS CLI, Azure CLI, gcloud, Terraform, Docker, kubectl
- IDEs: VS Code, Vim only

### Standard Installation (Recommended)
- Base + common tools + 3-4 IDEs: ~4-5GB
- Includes: All AWS tools, Azure tools, IaC tools, container tools
- IDEs: VS Code, VSCodium, Vim, Kate

### Full Installation
- Everything included: ~7-8GB
- All AWS tools, all Azure tools, all GCP tools
- All 8 IDEs
- All additional tools

## Tool Selection During Installation

During installation, users can select:

### Cloud Tools
- ☑ Core AWS tools (required)
- ☐ Extended AWS tools (Copilot, Amplify, EB, NoSQL Workbench)
- ☑ Azure CLI (required)
- ☐ Azure Functions & Bicep
- ☑ GCP gcloud (required)
- ☑ Terraform (recommended)
- ☐ Pulumi
- ☐ Ansible

### IDEs
- ☑ VS Code (recommended)
- ☐ VSCodium
- ☐ IntelliJ IDEA CE
- ☐ PyCharm CE
- ☑ Vim/Neovim (recommended)
- ☐ Emacs
- ☐ Kate
- ☐ Eclipse

### Additional Tools
- ☑ GitHub CLI (recommended)
- ☑ Trivy (recommended)
- ☐ Infracost
- ☐ httpie

## Post-Installation Tool Management

Users can add or remove tools after installation:

```bash
# List available tools
nubifer-tools list-available

# Install additional tool
nubifer-tools install aws-copilot
nubifer-tools install pycharm

# Remove tool
nubifer-tools remove eclipse

# Update all tools
nubifer-tools update-all

# Verify installations
verify-cloud-tools
```

## Tool Updates

### Automatic Updates
- Security updates: Automatic via unattended-upgrades
- System packages: Automatic

### Manual Updates
- Cloud CLIs: `nubifer-tools update-cloud-tools`
- IDEs: `nubifer-tools update-ides`
- All: `nubifer-tools update-all`

## Cloud Provider Extensions

### VS Code Extensions (Pre-installed)
- AWS Toolkit
- Azure Tools
- Google Cloud Code
- Terraform
- Docker
- Kubernetes
- Python
- Go

### Available Extensions (User can install)
- AWS SAM
- Azure Functions
- GitHub Copilot
- GitLens
- Remote - SSH
- Remote - Containers

## Documentation

Each tool includes:
- Man pages (where available)
- `--help` documentation
- Shell completion
- Links to official documentation

## Support

For tool-specific issues:
- AWS: https://aws.amazon.com/cli/
- Azure: https://docs.microsoft.com/cli/azure/
- GCP: https://cloud.google.com/sdk/docs
- Terraform: https://www.terraform.io/docs
- Docker: https://docs.docker.com/

For NubiferOS-specific issues:
- GitHub Issues
- Documentation: https://docs.nubiferos.org
- Discord: https://discord.gg/nubiferos

## Version Information

This document reflects NubiferOS 1.0 (Nimbus).

Tool versions are current as of the build date. Check `verify-cloud-tools` for installed versions.

---

**Last Updated**: 2024-01-15  
**NubiferOS Version**: 1.0 (Nimbus)
