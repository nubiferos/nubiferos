# NubiferOS Post-Install Tools

## Overview

NubiferOS uses a hybrid installation approach to balance ISO size, build time, and user flexibility:

- **Pre-installed**: All CLI tools (aws, az, gcloud, kubectl, terraform, etc.)
- **Post-install**: IDEs and large applications (user choice)

This approach provides:
- ✅ Smaller ISO size (~3-4GB vs 8-10GB)
- ✅ Faster ISO builds (30-40 min vs 60-90 min)
- ✅ Always latest IDE versions
- ✅ User choice - install only what you need
- ✅ Easy installation with `nubifer-install`

---

## What's Included in the ISO

### Pre-Installed CLI Tools

**Cloud Provider CLIs:**
- AWS CLI v2
- Azure CLI
- Google Cloud SDK (gcloud)
- Oracle Cloud CLI (oci)

**Infrastructure as Code:**
- Terraform
- Pulumi
- Ansible

**Container & Kubernetes:**
- kubectl
- Helm
- k9s
- kubectx/kubens

**Development Tools:**
- Git
- curl, wget, jq
- Python 3, pip
- Node.js, npm
- Go

**Monitoring & Observability:**
- Trivy (security scanner)
- eksctl (AWS EKS)
- Various cloud-specific tools

**Browsers:**
- Firefox (hardened)
- Chromium

**Security:**
- pass (password-store)
- GPG
- AppArmor
- fail2ban
- UFW firewall

---

## Post-Install Options

### IDEs (Not Pre-Installed)

These are available via `nubifer-install` but not included in the ISO to save space:

| IDE | Size | Command |
|-----|------|---------|
| Visual Studio Code | 500MB | `nubifer-install vscode` |
| IntelliJ IDEA Community | 1.5GB | `nubifer-install intellij` |
| PyCharm Community | 1.2GB | `nubifer-install pycharm` |
| Vim (with plugins) | 50MB | `nubifer-install vim` |
| Neovim (with plugins) | 100MB | `nubifer-install neovim` |

### Additional Tools

| Tool | Size | Command |
|------|------|---------|
| Docker Desktop | 800MB | `nubifer-install docker-desktop` |
| Postman | 200MB | `nubifer-install postman` |
| DBeaver | 150MB | `nubifer-install dbeaver` |

---

## Using nubifer-install

### Interactive Mode

Simply run without arguments for an interactive menu:

```bash
nubifer-install
```

You'll see:

```
╔════════════════════════════════════════╗
║   NubiferOS Package Installer          ║
╚════════════════════════════════════════╝

Select packages to install:

IDEs:
  1) Visual Studio Code (500MB)
  2) IntelliJ IDEA Community (1.5GB)
  3) PyCharm Community (1.2GB)
  4) Vim with plugins (50MB)
  5) Neovim with plugins (100MB)

Cloud Tools:
  6) AWS tools
  7) Azure tools
  8) Google Cloud SDK
  9) All cloud tools

Additional Tools:
  10) Docker Desktop
  11) Postman
  12) DBeaver

  0) Exit

Enter numbers separated by spaces (e.g., 1 6 10):
```

### Command Line Mode

Install specific packages directly:

```bash
# Install VS Code
nubifer-install vscode

# Install multiple packages
nubifer-install vscode docker-desktop postman

# Install all cloud tools
nubifer-install all-cloud
```

### List Available Packages

```bash
nubifer-install --list
```

### Get Help

```bash
nubifer-install --help
```

---

## First Boot Setup Wizard

On first boot, the NubiferOS Setup Wizard will guide you through:

1. **GPG Key Setup** - For credential encryption
2. **Password Store (pass) Setup** - For credential management
3. **IDE Selection** - Choose which IDEs to install
4. **Additional Tools** - Select extra tools you need
5. **Cloud Provider Configuration** - Set up AWS/Azure/GCP credentials

The wizard automatically calls `nubifer-install` for your selections.

---

## Why This Approach?

### Problem with Pre-Installing Everything

**Old approach** (all IDEs in ISO):
- ISO size: 8-10GB
- Build time: 60-90 minutes
- Wasted space: Users don't need all IDEs
- Stale versions: IDEs outdated by release time

**New approach** (post-install):
- ISO size: 3-4GB
- Build time: 30-40 minutes
- User choice: Install only what you need
- Latest versions: Always get current releases

### What Other Distros Do

| Distro | Approach |
|--------|----------|
| **Ubuntu** | Minimal ISO, install during setup |
| **Fedora** | Netinstall option available |
| **Arch** | Minimal base, user installs everything |
| **Kali** | Full ISO with tools, but also netinstall |
| **NubiferOS** | CLI tools pre-installed, IDEs post-install |

---

## Installation Details

### VS Code

Installs from Microsoft's official repository and includes extensions:
- HashiCorp Terraform
- Docker
- Kubernetes Tools
- AWS Toolkit
- Azure Account
- Google Cloud Code

### IntelliJ IDEA / PyCharm

Installs via Snap for easy updates:
```bash
snap install intellij-idea-community --classic
snap install pycharm-community --classic
```

### Vim / Neovim

Installs with cloud development plugins:
- vim-terraform
- vim-kubernetes
- NERDTree
- vim-airline
- Git integration

### Docker Desktop

Installs Docker Engine and adds user to docker group:
```bash
# After installation, log out and back in
# Then test:
docker run hello-world
```

---

## Updating Tools

### CLI Tools (Pre-Installed)

Use the built-in update checker:

```bash
# Check for updates
nubifer-update-checker

# Install updates
nubifer-update-checker --install-all
```

### IDEs (Post-Installed)

**VS Code:**
```bash
sudo apt update && sudo apt upgrade code
```

**IntelliJ / PyCharm:**
```bash
sudo snap refresh intellij-idea-community
sudo snap refresh pycharm-community
```

**Docker:**
```bash
sudo apt update && sudo apt upgrade docker-ce
```

---

## Troubleshooting

### nubifer-install not found

```bash
# Ensure it's executable
sudo chmod +x /usr/local/bin/nubifer-install

# Or reinstall
sudo cp /usr/share/nubiferos/scripts/nubifer-install /usr/local/bin/
sudo chmod +x /usr/local/bin/nubifer-install
```

### Installation fails

```bash
# Update package lists
sudo apt update

# Check internet connection
ping -c 3 google.com

# Check disk space
df -h
```

### VS Code extensions fail to install

```bash
# Install extensions manually
code --install-extension hashicorp.terraform
code --install-extension ms-azuretools.vscode-docker
```

### Docker permission denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then test
docker run hello-world
```

---

## Advanced Usage

### Custom IDE Configuration

After installing an IDE, you can customize it:

**VS Code:**
```bash
# Settings location
~/.config/Code/User/settings.json

# Extensions location
~/.vscode/extensions/
```

**IntelliJ / PyCharm:**
```bash
# Settings location
~/.config/JetBrains/
```

### Scripted Installation

For automated setups:

```bash
#!/bin/bash
# Install my preferred tools
nubifer-install vscode
nubifer-install docker-desktop
nubifer-install postman

# Configure VS Code
code --install-extension my-extension
```

### Offline Installation

If you need to install on a system without internet:

1. Download packages on a connected system
2. Transfer to offline system
3. Install manually:

```bash
# VS Code
sudo dpkg -i code_*.deb
sudo apt-get install -f

# Docker
sudo dpkg -i docker-ce_*.deb containerd.io_*.deb
sudo apt-get install -f
```

---

## Future Enhancements

### Planned Features

- **Package Repository**: NubiferOS APT repository for easier updates
- **Offline Mode**: Download packages for offline installation
- **Profile Support**: Save and restore tool selections
- **Team Profiles**: Share tool configurations across teams
- **Auto-Update**: Optional automatic IDE updates

### Feedback

Have suggestions for tools to add? Open an issue:
https://github.com/nubiferos/nubiferos/issues

---

## Summary

NubiferOS provides a balanced approach:

**Pre-Installed (in ISO):**
- All CLI tools you need for cloud development
- Browsers, security tools, basic utilities
- Ready to use immediately

**Post-Install (via nubifer-install):**
- IDEs (VS Code, IntelliJ, PyCharm, Vim, Neovim)
- Large applications (Docker, Postman, DBeaver)
- User choice, latest versions

**Benefits:**
- Smaller, faster ISO builds
- User flexibility
- Always current versions
- Easy installation

**Command to remember:**
```bash
nubifer-install
```

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: November 14, 2025
