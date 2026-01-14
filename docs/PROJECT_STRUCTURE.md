# NubiferOS Project Structure

This document provides a detailed overview of the NubiferOS project structure.

## Directory Tree

```
nubiferos/
├── .kiro/                                    # Kiro specifications
│   └── specs/
│       └── custom-linux-distro/
│           ├── requirements.md               # EARS requirements
│           ├── design.md                     # Architecture design
│           └── tasks.md                      # Implementation tasks
│
├── build/                                    # Build system
│   ├── config.sh                            # Build configuration (executable)
│   ├── README.md                            # Build system documentation
│   ├── build-iso.sh                         # ISO creation script (to be implemented)
│   ├── customize-system.sh                  # System customization (to be implemented)
│   └── install-cloud-tools.sh               # Cloud tools installer (to be implemented)
│
├── components/                               # Custom NubiferOS components
│   ├── README.md                            # Components overview
│   │
│   ├── credential-manager/                  # Credential management service
│   │   ├── src/                            # Python source code
│   │   ├── config/                         # Configuration files
│   │   └── systemd/                        # Systemd service definitions
│   │
│   ├── context-manager/                     # Workspace context service
│   │   ├── src/                            # Python/Go source code
│   │   ├── dbus/                           # D-Bus interface definitions
│   │   └── systemd/                        # Systemd service definitions
│   │
│   ├── resource-viewer/                     # GUI resource browser
│   │   ├── src/                            # Frontend source (React/Vue)
│   │   ├── backend/                        # API server (Python/Go)
│   │   ├── indexer/                        # Cloud resource indexer
│   │   └── database/                       # Database schema and migrations
│   │
│   ├── context-indicator/                   # Desktop indicator widget
│   │   ├── gnome-extension/                # GNOME Shell extension
│   │   └── kde-plasmoid/                   # KDE Plasma widget
│   │
│   └── ai-assistant/                        # AI Assistant framework
│       ├── src/                            # AI service source code
│       ├── providers/                      # LLM provider plugins
│       ├── filters/                        # Security filters
│       ├── config/                         # Configuration templates
│       └── systemd/                        # Service definitions
│
├── configs/                                  # System configuration files
│   ├── desktop/                            # Desktop environment configs
│   ├── cloud-tools/                        # Cloud CLI configurations
│   └── security/                           # Security policies (AppArmor, etc.)
│
├── installer/                                # Custom installer
│   ├── calamares/                          # Calamares installer configuration
│   └── scripts/                            # Post-install scripts
│
├── iso/                                      # ISO build workspace (generated)
│
├── output/                                   # Build artifacts (generated)
│
├── logs/                                     # Build logs (generated)
│
├── docs/                                     # Documentation
│   └── README.md                           # Documentation index
│
├── scripts/                                  # Helper scripts
│   ├── validate-structure.sh               # Project structure validator
│   └── init-git.sh                         # Git initialization script
│
├── .gitignore                               # Git ignore rules
├── .vscode/                                 # VS Code configuration
├── CHANGELOG.md                             # Version history
├── CONTRIBUTING.md                          # Contribution guidelines
├── LICENSE                                  # MIT License
├── PROJECT_STRUCTURE.md                     # This file
├── QUICKSTART.md                            # Quick start guide
├── README.md                                # Project overview
└── VERSION                                  # Current version (1.0.0-dev)
```

## Key Directories

### Build System (`build/`)
Contains all scripts and configuration for building the NubiferOS ISO image.

**Key Files**:
- `config.sh`: Central configuration with all build parameters
- `build-iso.sh`: Master build orchestration script
- `install-cloud-tools.sh`: Installs AWS, Azure, GCP tools
- `customize-system.sh`: Applies NubiferOS customizations

### Components (`components/`)
Custom NubiferOS components that provide core functionality.

**Components**:
1. **credential-manager**: Secure credential storage with encryption
2. **context-manager**: Workspace isolation and switching
3. **resource-viewer**: GUI for browsing cloud resources
4. **context-indicator**: Visual context display in desktop
5. **ai-assistant**: Optional AI integration for natural language cloud management

### Configuration (`configs/`)
System-wide configuration files organized by category.

**Categories**:
- `desktop/`: GNOME/KDE configurations
- `cloud-tools/`: Default configs for AWS CLI, Azure CLI, etc.
- `security/`: AppArmor profiles, firewall rules, audit policies

### Installer (`installer/`)
Installation system based on Calamares.

**Contents**:
- `calamares/`: Installer configuration and branding
- `scripts/`: Post-installation setup scripts

### Documentation (`docs/`)
Project documentation organized by audience.

**Planned Sections**:
- User guides
- Developer documentation
- Security documentation
- API reference

## File Purposes

### Root Level Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview, features, and usage |
| `QUICKSTART.md` | Quick start guide for new users |
| `CONTRIBUTING.md` | Contribution guidelines and standards |
| `CHANGELOG.md` | Version history and release notes |
| `LICENSE` | MIT License text |
| `VERSION` | Current version number |
| `.gitignore` | Git ignore patterns |
| `PROJECT_STRUCTURE.md` | This file - project structure documentation |

### Build Configuration

The `build/config.sh` file contains:
- Distribution information (name, version, codename)
- Base distribution settings (Debian 12)
- Desktop environment selection (GNOME)
- Security configuration (encryption, AppArmor, firewall)
- Component versions
- Package lists
- Build paths
- Helper functions

### Component Structure

Each component follows this structure:
```
component-name/
├── src/              # Source code
├── tests/            # Unit and integration tests (to be added)
├── config/           # Configuration files
├── docs/             # Component documentation (to be added)
└── README.md         # Component overview (to be added)
```

## Generated Directories

These directories are created during the build process:

- **`iso/`**: Temporary workspace for ISO creation
- **`output/`**: Final ISO images and checksums
- **`logs/`**: Build logs with timestamps

These are excluded from version control via `.gitignore`.

## Configuration Management

### Build Configuration
All build parameters are centralized in `build/config.sh`:
- Easy to modify for different variants
- Validated before build starts
- Exported as environment variables

### Component Configuration
Each component has its own configuration:
- Stored in component's `config/` directory
- Installed to `/etc/nubiferos/` on target system
- Can be customized per installation

### Security Configuration
Security policies are in `configs/security/`:
- AppArmor profiles for NubiferOS services
- Firewall rules (ufw configuration)
- Audit rules (auditd configuration)
- Kernel hardening parameters

## Development Workflow

1. **Setup**: Run `./scripts/validate-structure.sh`
2. **Configure**: Edit `build/config.sh` if needed
3. **Develop**: Implement components in `components/`
4. **Test**: Add tests in component `tests/` directories
5. **Document**: Update relevant documentation
6. **Build**: Run `build/build-iso.sh` (when implemented)
7. **Validate**: Test ISO in VM

## Version Control

### Tracked Files
- Source code
- Configuration files
- Documentation
- Build scripts
- Specifications

### Ignored Files
- Build artifacts (`iso/`, `output/`)
- Logs (`logs/`)
- Credentials and secrets
- IDE-specific files (except `.vscode/` if needed)
- Temporary files

## Security Considerations

### Sensitive Files
Never commit:
- Credentials (`.pem`, `.key` files)
- Secrets (API keys, tokens)
- Private keys
- GPG private keys

### Build Security
- Verify checksums of downloaded packages
- Sign ISO images with GPG
- Use HTTPS for all downloads
- Validate base ISO signatures

## Extensibility

The structure supports:
- Adding new components in `components/`
- Adding new cloud providers
- Custom desktop environments
- Additional security policies
- Plugin system (future)

## References

- [Requirements](.kiro/specs/custom-linux-distro/requirements.md)
- [Design](.kiro/specs/custom-linux-distro/design.md)
- [Tasks](.kiro/specs/custom-linux-distro/tasks.md)
- [Build System](build/README.md)
- [Components](components/README.md)
- [Documentation](docs/README.md)

## Maintenance

### Adding New Components
1. Create directory in `components/`
2. Follow standard component structure
3. Update `components/README.md`
4. Add to build configuration
5. Update documentation

### Modifying Build System
1. Edit `build/config.sh` for configuration changes
2. Update build scripts for process changes
3. Test in clean environment
4. Update `build/README.md`

### Updating Documentation
1. Keep documentation in sync with code
2. Update version numbers consistently
3. Maintain CHANGELOG.md
4. Add examples and screenshots

## Status

**Current Phase**: Project Setup Complete ✓

**Next Steps**:
- Implement build system scripts (Task 2)
- Develop credential manager (Task 3)
- Develop context manager (Task 4)
- Develop resource viewer (Task 7)
- Develop context indicator (Task 5)

See [tasks.md](.kiro/specs/custom-linux-distro/tasks.md) for detailed implementation plan.
