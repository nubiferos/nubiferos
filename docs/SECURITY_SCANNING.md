# NubiferOS Security Scanning

This document describes the security scanning capabilities built into NubiferOS.

## Overview

NubiferOS includes comprehensive security scanning at multiple levels:

1. **Build-time scanning** - Automated scans during ISO creation
2. **CI/CD scanning** - GitHub Actions workflow for continuous security
3. **Local scanning** - On-demand scans on installed systems

## Build-Time Security

During ISO builds, the following security checks are performed:

### Software Bill of Materials (SBOM)

Every ISO build generates an SBOM in both CycloneDX and SPDX formats:
- Lists all packages and their versions
- Enables supply chain transparency
- Required for compliance frameworks

### Vulnerability Scanning

The ISO is scanned for known vulnerabilities using Grype:
- Scans against NVD and other vulnerability databases
- Reports Critical, High, Medium, and Low severity issues
- Results uploaded to S3 alongside the ISO

### ISO Signing

Release ISOs are cryptographically signed:
- GPG detached signature (.asc file)
- Public key available for verification
- Ensures ISO integrity and authenticity

## CI/CD Security Workflow

The `security-scan.yml` workflow runs on every push and PR:

### Repository Scanning
- **Secret detection** - Gitleaks scans for leaked credentials
- **Code analysis** - ShellCheck validates shell scripts
- **Dependency audit** - Checks for vulnerable dependencies

### ISO Scanning (Manual Trigger)
- Download ISO from S3
- Generate SBOM
- Run vulnerability scan
- Post results to PR comments

## Local Security Scanner

The `nubifer-security-scan` command provides on-demand security scanning:

```bash
# Run vulnerability scan
nubifer-security-scan --vuln-scan

# Run compliance/hardening check
nubifer-security-scan --compliance

# Verify ISO signature
nubifer-security-scan --verify-iso /path/to/nubiferos.iso

# Run all scans
nubifer-security-scan --full

# Output as JSON (for automation)
nubifer-security-scan --full --json

# Quiet mode (errors only)
nubifer-security-scan --full --quiet
```

### Vulnerability Scan

Uses Grype to scan the system for known vulnerabilities:
- Scans installed packages
- Reports by severity level
- Saves results to `~/.local/share/nubifer/security/vuln-scan.json`

### Compliance Check

Uses Lynis to audit system hardening:
- Checks security configurations
- Reports hardening score (0-100)
- Lists warnings and suggestions
- Saves results to `~/.local/share/nubifer/security/compliance.json`

### ISO Verification

Verifies the GPG signature of downloaded ISOs:
- Imports NubiferOS public key
- Validates detached signature
- Confirms ISO integrity

## Verifying Downloaded ISOs

Always verify ISOs before installation:

```bash
# Download the ISO and signature
wget https://<your-bucket-name>.s3.amazonaws.com/nubiferos-latest.iso
wget https://<your-bucket-name>.s3.amazonaws.com/nubiferos-latest.iso.asc

# Download and import the public key
wget https://<your-bucket-name>.s3.amazonaws.com/nubiferos-signing-key.pub
gpg --import nubiferos-signing-key.pub

# Verify the signature
gpg --verify nubiferos-latest.iso.asc nubiferos-latest.iso
```

Expected output for valid signature:
```
gpg: Signature made [date]
gpg: Good signature from "NubiferOS Release Signing Key"
```

## Security Dashboard Integration

The Security Dashboard (`nubifer-dashboard`) displays:
- Overall security score
- Encryption status
- Firewall status
- AppArmor status
- Recent scan results

Scan results from `nubifer-security-scan` are automatically picked up by the dashboard.

## Vulnerability Allowlist

Some vulnerabilities may be accepted risks. The allowlist is at:
`security/vuln-allowlist.yaml`

Format:
```yaml
allowlist:
  - id: CVE-2024-XXXXX
    reason: "Not exploitable in our configuration"
    expires: "2025-01-01"
```

## GPG Key Management

### For Maintainers

The release signing key should be:
1. Generated with RSA 4096-bit
2. Stored securely (not in repository)
3. Added to GitHub Secrets as `GPG_PRIVATE_KEY`
4. Passphrase stored as `GPG_PASSPHRASE`

### Key Rotation

When rotating keys:
1. Generate new key
2. Update GitHub Secrets
3. Update public key in repository
4. Announce key change to users

## Compliance Frameworks

NubiferOS security scanning supports:
- CIS Benchmarks (via Lynis)
- NIST guidelines
- SOC 2 requirements (SBOM generation)

## Troubleshooting

### Scan takes too long
- Use `--quiet` mode for faster output
- Check network connectivity for vulnerability database updates

### Missing tools
- Tools are auto-installed on first use
- Requires sudo for installation

### False positives
- Add to allowlist with justification
- Report to upstream if applicable
