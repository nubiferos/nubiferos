# NubiferOS Cloud Tools Launcher

A categorized launcher for all cloud engineering tools installed on NubiferOS.

## Features

- **Organized by Category**: Tools grouped into Cloud Providers, Kubernetes, Containers, Infrastructure, Security, Development, and NubiferOS
- **Installation Status**: Green/red indicators show which tools are installed
- **Quick Search**: Filter tools by name
- **Smart Launch**: CLI tools open in terminal, GUI apps launch directly, web consoles open in browser

## Categories

### Cloud Providers
- AWS, Azure, GCP, Oracle Cloud consoles
- Cloud CLIs (aws, az, gcloud)

### Kubernetes
- k9s (TUI cluster manager)
- Lens (GUI IDE)
- kubectl, Helm, eksctl

### Containers
- Podman Desktop (GUI)
- Docker, Podman CLIs

### Infrastructure
- Terraform, OpenTofu
- Ansible, Pulumi

### Security
- Security Dashboard
- Trivy, Lynis
- Pass (secrets manager)

### Development
- VS Code
- Git, GitHub CLI
- jq, yq

### NubiferOS
- Workspace Manager
- Credential Manager
- Update Checker

## Installation

The launcher is installed automatically with NubiferOS. To install manually:

```bash
sudo cp nubifer-tools /usr/local/bin/
sudo chmod +x /usr/local/bin/nubifer-tools
sudo cp nubifer-tools.desktop /usr/share/applications/
```

## Usage

Launch from:
- Applications menu → NubiferOS → Cloud Tools
- Command line: `nubifer-tools`
- Keyboard shortcut (configure in GNOME Settings)

## Dependencies

- Python 3
- GTK 3 (python3-gi)
- GNOME Terminal (for CLI tools)

## Adding New Tools

Edit the `CATEGORIES` dictionary in `nubifer-tools` to add new tools:

```python
{"name": "Tool Name", "cmd": "command", "icon": "icon-name", "type": "cli|gui|web|tui", "terminal": True|False}
```

Types:
- `cli`: Command-line tool (opens in terminal)
- `tui`: Terminal UI (opens in terminal)
- `gui`: Graphical application
- `web`: Opens URL in browser
