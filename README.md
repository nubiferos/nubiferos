# NubiferOS

**Multi-Cloud, Unified Control**

A specialized Linux distribution designed for cloud infrastructure management and development.

## Overview

NubiferOS (from Latin *nubifer*: "cloud-bearing") provides a secure, isolated environment for managing multiple cloud accounts (AWS, Azure, GCP) with built-in tools, credential management, and visual resource exploration. The distribution emphasizes security through account isolation, local resource indexing to reduce cloud costs, and clear visual context to prevent accidental changes across accounts.

## Features

- **Multi-Cloud Support**: Pre-installed CLI tools for AWS, Azure, and GCP
- **Secure Credential Management**: Encrypted storage with system keyring integration
- **Workspace Isolation**: Separate environments for each cloud account
- **Visual Context Indicators**: Always-visible indicators showing current cloud context
- **Local Resource Indexing**: Browse cloud resources offline to reduce costs
- **Read-Only Mode**: Safe browsing without risk of accidental changes
- **Security Hardened**: Full disk encryption, AppArmor, automatic updates

## Project Structure

```
nubiferos/
├── brand/                        # Branding configuration
│   ├── brand.conf               # Central brand variables
│   ├── load-brand.sh            # Brand loader script
│   ├── brandideas.md            # Brand identity concepts
│   └── README.md                # Branding documentation
├── build/                        # Build system
│   ├── config.sh                # Build configuration
│   ├── build-iso.sh             # ISO creation script
│   ├── customize-system.sh      # System customization
│   └── install-cloud-tools.sh   # Cloud tools installer
├── components/                   # Custom NubiferOS components
│   ├── credential-manager/      # Credential management service
│   ├── context-manager/         # Workspace context service
│   ├── resource-viewer/         # GUI resource browser
│   └── context-indicator/       # Desktop indicator widget
├── configs/                      # System configuration files
│   ├── desktop/                 # Desktop environment configs
│   ├── cloud-tools/             # Cloud CLI configurations
│   └── security/                # Security policies
├── installer/                    # Custom installer
│   ├── calamares/               # Calamares installer config
│   └── scripts/                 # Post-install scripts
├── iso/                          # ISO build workspace (generated)
├── output/                       # Build artifacts (generated)
├── logs/                         # Build logs (generated)
└── docs/                         # Documentation
```

## Requirements

### Build Requirements

- Debian 12 (Bookworm) or Ubuntu 22.04 LTS
- 20GB free disk space
- 4GB RAM minimum (8GB recommended)
- Internet connection for downloading packages

### Build Dependencies

```bash
sudo apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    isolinux \
    syslinux-efi
```

## Building NubiferOS

1. Clone the repository:
```bash
git clone https://github.com/nubiferos/nubiferos.git
cd nubiferos
```

2. Review and customize the build configuration:
```bash
vim build/config.sh
# Or customize branding:
vim brand/brand.conf
```

3. Run the build script:
```bash
sudo ./build/build-iso.sh
```

4. The ISO will be created in the `output/` directory.

## Installation

1. Write the ISO to a USB drive:
```bash
sudo dd if=output/NubiferOS-1.0-x86_64.iso of=/dev/sdX bs=4M status=progress
```

2. Boot from the USB drive and follow the installer prompts.

3. The installer will:
   - Set up full disk encryption (LUKS)
   - Install the base system
   - Configure security hardening
   - Install NubiferOS components
   - Set up the desktop environment

## Usage

### Managing Credentials

Add cloud credentials:
```bash
nubifer-creds add --provider aws --account prod-account
```

List credentials:
```bash
nubifer-creds list
```

### Managing Workspaces

Create a workspace:
```bash
nubifer-workspace create --name "AWS Production" --provider aws --account prod-account
```

Switch workspaces:
```bash
nubifer-workspace switch aws-prod
```

List workspaces:
```bash
nubifer-workspace list
```

### Using Cloud Tools

All cloud CLI tools are pre-installed and automatically configured with credentials from the current workspace:

```bash
# AWS
aws s3 ls
aws ec2 describe-instances

# Azure
az vm list

# GCP
gcloud compute instances list
```

### IDE Integration

NubiferOS automatically configures IDE plugins for installed tools:

```bash
# Install IDE plugins for your installed IDEs
sudo /usr/local/bin/install-ide-plugins
```

Supported IDEs:
- **VS Code / VSCodium**: AWS Toolkit, Azure Tools, Google Cloud Code, Terraform, Docker, Kubernetes
- **IntelliJ IDEA / PyCharm**: Cloud provider toolkits, Terraform, Docker, Kubernetes
- **Vim / Neovim**: vim-terraform, Dockerfile.vim, vim-kubernetes, LSP support
- **Emacs**: terraform-mode, dockerfile-mode, kubernetes, magit

See [IDE Plugins Documentation](docs/guides/IDE_PLUGINS.md) for details.

### Documentation Access

All installed tools have documentation bookmarked in Firefox:
- Cloud provider documentation (AWS, Azure, GCP)
- Tool documentation (Terraform, Docker, Kubernetes, etc.)
- IDE extension documentation
- Learning resources and tutorials

See [Browser Configuration](docs/guides/BROWSER_CONFIGURATION.md) for the complete bookmark structure.

## Security

NubiferOS implements multiple layers of security:

- **Full Disk Encryption**: Mandatory LUKS encryption during installation
- **Credential Protection**: Triple-layer encryption (keyring + AES-256-GCM + LUKS)
- **System Hardening**: AppArmor profiles, firewall, disabled unnecessary services
- **Automatic Updates**: Security patches applied automatically
- **Workspace Isolation**: Credentials and environment isolated per workspace
- **Audit Logging**: Comprehensive logging of all cloud operations

## Documentation

- [Documentation Index](docs/INDEX.md) - Complete documentation catalog
- [Quickstart Guide](docs/QUICKSTART.md) - Get started quickly
- [Quick Build Guide](docs/QUICK_BUILD_GUIDE.md) - Build the ISO
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Codebase organization
- [Design Decisions](docs/DESIGN_DECISIONS.md) - Architecture rationale
- [Security Documentation](docs/SECURITY_SUMMARY.md) - Security overview
- [Calamares Documentation](docs/calamares/) - Installer documentation

## Development

### Component Development

Each component has its own directory under `components/`:

- **credential-manager**: Python service for secure credential storage
- **context-manager**: Python/Go service for workspace management
- **resource-viewer**: Electron/Tauri app for browsing cloud resources
- **context-indicator**: GNOME Shell extension for visual context

### Testing

Run component tests:
```bash
pytest components/credential-manager/tests/
pytest components/context-manager/tests/
```

Test ISO build:
```bash
./test/test-build.sh
```

Test installation in VM:
```bash
./test/test-install-vm.sh
```

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

NubiferOS is open source software licensed under GPL-3.0. See LICENSE file for details.

## Support

- Website: https://nubiferos.org
- Documentation: https://docs.nubiferos.org
- Repository: https://github.com/nubiferos/nubiferos
- Issues: GitHub Issues
- Discussions: GitHub Discussions
- Discord: https://discord.gg/nubiferos

## Roadmap

### Phase 1 (Current)
- Base system with desktop environment
- Cloud CLI tools installation
- Basic credential manager
- Virtual desktop-based workspace isolation
- Simple context indicator
- Basic resource viewer

### Phase 2 (Future)
- OIDC/SSO authentication
- Container-based workspace isolation
- Organization-wide dashboard
- Advanced resource visualization
- Cost analysis and forecasting
- Multi-cloud comparison views

## Credits

NubiferOS is built on top of:
- Debian GNU/Linux
- GNOME Desktop Environment
- Calamares Installer
- Various open source cloud tools

## Etymology

**NubiferOS** comes from the Latin word *nubifer* (feminine: *nubifera*), meaning "cloud-bearing" or "cloud-carrier" - perfectly describing an OS that bears and manages multiple clouds.

## Version

Current Version: 1.0 (Nimbus)
