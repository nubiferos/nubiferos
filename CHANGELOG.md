# Changelog

All notable changes to CloudOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and build system
- Build configuration with security hardening options
- Project documentation (README, CONTRIBUTING, LICENSE)
- Version control setup with .gitignore

## [1.0.0] - TBD

### Planned Features

#### Base System
- Debian 12 (Bookworm) based distribution
- GNOME desktop environment
- Full disk encryption (LUKS) mandatory
- Security hardening (AppArmor, firewall, automatic updates)

#### Cloud Tools
- AWS CLI tools (aws-cli, sam-cli, eksctl, cdk)
- Azure CLI tools (az)
- Google Cloud CLI tools (gcloud)
- Infrastructure as Code tools (Terraform, Pulumi, Ansible)
- Container tools (Docker, kubectl, Helm, k9s)

#### Custom Components
- Credential Manager: Secure credential storage with system keyring
- Context Manager: Workspace isolation and switching
- Resource Viewer: GUI for browsing cloud resources offline
- Context Indicator: Visual indicator showing current cloud context

#### Security Features
- Triple-layer credential encryption
- Workspace isolation using virtual desktops
- Read-only mode for safe browsing
- Automatic security updates
- Comprehensive audit logging

#### Installation
- Calamares-based graphical installer
- Mandatory full disk encryption
- Post-install configuration automation

---

## Version History

### Version 1.0 - "Nimbus" (Planned)
First stable release of CloudOS with core functionality for multi-cloud management.

---

## Release Notes Format

Each release will include:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future releases
- **Removed**: Features that have been removed
- **Fixed**: Bug fixes
- **Security**: Security improvements and fixes

---

[Unreleased]: https://github.com/cloudos/cloudos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/cloudos/cloudos/releases/tag/v1.0.0
