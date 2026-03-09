# NubiferOS Security Update Process

## Update Architecture

NubiferOS uses a multi-layer update strategy:

1. **Debian security updates** — upstream patches via `unattended-upgrades`
2. **NubiferOS package updates** — OTA via custom APT repository at `packages.nubiferos.org`
3. **Kernel updates** — via Debian security repo with `needrestart` + `kexec` for fast reboots

### APT Repository Infrastructure

```
packages.nubiferos.org (CloudFront → S3)
├── dists/bookworm/main/binary-all/
│   ├── Packages
│   ├── Packages.gz
│   └── Release
├── pool/main/
│   ├── nubifer-core_*.deb
│   ├── nubifer-creds_*.deb
│   ├── nubifer-workspace_*.deb
│   ├── nubifer-dashboard_*.deb
│   ├── nubifer-tools_*.deb
│   ├── nubifer-welcome_*.deb
│   ├── nubifer-updater_*.deb
│   ├── nubifer-security_*.deb
│   └── nubifer-branding_*.deb
└── GPG signed with NubiferOS release key
```

### Update Flow

```
                    ┌─────────────────┐
  Push to trunk ──→ │ GitHub Actions   │
                    │ publish-packages │
                    └────────┬────────┘
                             │ build-debs.sh
                             │ publish-repo.sh
                             ▼
                    ┌─────────────────┐
                    │ S3 + CloudFront  │
                    │ packages.nubifer │
                    │  eros.org        │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
    ┌──────────────────┐         ┌──────────────────┐
    │ nubifer-update    │         │ unattended-       │
    │ .timer (6h)       │         │ upgrades (daily)  │
    │ NubiferOS pkgs    │         │ Debian security   │
    └──────────────────┘         └──────────────────┘
```

## During ISO Build

1. **APT sources include security repo**:
   ```
   deb http://security.debian.org/debian-security bookworm-security main
   ```

2. **Build process runs upgrades**:
   - `extract-debian.sh`: Initial `apt-get upgrade` after bootstrap
   - `security-cleanup.sh`: Final `apt-get upgrade` before ISO creation

3. **NubiferOS repo bootstrapped into ISO**:
   - APT source: `/etc/apt/sources.list.d/nubiferos.list`
   - GPG key: `/etc/apt/keyrings/nubiferos.gpg`
   - Update timer: `nubifer-update.timer` (every 6 hours)

4. **Latest patches at build time** are included in the ISO

## After Installation

### Automatic Updates

**Debian Security (via unattended-upgrades)**:
- Checks daily for security patches
- Installs automatically
- Configured in `/etc/apt/apt.conf.d/50unattended-upgrades`

**NubiferOS Packages (via nubifer-update.timer)**:
- Checks every 6 hours (with 30-min random delay)
- Auto-installs all nubifer-* package updates
- Desktop notification on completion
- Logs to syslog with tag `nubifer-update`
- Stamp file: `/var/lib/nubifer/last-update-check`

### Manual Updates

```bash
# Update all packages
sudo apt update && sudo apt upgrade

# Update only NubiferOS packages
sudo nubifer-update-service

# Check update status
cat /var/lib/nubifer/last-update-check
```

### Kernel Updates

NubiferOS uses `needrestart` + `kexec-tools` for fast kernel reboots:

- **needrestart**: Detects when services need restarting after library updates, configured for automatic restarts (`$nrconf{restart} = 'a'`)
- **kexec-tools**: Enables fast reboots by loading the new kernel directly, skipping BIOS/POST (~5-10 seconds vs ~60+ seconds)

```bash
# Check if reboot is required
nubifer-reboot-check

# Fast reboot using kexec (skips BIOS/POST)
sudo nubifer-fast-reboot

# Normal reboot (full hardware re-initialization)
sudo systemctl reboot
```

## CI/CD Pipelines

### Package Publishing (`publish-packages.yml`)
- **Trigger**: Push to trunk when component/script/config files change
- **Process**: `build-debs.sh` → `publish-repo.sh` → S3/CloudFront
- **GPG signing**: Release file signed with NubiferOS key (passphrase from GitHub Secrets)

### ISO Release (`release.yml`)
- **Trigger**: Manual dispatch with version bump (patch/minor/major)
- **Process**: Promote staging ISO to production, create git tag + GitHub Release
- **Approval**: Requires `production` environment approval gate

### ISO Build (`build-iso.yml`)
- **Trigger**: Push to trunk (auto) or manual dispatch
- **Output**: Staging ISO in S3 (not promoted until release)

## Understanding CVE Reports

### Why CVEs May Still Appear

1. **Debian backports fixes**: Debian patches vulnerabilities without changing version numbers. Scanners like grype check version numbers, so they may flag "vulnerable" versions that are actually patched.

2. **Not yet fixed**: Some CVEs are waiting for:
   - Upstream project to release a fix
   - Debian maintainers to backport the fix
   - Testing before release to stable

3. **Disputed/Not applicable**: Some CVEs:
   - Don't apply to Debian's build configuration
   - Are disputed by the project maintainers
   - Require specific conditions not present in NubiferOS

### Checking Debian Security Status

1. **Debian Security Tracker**: https://security-tracker.debian.org/
   - Search for specific CVEs
   - See if Debian considers it fixed

2. **Check package changelog**:
   ```bash
   apt changelog <package-name> | grep -i CVE
   ```

3. **Check if patched**:
   ```bash
   dpkg -s <package-name> | grep Version
   # Then check security tracker for that version
   ```

## CVE Triage Process

### For each Critical/High CVE:

1. **Check Debian Security Tracker**
   - Is it marked as "fixed" in bookworm?
   - Is there a DSA (Debian Security Advisory)?

2. **Assess applicability**
   - Does NubiferOS use the vulnerable feature?
   - Is the attack vector relevant to our use case?

3. **Take action**
   - If fixed: Ensure we're on latest version
   - If not fixed: Add to allowlist with justification OR remove package
   - If not applicable: Add to allowlist with explanation

## Packages Removed for Security

The following packages were removed from the ISO to eliminate CVEs:

| Package | CVEs Eliminated | Reason for Removal |
|---------|-----------------|-------------------|
| gnome-remote-desktop | 84 Critical | RDP not needed in installer |
| ipp-usb | 7 Critical | IPP printing not needed |
| imagemagick | 6 Critical | Image processing not needed |
| ppp | 2 Critical | Dial-up/VPN not needed |
| linux-headers | 1676 High | Dev tools not needed |

These can be installed post-install if needed:
```bash
apt install gnome-remote-desktop  # RDP support
apt install ipp-usb               # IPP-over-USB printing
apt install imagemagick           # Image processing
apt install ppp                   # PPP connections
apt install linux-headers-amd64   # Kernel module building
```

## Monitoring for New CVEs

1. **Subscribe to debian-security-announce**:
   https://lists.debian.org/debian-security-announce/

2. **Run periodic scans**:
   ```bash
   # On installed system
   nubifer-vuln-scan

   # On ISO (via GitHub Actions)
   # Trigger security-scan workflow manually
   ```

3. **Check before releases**:
   - Run full vulnerability scan
   - Review new Critical/High CVEs
   - Update or remove affected packages
