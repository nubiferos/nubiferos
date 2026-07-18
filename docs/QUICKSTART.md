# NubiferOS Quick Start Guide

> **This is the developer/build quick start.** If you have NubiferOS installed and want to set up workspaces and credentials, see the [User Quick Start](guides/USER_QUICKSTART.md).

## Project Setup

### 1. Validate Project Structure

Verify that all directories and files are in place:

```bash
./scripts/validate-structure.sh
```

### 2. Initialize Git Repository (Optional)

If you want to set up version control:

```bash
./scripts/init-git.sh
```

### 3. Review Configuration

Check the build configuration:

```bash
source build/config.sh
print_config
```

## Project Structure Overview

```
nubiferos/
├── build/                    # Build system and scripts
├── components/               # Custom NubiferOS components
│   ├── credential-manager/  # Secure credential storage
│   ├── context-manager/     # Workspace management
│   ├── resource-viewer/     # GUI resource browser
│   └── context-indicator/   # Desktop indicator
├── configs/                  # System configurations
│   ├── desktop/             # Desktop environment
│   ├── cloud-tools/         # Cloud CLI configs
│   └── security/            # Security policies
├── installer/                # Installation system
│   ├── calamares/           # Installer config
│   └── scripts/             # Post-install scripts
├── docs/                     # Documentation
└── scripts/                  # Helper scripts
```

## Next Steps

### For Developers

1. **Read the specifications**:
   - [Requirements](.kiro/specs/custom-linux-distro/requirements.md)
   - [Design](.kiro/specs/custom-linux-distro/design.md)
   - [Tasks](.kiro/specs/custom-linux-distro/tasks.md)

2. **Set up development environment**:
   ```bash
   # Install build dependencies
   sudo apt-get update
   sudo apt-get install -y debootstrap squashfs-tools xorriso \
       grub-pc-bin grub-efi-amd64-bin python3 python3-pip nodejs npm
   ```

3. **Start implementing tasks**:
   - Follow the task list in `.kiro/specs/custom-linux-distro/tasks.md`
   - Each task references specific requirements
   - Implement one task at a time

### For Contributors

1. Read [CONTRIBUTING.md](CONTRIBUTING.md)
2. Check open issues on GitHub
3. Join discussions
4. Submit pull requests

## Key Files

- **build/config.sh**: Main build configuration
- **README.md**: Project overview and features
- **CONTRIBUTING.md**: Contribution guidelines
- **CHANGELOG.md**: Version history
- **LICENSE**: MIT License

## Build Configuration

The build system is configured in `build/config.sh`:

- **Base Distribution**: Debian 12 (Bookworm)
- **Desktop**: GNOME 43
- **Security**: Hardened (AppArmor, firewall, encryption)
- **Architecture**: x86_64

To customize, edit `build/config.sh` and modify:
- Package selections
- Component versions
- Security settings
- Build options

## Component Development

Each component has its own directory:

```
component-name/
├── src/           # Source code
├── config/        # Configuration files
├── systemd/       # Service definitions
└── README.md      # Component documentation
```

### Credential Manager
- **Language**: Python
- **Purpose**: Secure credential storage
- **Technology**: libsecret, D-Bus

### Context Manager
- **Language**: Python/Go
- **Purpose**: Workspace isolation
- **Technology**: D-Bus, virtual desktops

### Resource Viewer
- **Language**: TypeScript/Python
- **Purpose**: GUI for cloud resources
- **Technology**: Electron/Tauri, React/Vue

### Context Indicator
- **Language**: JavaScript/QML
- **Purpose**: Desktop indicator
- **Technology**: GNOME Shell extension, KDE Plasmoid

## Useful Commands

### Validate Structure
```bash
./scripts/validate-structure.sh
```

### Initialize Git
```bash
./scripts/init-git.sh
```

### View Build Config
```bash
source build/config.sh && print_config
```

### Check Version
```bash
cat VERSION
```

## Getting Help

- **Documentation**: See [docs/](docs/)
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)

## Resources

- [Debian Documentation](https://www.debian.org/doc/)
- [GNOME Developer Documentation](https://developer.gnome.org/)
- [Calamares Documentation](https://calamares.io/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Google Cloud CLI Documentation](https://cloud.google.com/sdk/gcloud)

## Status

Current Version: 1.0.0-dev

This is the initial project setup. The build system and component implementations are in progress.

See [tasks.md](.kiro/specs/custom-linux-distro/tasks.md) for the implementation roadmap.
