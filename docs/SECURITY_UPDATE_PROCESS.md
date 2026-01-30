# NubiferOS Security Update Process

## How Security Updates Work

### During ISO Build

1. **APT sources include security repo**:
   ```
   deb http://security.debian.org/debian-security bookworm-security main
   ```

2. **Build process runs upgrades**:
   - `extract-debian.sh`: Initial `apt-get upgrade` after bootstrap
   - `security-cleanup.sh`: Final `apt-get upgrade` before ISO creation

3. **Latest patches at build time** are included in the ISO

### After Installation

1. **Automatic security updates** via `unattended-upgrades`:
   - Enabled by default in NubiferOS
   - Checks daily for security patches
   - Installs automatically (configurable)

2. **Manual updates**:
   ```bash
   sudo apt update && sudo apt upgrade
   ```

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
