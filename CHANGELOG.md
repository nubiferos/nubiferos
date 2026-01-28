# Changelog

All notable changes to NubiferOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Security Dashboard: Real-time security status monitoring with score calculation
- Tool Update Checker: Config-driven version checking for all cloud tools (`nubifer-check-updates`)
- Installer package descriptions: Every package now shows what it does
- Security Dashboard slide added to installer slideshow
- Firefox bookmarks: AI/ML section, expanded AWS services, security tools
- LUKS + TPM cloud strategy documentation
- Read-only mode shortcuts: `nubifer-workspace ro` and `nubifer-workspace rw`
- Timed write sessions: `sudo nubifer-workspace rw -d 30` auto-reverts after 30 minutes
- High-visibility mode indicators: green background for read-only, red for read-write

### Changed
- AWS CLI pager disabled by default (prevents terminal corruption on Ctrl+C)
- Region is now required when creating workspaces
- AWS wrapper reads region from workspace environment config
- Wayland slide text updated (removed X11 comparison)
- Write mode (`rw`) now requires sudo for security (prevents unauthorized writes)
- Terminal prompt shows `[🔒 RO]` or `[🔓 RW]` with colored backgrounds

### Fixed
- AWS wrapper now correctly reads region from `environment.AWS_REGION`
- Security Dashboard checks for UFW, AppArmor, Context Indicator improved

### Security
- Sudo required to enable write mode on workspaces
- Timed write sessions auto-revert to read-only
- Prevents compromised sessions from modifying cloud resources

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
First stable release of NubiferOS with core functionality for multi-cloud management.

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

[Unreleased]: https://github.com/nubiferos/nubiferos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nubiferos/nubiferos/releases/tag/v1.0.0
