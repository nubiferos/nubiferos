# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in NubiferOS, please report it responsibly.

### How to Report

**Email**: security@nubiferos.org

**Include**:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity (critical: days, high: weeks, medium/low: next release)

### Scope

**In Scope**:
- NubiferOS ISO build process
- Pre-installed components and configurations
- Credential management system
- Workspace isolation mechanisms
- Security hardening configurations

**Out of Scope**:
- Third-party cloud CLI tools (aws, az, gcloud) - report to respective vendors
- Upstream Debian packages - report to Debian Security Team
- Cloud provider vulnerabilities - report to AWS/Azure/GCP

### Disclosure Policy

- We follow coordinated disclosure
- We'll work with you on timing
- Credit given to reporters (unless anonymity requested)

## Security Documentation

For detailed security information, see:

- [Threat Model](docs/THREAT_MODEL.md) - Security boundaries and mitigations
- [Security Summary](docs/SECURITY_SUMMARY.md) - Overview of security features
- [Credential Security](docs/CREDENTIAL_SECURITY.md) - How credentials are protected
- [Security Non-Goals](docs/SECURITY_NON_GOALS.md) - What we explicitly don't protect against

## Security Features

NubiferOS includes:

- **Full Disk Encryption** - LUKS mandatory during installation
- **Credential Protection** - GPG-encrypted storage via `pass`
- **Workspace Isolation** - Firejail sandboxing per cloud account
- **Build Security** - SBOM, vulnerability scanning, GPG-signed releases
- **System Hardening** - AppArmor, firewall, Wayland isolation

## Verifying Releases

All releases are GPG-signed. To verify:

```bash
# Import signing key
gpg --import nubiferos-signing-key.pub

# Verify ISO signature
gpg --verify nubiferos-*.iso.asc nubiferos-*.iso

# Verify checksum
sha256sum -c SHA256SUMS
```

The signing key is available at:
- GitHub Releases
- https://nubiferos.org/security/signing-key.pub
