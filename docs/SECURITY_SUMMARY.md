# NubiferOS Security Summary

Complete overview of all security features, protections, and hardening measures in NubiferOS.

## Security Philosophy

NubiferOS is built on three core security principles:

1. **Defense in Depth** - Multiple layers of security, not a single point of failure
2. **Proven Technologies** - Battle-tested, audited solutions over custom implementations
3. **Secure by Default** - Security enabled out-of-the-box, not optional

---

## Security Layers

```
┌─────────────────────────────────────────────────────┐
│  Layer 8: User Education & Policies                 │
├─────────────────────────────────────────────────────┤
│  Layer 7: Application Sandboxing (Firejail)        │
├─────────────────────────────────────────────────────┤
│  Layer 6: Credential Encryption (GPG/pass)         │
├─────────────────────────────────────────────────────┤
│  Layer 5: Desktop Isolation (Wayland)              │
├─────────────────────────────────────────────────────┤
│  Layer 4: Mandatory Access Control (AppArmor)      │
├─────────────────────────────────────────────────────┤
│  Layer 3: Kernel Hardening & Firewall              │
├─────────────────────────────────────────────────────┤
│  Layer 2: CPU Security Mitigations                 │
├─────────────────────────────────────────────────────┤
│  Layer 1: Full Disk Encryption (LUKS)              │
└─────────────────────────────────────────────────────┘
```

---

## 1. Full Disk Encryption (LUKS)

### What It Protects
- ✅ Data at rest
- ✅ Physical theft scenarios
- ✅ Unauthorized physical access
- ✅ Forensic analysis of stolen drives

### Implementation
- **Technology**: LUKS (Linux Unified Key Setup)
- **Algorithm**: AES-256-XTS
- **Key Size**: 512-bit
- **Status**: Mandatory (cannot be disabled)

### Current Implementation: LUKS1

**Status:** LUKS1 everywhere (single password)

For the initial release, we're using LUKS1 for simplicity - one password at boot, done.

### Future Consideration: LUKS1/LUKS2 Hybrid

A hybrid approach (LUKS1 /boot + LUKS2 root) would provide maximum security but requires two password prompts (GRUB + initramfs). We'll revisit this during alpha testing once we have a working OS to protect.

| Approach | Evil Maid Protected | GPU Resistant | Passwords |
|----------|---------------------|---------------|-----------|
| **LUKS1 everywhere (current)** | ✅ Yes | ❌ No | 1 |
| Unencrypted /boot + LUKS2 root | ❌ No | ✅ Yes | 1 |
| LUKS1 /boot + LUKS2 root (future) | ✅ Yes | ✅ Yes | 2 (or keyfile) |

**References:**
- [Debian Encrypted Boot Guide](https://cryptsetup-team.pages.debian.net/cryptsetup/encrypted-boot.html)
- [Arch Wiki - Encrypting Entire System](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)

---

## 2. CPU Security Mitigations

### What It Protects
- ✅ Spectre v1, v2, v4 attacks
- ⚠️ RETBleed attacks (partial by default)
- ✅ Meltdown attacks
- ✅ MDS (Microarchitectural Data Sampling)
- ✅ TAA (TSX Asynchronous Abort)

### Implementation
- **Default**: Spectre v2 mitigation enabled
- **RETBleed**: Warning shown, full mitigation optional
- **Performance Impact**: 5-10% (default), 15-30% (full)
- **Configuration**: See `docs/CPU_SECURITY_MITIGATIONS.md`

### RETBleed Warning

You may see this warning on boot:
```
RETBleed: WARNING: Spectre v2 mitigation leaves CPU vulnerable to RETBleed attacks
```

**This is normal and acceptable for most users.** See `RETBLEED_WARNING.md` for details.

### Tools
- `testing/check-cpu-mitigations.sh` - Check current status
- `configs/security/enable-retbleed-mitigation.sh` - Enable full protection
- `configs/security/configure-cpu-mitigations.sh` - Interactive configuration

### Features
- Encrypted root partition
- Encrypted swap
- Secure boot integration
- Recovery key support (physical USB)
- No backdoors

### User Experience
```bash
# Boot process
1. Power on
2. Enter LUKS passphrase
3. System decrypts and boots
```

**Documentation**: [docs/RECOVERY_KEY.md](RECOVERY_KEY.md)

---

## 2. Wayland Display Server

### What It Protects
- ✅ Keylogging between applications
- ✅ Screen capture by malicious apps
- ✅ Window injection attacks
- ✅ Credential theft via display server

### Why Not X11?
X11 (used by Xfce, older systems) has fundamental security flaws:
- Any app can read any keyboard input
- Any app can capture any screen
- No application isolation
- 1980s security model

### Wayland Advantages
- Apps cannot see other apps' input
- Screen capture requires explicit permission
- Modern security architecture (2010s)
- Critical for credential management

### Trade-offs
- Higher resource usage (~1GB RAM vs 400MB)
- Some legacy apps may have compatibility issues
- Worth it for credential security

**Documentation**: [docs/DESKTOP_ENVIRONMENT_ANALYSIS.md](DESKTOP_ENVIRONMENT_ANALYSIS.md)

---

## 3. Credential Management (GPG + pass)

### What It Protects
- ✅ Cloud credentials (AWS, Azure, GCP)
- ✅ API keys and tokens
- ✅ Database passwords
- ✅ SSH keys and passphrases
- ✅ Service account credentials

### Architecture
```
System Keyring (GNOME Keyring)
  └── GPG Master Key
      └── pass (password-store)
          ├── AWS credentials
          ├── Azure credentials
          ├── GCP credentials
          ├── API tokens
          └── Database passwords
```

### Why GPG + pass?
- **Battle-tested**: Decades of security audits
- **Proven**: Used by security professionals worldwide
- **No custom crypto**: Avoids implementation bugs
- **Auditable**: Open source, large community
- **Git integration**: Built-in backup and sync

### Encryption Details
- **Algorithm**: GPG (OpenPGP)
- **Key Type**: RSA 4096-bit or Ed25519
- **Storage**: Encrypted files, one per credential
- **Master Key**: Protected by system keyring

### Features
- Workspace-based credential isolation
- Automatic credential injection into CLIs
- Support for temporary credentials (STS, SSO)
- Credential rotation reminders
- Audit logging
- Bitwarden/1Password integration

**Documentation**: [docs/CREDENTIAL_SECURITY.md](CREDENTIAL_SECURITY.md)

---

## 4. Workspace Isolation (Firejail)

### What It Protects
- ✅ Cross-workspace credential leakage
- ✅ Accidental wrong-account operations
- ✅ Filesystem-based attacks
- ✅ Resource exhaustion

### Technology
- **Firejail**: Application sandboxing using Linux namespaces
- **Namespaces**: PID, Network, Mount, IPC isolation
- **Seccomp-bpf**: System call filtering
- **Resource Limits**: Memory, CPU, file size limits

### How It Works
```bash
# User runs AWS CLI
aws s3 ls

# Behind the scenes:
1. CLI wrapper detects active workspace
2. Generates workspace-specific Firejail profile
3. Launches AWS CLI in sandbox
4. Sandbox can ONLY access workspace credentials
5. Other workspaces' credentials are invisible
```

### Isolation Features
- **Filesystem**: Each workspace sees only its credentials
- **Read-only mode**: Enforced at sandbox level
- **Network**: Optional network filtering
- **Resources**: Memory/CPU limits prevent DoS

### Example Profile
```
# Workspace ABC123 profile
whitelist ~/.aws/workspace-abc123
blacklist ~/.aws/workspace-def456
blacklist ~/.aws/workspace-ghi789
read-only ~/.aws/workspace-abc123  # If read-only mode
rlimit-as 2G  # Max 2GB memory
rlimit-cpu 3600  # Max 1 hour CPU
```

### Performance Impact
- Overhead: ~5-10ms startup, ~5% runtime
- Worth it for credential isolation

**Documentation**: [components/workspace-manager/FIREJAIL_INTEGRATION.md](../components/workspace-manager/FIREJAIL_INTEGRATION.md)

---

## 5. Mandatory Access Control (AppArmor)

### What It Protects
- ✅ Privilege escalation
- ✅ Unauthorized file access
- ✅ Kernel exploits
- ✅ Application vulnerabilities

### Technology
- **AppArmor**: Kernel-level mandatory access control
- **Enforcement**: Cannot be bypassed by user-space
- **Profiles**: Per-application security policies

### Profiles Included
- Cloud CLIs (aws, az, gcloud, oci)
- Credential manager
- Browsers (Firefox, Chromium)
- System services

### Example: Credential Manager Profile
```
/usr/bin/nubifer-credential-manager {
  # Allow reading configuration
  /etc/nubifer/** r,
  
  # Allow credential storage
  owner @{HOME}/.config/nubifer/** rw,
  
  # Deny network access
  deny network,
  
  # Allow keyring access
  owner @{HOME}/.local/share/keyrings/** rw,
}
```

### Benefits
- Kernel-level enforcement
- Limits damage from compromised applications
- Complements Firejail sandboxing
- Default on Debian/Ubuntu

**Documentation**: [build/apply-security-hardening.sh](../build/apply-security-hardening.sh)

---

## 6. Network Security

### Firewall (UFW)

**Default Policy**: Deny all incoming, allow outgoing

```bash
# Status
sudo ufw status

# Default rules
Default: deny (incoming), allow (outgoing)
```

### Features
- Stateful packet filtering
- Application-aware rules
- IPv4 and IPv6 support
- Easy management

### Intrusion Prevention (fail2ban)

**Protection Against**: Brute force attacks, port scanning

```bash
# Configuration
Ban time: 1 hour
Max retries: 5 attempts
Find time: 10 minutes

# Monitored services
- SSH (if enabled)
- System authentication
```

### Kernel Hardening

**Sysctl Parameters**:
```bash
# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable IP forwarding
net.ipv4.ip_forward = 0

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1

# ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2

# Restrict kernel pointers
kernel.kptr_restrict = 2

# Restrict ptrace
kernel.yama.ptrace_scope = 2
```

---

## 7. Audit Logging (auditd)

### What It Monitors
- ✅ Credential file access
- ✅ Authentication attempts
- ✅ Password/group changes
- ✅ Sudo usage
- ✅ Network configuration changes
- ✅ File deletions
- ✅ Kernel module loading

### Audit Rules
```bash
# Credential access
-w /etc/nubifer/ -p wa -k nubifer_config
-w /home/ -p wa -k nubifer_credentials

# Authentication
-w /var/log/auth.log -p wa -k auth_log
-w /etc/shadow -p wa -k shadow_changes

# Sudo usage
-w /var/log/sudo.log -p wa -k sudo_log

# File deletions
-a always,exit -F arch=b64 -S unlink -k delete
```

### Viewing Logs
```bash
# View audit log
sudo ausearch -k nubifer_credentials

# View authentication events
sudo ausearch -k auth_log

# View sudo usage
sudo ausearch -k sudo_log
```

---

## 8. Automatic Security Updates

### What It Updates
- ✅ Security patches
- ✅ Kernel updates
- ✅ System packages
- ✅ Cloud tools (via update checker)

### Configuration
```bash
# Update frequency
Daily: Check for updates
Daily: Download updates
Daily: Install security updates
Weekly: Clean old packages

# Reboot policy
Automatic reboot: Disabled (manual control)
Reboot time: 03:00 (if enabled)
```

### Update Sources
- Debian security repository
- NubiferOS package repository
- Cloud provider official sources (AWS, Azure, GCP)

### Manual Updates
```bash
# Check for updates
nubifer-update-checker

# Install updates
sudo apt update && sudo apt upgrade

# Update cloud tools
nubifer-update-checker --install-all
```

**Documentation**: [docs/UPDATE_MANAGEMENT.md](UPDATE_MANAGEMENT.md)

---

## 9. Password Security

### Password Policies
```bash
# Requirements
Minimum length: 16 characters
Digit required: Yes
Uppercase required: Yes
Lowercase required: Yes
Special character required: Yes
Minimum character classes: 4
Max repeated characters: 2
Max sequential characters: 3
Dictionary check: Enabled
Username check: Enabled
```

### Password Storage
- System passwords: `/etc/shadow` (hashed with SHA-512)
- Credential passwords: GPG-encrypted via pass
- No plaintext passwords anywhere

### Password Hashing
- **Algorithm**: SHA-512 (yescrypt on newer systems)
- **Rounds**: 5000+ (configurable)
- **Salt**: Random per password

---

## 10. SSH Hardening (if enabled)

### Configuration
```bash
# Protocol
Protocol 2 only (SSH-2)

# Authentication
Root login: Disabled
Password authentication: Disabled
Public key authentication: Only method
Max auth tries: 3

# Session limits
Client alive interval: 300 seconds
Max sessions: 2

# Forwarding
X11 forwarding: Disabled
```

### Key Requirements
- Minimum key size: 2048-bit RSA or Ed25519
- Key-based authentication only
- No password authentication

---

## 11. Recovery Mechanisms

### Recovery Key (Physical USB)

**Purpose**: Emergency access without backdoors

**Features**:
- Physical USB required (no remote access)
- Can reset passwords
- Can unlock LUKS drives
- Must be stored securely (safe/vault)

**Use Cases**:
- Forgotten password
- Lost LUKS passphrase
- Rogue employee lockout
- Emergency data access

**Security**:
- Physical access = full control
- Store like you'd store encryption keys
- Create multiple copies
- Test quarterly

**Documentation**: [docs/RECOVERY_KEY.md](RECOVERY_KEY.md)

---

## 12. Browser Security

### Firefox Hardening

**Privacy Settings**:
```javascript
// Disable telemetry
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);

// Enhanced tracking protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);

// HTTPS-only mode
user_pref("dom.security.https_only_mode", true);

// Disable WebRTC (prevents IP leaks)
user_pref("media.peerconnection.enabled", false);

// Resist fingerprinting
user_pref("privacy.resistFingerprinting", true);
```

### Chromium Hardening
- Sandboxed processes
- Site isolation enabled
- Safe browsing enabled
- Third-party cookies blocked

### Pre-configured Bookmarks
- 150+ cloud documentation links
- Organized by provider and service
- No tracking or analytics links

**Documentation**: [docs/BROWSER_CONFIGURATION.md](BROWSER_CONFIGURATION.md)

---

## Security Verification

### Post-Install Verification

```bash
# Run security verification
sudo verify-security

# Output shows:
✓ AppArmor: enabled
✓ UFW: enabled
✓ fail2ban: enabled
✓ unattended-upgrades: enabled
✓ auditd: enabled
✓ All security configurations present
```

### Automated Testing

```bash
# Run post-install tests
cd tests
sudo ./post-install-tests.sh

# Tests include:
- Security services running
- Firewall configured
- AppArmor profiles loaded
- Audit rules active
- Kernel hardening applied
- Password policies enforced
```

**Documentation**: [docs/POST_INSTALL_TESTING.md](POST_INSTALL_TESTING.md)

---

## Pre-install vs Post-install Security

### Pre-install Security (Installation Phase)

**Trust Boundary**: Limited to installer ISO and installation process

**Security Measures**:
- Installer ISO integrity verification (checksums)
- Kiosk-mode installer environment (restricted session)
- Mandatory full disk encryption during installation
- No live user or general workstation functionality

**Threats Addressed**:
- Installer ISO tampering (via checksum verification)
- Accidental installation to wrong disk (via Calamares UI)
- Installation without encryption (mandatory LUKS)

**Threats NOT Addressed**:
- Compromised installation media or download source
- Network-based attacks during installation
- Hardware-level attacks on installation system
- UEFI/BIOS firmware compromise

**Note**: The installer environment provides minimal attack surface but cannot protect against all pre-install threats. Users must verify ISO integrity and use trusted installation media.

### Post-install Security (Operational Phase)

**Trust Boundary**: Full NubiferOS system with all security layers active

**Security Measures**:
- All 8 security layers (encryption, isolation, access control, etc.)
- Credential management and workspace isolation
- Network security and intrusion prevention
- Audit logging and monitoring
- Automatic security updates

**Threats Addressed**:
- Application-level credential theft
- Cross-workspace credential leakage
- Physical device theft (encrypted disk)
- Malware and privilege escalation
- Network intrusions and brute force attacks

**Threats NOT Addressed**:
- Hardware-level attacks and side channels
- Nation-state and advanced persistent threats
- Social engineering and user behavior
- Third-party application vulnerabilities

**Note**: Post-install security provides comprehensive protection for the defined threat model but has explicit scope boundaries documented in [SECURITY_NON_GOALS.md](SECURITY_NON_GOALS.md).

---

## Threat Model

### What NubiferOS Protects Against

✅ **Physical Theft**: Full disk encryption  
✅ **Keylogging**: Wayland isolation  
✅ **Screen Capture**: Wayland permissions  
✅ **Credential Theft**: GPG encryption + workspace isolation  
✅ **Cross-Account Mistakes**: Workspace sandboxing  
✅ **Malicious Applications**: AppArmor + Firejail  
✅ **Network Attacks**: Firewall + fail2ban  
✅ **Privilege Escalation**: AppArmor + kernel hardening  
✅ **Brute Force**: fail2ban + strong passwords  
✅ **Unauthorized Access**: Authentication + audit logging  

### What NubiferOS Does NOT Protect Against

⚠️ **Physical Access with Recovery Key**: By design (no backdoors)  
⚠️ **Kernel Exploits**: Keep system updated  
⚠️ **Zero-Day Vulnerabilities**: No system is perfect  
⚠️ **Social Engineering**: User education required  
⚠️ **Compromised Cloud Accounts**: Use MFA, rotate credentials  
⚠️ **Side-Channel Attacks**: Spectre, Meltdown (hardware level)  

---

## Security Best Practices

### For Users

1. **Use Strong Passwords**
   - 16+ characters
   - Mix of character types
   - Unique per service
   - Use password manager

2. **Enable MFA Everywhere**
   - AWS: Use AWS SSO or MFA
   - Azure: Use Azure AD MFA
   - GCP: Use 2-Step Verification
   - GitHub/GitLab: Enable 2FA

3. **Rotate Credentials Regularly**
   - Access keys: Every 90 days
   - Passwords: Every 90 days
   - SSH keys: Annually
   - Use temporary credentials when possible

4. **Use Workspaces Correctly**
   - One workspace per cloud account
   - Enable read-only mode for production
   - Never share workspaces
   - Review workspace access regularly

5. **Keep System Updated**
   - Install security updates promptly
   - Update cloud tools regularly
   - Check for updates weekly

6. **Secure Recovery Key**
   - Store in physical safe/vault
   - Create multiple copies
   - Test quarterly
   - Never store with system

7. **Monitor Audit Logs**
   - Review logs weekly
   - Investigate suspicious activity
   - Set up alerts for critical events

### For Administrators

1. **Enforce Security Policies**
   - Require strong passwords
   - Mandate MFA
   - Regular security audits
   - Incident response plan

2. **Manage Recovery Keys**
   - Document key locations
   - Dual authorization for use
   - Regular testing
   - Secure storage

3. **Monitor Systems**
   - Centralized logging
   - Security alerts
   - Regular vulnerability scans
   - Penetration testing

4. **Train Users**
   - Security awareness training
   - Phishing simulations
   - Incident reporting procedures
   - Best practices documentation

---

## Compliance Considerations

### SOC 2
- ✅ Access controls (AppArmor, Firejail)
- ✅ Encryption at rest (LUKS)
- ✅ Audit logging (auditd)
- ✅ Change management (automatic updates)
- ✅ Incident response (recovery key)

### ISO 27001
- ✅ Information security management
- ✅ Risk assessment (threat model)
- ✅ Access control (multi-layer)
- ✅ Cryptography (GPG, LUKS)
- ✅ Physical security (recovery key)

### HIPAA
- ✅ Encryption (LUKS, GPG)
- ✅ Access controls (AppArmor, Firejail)
- ✅ Audit controls (auditd)
- ✅ Integrity controls (checksums, signatures)
- ✅ Transmission security (HTTPS, SSH)

### PCI DSS
- ✅ Firewall (UFW)
- ✅ Encryption (LUKS, GPG)
- ✅ Access control (multi-layer)
- ✅ Monitoring (auditd)
- ✅ Security testing (automated tests)

---

## Security Roadmap

### Phase 1 (Current - v1.0)
- ✅ Full disk encryption (LUKS)
- ✅ Wayland isolation
- ✅ GPG + pass credential management
- ✅ Firejail workspace isolation
- ✅ AppArmor profiles
- ✅ Firewall + fail2ban
- ✅ Audit logging
- ✅ Automatic updates
- ✅ Recovery key system

### Phase 2 (v1.1)
- 🔄 Container-based workspaces (Podman)
- 🔄 Enhanced network filtering
- 🔄 SELinux profiles (RHEL variant)
- 🔄 Hardware security key support (YubiKey)
- 🔄 Biometric authentication
- 🔄 Encrypted backup system

### Phase 3 (v1.2+)
- 📋 MicroVM-based workspaces (Firecracker)
- 📋 TPM 2.0 integration
- 📋 Secure Boot enforcement
- 📋 gVisor runtime option
- 📋 Zero-trust networking
- 📋 Advanced threat detection

---

## Security Contacts

### Reporting Security Issues

**Email**: security@nubiferos.org  
**PGP Key**: [Available on website]  
**Response Time**: 24-48 hours

### Security Advisories

**Location**: https://github.com/nubiferos/nubiferos/security/advisories  
**Notification**: GitHub Security Advisories  
**Frequency**: As needed

### Community

**Discord**: https://discord.gg/nubiferos  
**GitHub Discussions**: https://github.com/nubiferos/nubiferos/discussions  
**Security Channel**: #security on Discord

---

## Summary

NubiferOS provides **defense-in-depth security** through multiple layers:

1. **Encryption**: LUKS (disk) + GPG (credentials)
2. **Isolation**: Wayland (desktop) + Firejail (workspaces)
3. **Access Control**: AppArmor (kernel-level)
4. **Network**: Firewall + fail2ban
5. **Monitoring**: Audit logging
6. **Updates**: Automatic security patches
7. **Recovery**: Physical USB key (no backdoors)

**Security is not optional** - it's built into every layer of NubiferOS.

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: November 14, 2025  
**Security Level**: Enterprise-Grade

