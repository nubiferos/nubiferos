# NubiferOS Tool Categories

NubiferOS organizes cloud engineering tools into categories, similar to how Kali Linux organizes security tools. This makes it easy to find the right tool for the job.

## Menu Categories

The GNOME application menu includes these NubiferOS-specific categories:

### Cloud Providers
Quick access to cloud consoles and CLIs:
- **AWS Console** - Opens AWS Management Console in browser
- **Azure Portal** - Opens Microsoft Azure Portal
- **GCP Console** - Opens Google Cloud Console
- **Oracle Cloud** - Opens Oracle Cloud Infrastructure Console
- **aws, az, gcloud** - Cloud CLIs (open in terminal)

### Kubernetes
Container orchestration tools:
- **k9s** - Terminal UI for Kubernetes (TUI)
- **Lens** - Kubernetes IDE (GUI)
- **kubectl** - Kubernetes CLI
- **Helm** - Kubernetes package manager
- **eksctl** - Amazon EKS cluster management

### Containers
Container runtime and management:
- **Podman Desktop** - Container management GUI
- **Docker** - Container CLI
- **Podman** - Rootless container CLI
- **Docker Compose** - Multi-container applications

### Infrastructure
Infrastructure as Code tools:
- **Terraform** - HashiCorp IaC
- **OpenTofu** - Open source Terraform fork
- **Ansible** - Configuration management
- **Pulumi** - IaC with real programming languages
- **Steampipe** - SQL queries for cloud APIs

### Security & Compliance
Security scanning and monitoring:
- **Security Dashboard** - NubiferOS security status (GUI)
- **Security Scan** - Vulnerability and compliance scanning
- **Trivy** - Container vulnerability scanner
- **Lynis** - System hardening audit
- **Pass** - GPG-encrypted password manager

### Development
Development tools and editors:
- **VS Code** - Visual Studio Code
- **Git** - Version control
- **GitHub CLI** - GitHub from command line
- **jq** - JSON processor
- **yq** - YAML processor

### NubiferOS
NubiferOS-specific tools:
- **Cloud Tools** - Unified tool launcher (GUI)
- **Workspace Manager** - Isolated cloud workspaces
- **Credential Manager** - Secure credential storage
- **Check Updates** - Tool version checker
- **Welcome Wizard** - Initial setup

## Cloud Tools Launcher

The **Cloud Tools Launcher** (`nubifer-tools`) provides a unified GUI for accessing all tools:

- **Organized by category** - Same categories as the menu
- **Installation status** - Green/red indicators show what's installed
- **Quick search** - Filter tools by name
- **Smart launch** - CLI tools open in terminal, GUI apps launch directly

Launch from:
- Applications menu → NubiferOS → Cloud Tools
- Command line: `nubifer-tools`

## Installing Additional Tools

### GUI Tools

```bash
# Lens - Kubernetes IDE
/usr/share/nubiferos/installers/install-lens.sh

# Podman Desktop - Container management
/usr/share/nubiferos/installers/install-podman-desktop.sh
```

### Cloud Query Tools

```bash
# Steampipe - SQL for cloud APIs
/usr/share/nubiferos/installers/install-steampipe.sh

# Example: Find unencrypted S3 buckets
steampipe query "select name from aws_s3_bucket where server_side_encryption_configuration is null"
```

## Comparison with Other Distros

| Feature | Ubuntu | Kali | NubiferOS |
|---------|--------|------|-----------|
| Tool categories | Basic | Excellent | ✅ Cloud-focused |
| Cloud console launchers | ❌ | ❌ | ✅ AWS, Azure, GCP, OCI |
| Unified tool launcher | ❌ | ❌ | ✅ nubifer-tools |
| Installation status | ❌ | ❌ | ✅ Green/red indicators |
| Cloud-specific tools | ❌ | ❌ | ✅ Steampipe, k9s, etc. |

## Adding Custom Tools

To add a tool to the Cloud Tools Launcher, edit `/usr/local/bin/nubifer-tools` and add an entry to the appropriate category:

```python
{"name": "Tool Name", "cmd": "command", "icon": "icon-name", "type": "cli|gui|web|tui", "terminal": True|False}
```

Types:
- `cli` - Command-line tool (opens in terminal)
- `tui` - Terminal UI (opens in terminal)
- `gui` - Graphical application
- `web` - Opens URL in browser
