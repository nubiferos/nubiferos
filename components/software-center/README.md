# NubiferOS Software Center

A curated software installer for cloud development tools. Provides easy access to tools that aren't in the standard Debian repositories or require special installation steps.

## Features

- **Curated catalog** of cloud development tools
- **One-click installation** for complex tools
- **Installation status** tracking
- **Categorized** by use case (Cloud CLIs, Kubernetes, IaC, etc.)

## Categories

### Cloud CLIs
- AWS CLI v2
- Google Cloud SDK
- Azure CLI

### Kubernetes
- kubectl
- Helm
- k9s
- Minikube
- eksctl

### Infrastructure as Code
- Terraform
- Pulumi
- Ansible

### Containers
- Docker
- Podman

### IDEs & Editors
- Visual Studio Code
- IntelliJ IDEA Community
- PyCharm Community
- Neovim

### DevOps Tools
- GitHub CLI
- ArgoCD CLI
- Trivy (security scanner)

### Database Clients
- PostgreSQL Client
- MySQL Client
- Redis CLI

## Usage

Launch from:
- Applications menu → System → NubiferOS Software Center
- Command line: `nubifer-software`

## Installation

The Software Center is installed automatically during NubiferOS installation.

To install manually:
```bash
sudo ./install.sh
```

## Adding New Tools

Edit `nubifer-software` and add entries to the `SOFTWARE_CATALOG` dictionary:

```python
{
    "id": "tool-id",
    "name": "Tool Name",
    "description": "What the tool does",
    "check_cmd": "command --version",  # How to check if installed
    "install_cmd": "installation command",
    "size": "~50MB"
}
```
