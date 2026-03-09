# Changelog

All notable changes to NubiferOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### OTA Update Infrastructure (March 2026)
- **APT package repository** hosted on S3 with CloudFront CDN at `packages.nubiferos.org`
- **GPG-signed repository** with Release file signing for package integrity
- **9 .deb packages** covering all NubiferOS components: core, creds, workspace, dashboard, tools, welcome, updater, security, branding
- **`build/build-debs.sh`** — builds all .deb packages from source tree
- **`build/publish-repo.sh`** — publishes debs to S3 APT repo with GPG signing
- **`release.yml`** — manual dispatch workflow for production releases with version bump, approval gate, GitHub Release creation, website dispatch
- **`publish-packages.yml`** — auto-publishes .deb packages on push to trunk when component files change
- ISO bootstrap: APT source, GPG key, and systemd timer baked in for first-boot OTA access
- `nubifer-update.timer` — checks for NubiferOS package updates every 6 hours with desktop notifications
- AWS infrastructure: S3 bucket, CloudFront distribution, ACM cert, Route53 DNS for `packages.nubiferos.org`

#### Security Hardening Package (`nubifer-security`)
- AppArmor profiles and enforcement service
- UFW firewall (deny incoming, allow outgoing)
- fail2ban with SSH jail (3 retries, 2hr ban)
- auditd rules for config/credential/auth monitoring
- Kernel hardening via sysctl (ASLR, ptrace, BPF, network hardening)
- SSH hardening (no root login, key-only auth, session limits)
- PAM password quality (16 char min, all character classes)
- `needrestart` — automatic service restarts after library updates
- `kexec-tools` — fast kernel reboots (skips BIOS/POST, ~5-10s vs ~60+s)
- `nubifer-reboot-check` — reboot-required status for dashboard integration
- `nubifer-fast-reboot` — kexec-based fast reboot script

#### Branding Package (`nubifer-branding`)
- `/etc/os-release`, `lsb-release`, `issue`, `issue.net`, `motd` generated from brand.conf
- Plymouth boot splash theme
- Wallpapers (10 color variants + 4 cloud provider themes)
- Icons (multiple sizes + SVG), GDM branding, dconf settings
- GNOME wallpaper picker XML, Shell context indicator extension, terminal prompt integration

- **STS Token Mode for AWS credentials**: Automatically generates temporary STS session tokens instead of using long-lived access keys
  - Enabled by default when adding AWS credentials via `nubifer-creds add -t aws`
  - Base credentials never leave the credential helper process
  - Tokens cached with auto-refresh (5-minute buffer before expiry)
  - Token duration configurable (default: 1 hour, range: 15 min - 12 hours)
  - Use `--no-sts` flag to disable and use static credentials instead
  - New commands: `nubifer-creds token {enable|disable|status|clear|refresh}`
- Brand logos (multiple color variants, icon sizes, dark/light/transparent modes)
- Simplified security-scan workflow (gitleaks, shellcheck, credential pattern checks)
- Security Dashboard: Real-time security status monitoring with score calculation
- Tool Update Checker: Config-driven version checking for all cloud tools (`nubifer-check-updates`)
- Installer package descriptions: Every package now shows what it does
- Security Dashboard slide added to installer slideshow
- Firefox bookmarks: AI/ML section, expanded AWS services, security tools
- LUKS + TPM cloud strategy documentation
- Read-only mode shortcuts: `nubifer-workspace ro` and `nubifer-workspace rw`
- Timed write sessions: `sudo nubifer-workspace rw -d 30` auto-reverts after 30 minutes
- High-visibility mode indicators: green background for read-only, red for read-write
- Build security pipeline: SBOM generation, vulnerability scanning, ISO signing
- Security scan GitHub Actions workflow for automated CVE detection

### Changed
- **`build-iso.yml` simplified** to staging-only builds; production promotion moved to `release.yml`
- **Version bumping** moved from build time to release time (calculated from git tags)
- `nubifer-core` now recommends `nubifer-security` and `nubifer-branding`
- `nubifer-core` postinst generates Firefox ESR policy from bookmarks JSON
- Legacy D-Bus-based CLI wrappers moved to `components/_LEGACY_cli-wrappers/`
- Credential system now uses `credential_process` approach (simpler, more secure than D-Bus)
- AWS CLI pager disabled by default (prevents terminal corruption on Ctrl+C)
- Region is now required when creating workspaces
- AWS wrapper reads region from workspace environment config
- Wayland slide text updated (removed X11 comparison)
- Write mode (`rw`) now requires sudo for security (prevents unauthorized writes)
- Terminal prompt shows `[🔒 RO]` or `[🔓 RW]` with colored backgrounds

### Fixed
- Build workflow: Clean staging directory before upload to prevent artifact accumulation
- Build workflow: Fix ASC file selection when multiple signature files exist
- AWS wrapper now correctly reads region from `environment.AWS_REGION`
- Security Dashboard checks for UFW, AppArmor, Context Indicator improved
- Shellcheck errors in CLI wrappers (SC2168, SC2145, SC2155, SC2064)

### Removed
- **gnome-remote-desktop**: Removed to eliminate FreeRDP dependency (84 Critical CVEs)
  - CVE-2026-22852 through CVE-2026-22857 and others in libfreerdp2-2, libwinpr2-2
  - RDP client not needed in installer ISO; users can install post-install if needed
  - Install manually: `apt install gnome-remote-desktop`
- **ipp-usb**: Removed IPP-over-USB printer daemon (7 Critical CVEs from Go 1.19.8)
  - CVE-2023-24531, CVE-2023-24540, CVE-2023-29402, CVE-2024-24790, etc.
  - Bundled old Go runtime; not needed in installer ISO
  - Install manually: `apt install ipp-usb`
- **imagemagick**: Removed image processing suite (6 Critical CVEs)
  - CVE-2023-5841 and others in libmagickcore, libmagickwand
  - Not needed in installer ISO
  - Install manually: `apt install imagemagick`
- **ppp**: Removed Point-to-Point Protocol daemon (2 Critical CVEs)
  - CVE-2024-58250
  - Dial-up/VPN not needed in installer ISO
  - Install manually: `apt install ppp`
- **linux-headers-amd64**: Removed kernel headers (not needed in installer ISO)
  - Reduces attack surface and ISO size
  - Install manually: `apt install linux-headers-amd64`
- **linux-kbuild, linux-compiler-gcc**: Removed kernel build tools (1676 High CVEs)
  - Build tools not needed at runtime
  - Pulled in by linux-headers; removed with headers

### Security
- Sudo required to enable write mode on workspaces
- Timed write sessions auto-revert to read-only
- Prevents compromised sessions from modifying cloud resources
- Added security cleanup step to build process to remove CVE-laden packages
- ISO now scanned for vulnerabilities before release

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
