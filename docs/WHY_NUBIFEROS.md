# Why NubiferOS?

**The only Linux distribution built specifically for cloud engineers, with security you can verify.**

## The Problem

Cloud engineers handle some of the most sensitive credentials in any organization:
- AWS root account access
- Production database passwords
- Kubernetes cluster admin tokens
- CI/CD pipeline secrets

Yet most work on general-purpose operating systems that weren't designed for this threat model.

## What Makes NubiferOS Different

### 1. Purpose-Built for Cloud Work

| Feature | Ubuntu/Fedora | macOS | NubiferOS |
|---------|---------------|-------|-----------|
| Cloud CLIs pre-installed | ❌ Manual | ❌ Manual | ✅ AWS, Azure, GCP, OCI |
| Credential isolation | ❌ None | ❌ None | ✅ Per-workspace sandboxing |
| Multi-account safety | ❌ Easy mistakes | ❌ Easy mistakes | ✅ Visual context + isolation |
| IaC tools ready | ❌ Manual | ❌ Manual | ✅ Terraform, Ansible, kubectl |

### 2. Published Threat Model

We tell you exactly what we protect against—and what we don't.

Most operating systems make vague security claims. We publish our [complete threat model](THREAT_MODEL.md) so you can:
- Understand our security boundaries
- Make informed decisions about your use case
- Verify our claims against your requirements

**Transparency builds trust.**

### 3. Verifiable Security

Every release includes artifacts you can verify:

| Artifact | Purpose | How to Verify |
|----------|---------|---------------|
| GPG Signature | ISO hasn't been tampered with | `gpg --verify nubiferos.iso.sig` |
| SHA256 Checksum | Download integrity | `sha256sum -c SHA256SUMS` |
| SBOM (CycloneDX) | Complete component inventory | Machine-readable JSON |
| Vulnerability Report | Known CVEs in this release | Grype scan results |
| Hardening Score | Security configuration audit | Lynis audit report |

**No other desktop Linux publishes this level of verification.**

### 4. Credential-First Security

Credentials are the crown jewels. We protect them at every layer:

```
┌─────────────────────────────────────────────────────┐
│  Workspace Isolation (Firejail)                     │
│  - Each cloud account in its own sandbox            │
│  - Credentials invisible to other workspaces        │
├─────────────────────────────────────────────────────┤
│  Encrypted Storage (GPG + pass)                     │
│  - No plaintext credentials on disk                 │
│  - No environment variable exposure                 │
├─────────────────────────────────────────────────────┤
│  Display Isolation (Wayland)                        │
│  - No keylogging between applications               │
│  - No screen capture without permission             │
├─────────────────────────────────────────────────────┤
│  Full Disk Encryption (LUKS)                        │
│  - Mandatory, not optional                          │
│  - Data protected if device is stolen               │
└─────────────────────────────────────────────────────┘
```

### 5. Defense in Depth

Eight security layers, not just one:

1. **LUKS Encryption** - Data at rest protection
2. **CPU Mitigations** - Spectre/Meltdown protection
3. **Kernel Hardening** - Reduced attack surface
4. **AppArmor** - Mandatory access control
5. **Wayland** - Display server isolation
6. **GPG/pass** - Credential encryption
7. **Firejail** - Application sandboxing
8. **Audit Logging** - Security monitoring

### 6. No Credential Leakage by Design

**We never do this:**
```bash
# FORBIDDEN in NubiferOS
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
```

**We always do this:**
```bash
# Credentials pulled on-demand, never in environment
aws s3 ls  # Wrapper fetches from encrypted store
```

Environment variables are visible in `/proc`, logs, and crash dumps. We don't use them for credentials. Ever.

## Comparison: NubiferOS vs. Alternatives

### vs. Ubuntu/Fedora

| Aspect | Ubuntu/Fedora | NubiferOS |
|--------|---------------|-----------|
| Target user | General purpose | Cloud engineers |
| Encryption | Optional | Mandatory |
| Credential management | DIY | Built-in |
| Cloud tools | Install yourself | Pre-configured |
| Workspace isolation | None | Firejail sandboxes |
| Threat model | Not published | [Published](THREAT_MODEL.md) |

### vs. macOS

| Aspect | macOS | NubiferOS |
|--------|-------|-----------|
| Open source | ❌ Proprietary | ✅ GPL-3.0 |
| Credential isolation | ❌ Keychain only | ✅ Per-workspace |
| Display isolation | ❌ Apps can keylog | ✅ Wayland |
| Verifiable builds | ❌ Trust Apple | ✅ SBOM + signatures |
| Cloud-native tools | ❌ Homebrew | ✅ Native packages |

### vs. Tails/Whonix

| Aspect | Tails/Whonix | NubiferOS |
|--------|--------------|-----------|
| Use case | Anonymity | Cloud work |
| Persistence | Limited/None | Full workstation |
| Cloud CLI support | ❌ Not designed for | ✅ Primary focus |
| Credential management | ❌ Ephemeral | ✅ Encrypted vault |
| Daily driver | ❌ Specialized | ✅ Yes |

### vs. Qubes OS

| Aspect | Qubes OS | NubiferOS |
|--------|----------|-----------|
| Isolation model | VMs (Xen) | Containers (Firejail) |
| Resource usage | High (multiple VMs) | Low (single kernel) |
| Hardware support | Limited | Standard Linux |
| Learning curve | Steep | Familiar Linux |
| Cloud tool integration | DIY | Built-in |

## Who Should Use NubiferOS

**Ideal for:**
- Cloud engineers managing multiple AWS/Azure/GCP accounts
- DevOps professionals handling production credentials
- Platform engineers working with Kubernetes clusters
- Security-conscious developers who want defense in depth
- Teams that need verifiable, auditable workstations

**Not designed for:**
- Anonymous browsing (use Tails)
- Maximum isolation at any cost (use Qubes)
- Gaming or multimedia production
- Users who need Windows applications

## Getting Started

1. **Download** - Get the ISO from [nubiferos.org](https://nubiferos.org)
2. **Verify** - Check GPG signature and SHA256 checksum
3. **Install** - Boot from USB, run installer
4. **Configure** - Set up your cloud workspaces
5. **Work securely** - Your credentials are protected

## Learn More

- [Threat Model](THREAT_MODEL.md) - What we protect against
- [Security Summary](SECURITY_SUMMARY.md) - All security features
- [Credential Security](CREDENTIAL_SECURITY.md) - How credentials are protected
- [Design Decisions](DESIGN_DECISIONS.md) - Why we made key choices
- [Quickstart Guide](QUICKSTART.md) - Get up and running

---

**NubiferOS**: Security you can verify. Built for cloud engineers.

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: January 31, 2026
