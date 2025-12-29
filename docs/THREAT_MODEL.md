# NubiferOS Threat Model

This document defines the security boundaries, threat mitigations, and explicit non-goals for NubiferOS as a cloud engineer workstation operating system. It establishes what threats are addressed, partially mitigated, or intentionally out of scope to provide clear expectations for users and security reviewers.

## User Persona

**Primary User**: Cloud Engineer / DevOps Professional

**Characteristics**:
- Manages multiple cloud accounts (AWS, Azure, GCP)
- Handles sensitive credentials and API keys daily
- Works with infrastructure as code (Terraform, Ansible)
- Requires secure credential management and isolation
- Uses workstation for cloud administration and development
- May work remotely or in shared office environments

**Use Cases**:
- Managing cloud infrastructure across multiple accounts
- Storing and using cloud credentials securely
- Preventing accidental cross-account operations
- Protecting credentials from malware and keyloggers
- Secure remote work with sensitive cloud access

## Assets to Protect

### Primary Assets
1. **Cloud Credentials**
   - AWS access keys, session tokens
   - Azure service principal credentials
   - GCP service account keys
   - API keys and tokens for cloud services

2. **Infrastructure Code**
   - Terraform state files
   - Ansible playbooks and inventories
   - Kubernetes configurations
   - CI/CD pipeline configurations

3. **Sensitive Data**
   - SSH private keys
   - Database connection strings
   - Application secrets and certificates
   - Customer data accessed through cloud services

### Secondary Assets
4. **System Access**
   - User authentication credentials
   - Sudo privileges
   - System configuration files

5. **Work Product**
   - Code repositories
   - Documentation
   - Configuration files

## In-Scope Adversaries

### 1. Opportunistic Attackers
**Motivation**: Financial gain, credential theft
**Capabilities**: Basic malware, phishing, social engineering
**Attack Vectors**:
- Malicious downloads and email attachments
- Credential harvesting malware
- Keyloggers and screen capture tools
- Browser-based attacks

### 2. Insider Threats (Intentional Malicious Actions)
**Motivation**: Financial gain, revenge, espionage
**Capabilities**: Physical access, legitimate system access
**Attack Vectors**:
- Physical device theft
- Unauthorized credential access
- Privilege escalation
- Intentional data exfiltration

### 3. Targeted Attackers
**Motivation**: Espionage, competitive advantage
**Capabilities**: Advanced persistent threats, custom malware
**Attack Vectors**:
- Spear phishing and social engineering
- Zero-day exploits
- Supply chain attacks
- Advanced malware and rootkits

### 5. Human Error and Operator Mistakes
**Motivation**: Accidental self-harm, operational confusion
**Capabilities**: Legitimate system access, authorized credentials
**Attack Vectors**:
- Wrong cloud account selection
- Commands executed in wrong terminal/workspace
- Operations in wrong AWS region or environment
- Accidental deletion or modification of resources
- Credential confusion between accounts

**Mitigations Provided**:
- Workspace isolation and context indicators
- Separate command histories per workspace
- Read-only mode for production workspaces
- Visual workspace identification
### 4. Physical Attackers
**Motivation**: Data theft, system compromise
**Capabilities**: Physical device access
**Attack Vectors**:
- Device theft or loss
- Unattended workstation access
- Cold boot attacks
- Hardware tampering

## Trust Boundaries

### Pre-Install Trust Boundary

**Trusted Components**:
- NubiferOS installer ISO (when properly verified)
- UEFI/BIOS firmware (assumed trusted)
- Hardware platform (assumed trusted)

**Untrusted Components**:
- Network infrastructure during installation
- Installation media if not properly verified
- Any existing data on target disk

**Key Security Notes**:
- Production NubiferOS ISOs are installer-only (not general-purpose live environments)
- The pre-install environment must never be treated as a trusted OS for credentials or sensitive data

**Threats Mitigated**:
- Installer ISO tampering (mitigated when ISO/signatures/checksums are verified by the user)
- Installation to wrong disk (via Calamares UI)

**Threats NOT Mitigated**:
- Compromised installation media
- UEFI/BIOS firmware attacks
- Hardware-level attacks
- Network-based attacks during installation

**Note**: Pre-install environment should not be used for entering credentials or sensitive data.

### Post-Install Trust Boundary

**Trusted Components**:
- NubiferOS kernel and system components
- LUKS encryption layer
- GPG/pass credential storage
- AppArmor and Firejail sandboxing
- Wayland display server

**Untrusted Components**:
- User applications and data
- Network traffic and remote services
- USB devices and external media
- Browser content and downloads

**Threats Mitigated**:
- Application-level credential theft
- Cross-workspace credential leakage
- Keylogging and screen capture
- Privilege escalation attacks
- Network-based intrusions

**Threats NOT Mitigated**:
- Kernel-level exploits
- Hardware-level attacks
- Social engineering
- Compromised cloud accounts

## Explicit Out-of-Scope Threats

### 1. Hardware-Level Attacks
**Rationale**: NubiferOS cannot fully eliminate hardware-level threats. Software alone cannot comprehensively defend against hardware attacks, though some mitigations exist with performance trade-offs.

**Examples**:
- CPU side-channel attacks (Spectre, Meltdown variants)
- Hardware keyloggers and implants
- DMA attacks via Thunderbolt/PCIe
- Cold boot attacks on RAM
- Hardware tampering and modification

**Partial Mitigations Provided**:
- Basic CPU mitigations enabled by default
- Configurable enhanced mitigations available
- Performance impact warnings and user choice

### 2. Nation-State Actors
**Rationale**: Defending against nation-state actors requires specialized security measures beyond the scope of a general-purpose cloud workstation OS.

**Examples**:
- Advanced persistent threats with unlimited resources
- Hardware supply chain attacks
- Sophisticated zero-day exploit chains
- Targeted surveillance and monitoring

### 3. Firmware and UEFI Attacks
**Rationale**: Firmware security requires hardware vendor cooperation and specialized tools.

**Examples**:
- UEFI rootkits and bootkits
- Firmware-level persistence
- Secure Boot bypass attacks
- TPM attacks and manipulation

### 4. Social Engineering
**Rationale**: Human factors are outside the technical scope of the operating system.

**Examples**:
- Phishing attacks targeting credentials
- Pretexting and impersonation
- Physical social engineering
- Insider recruitment and coercion

### 5. Cloud Provider Security
**Rationale**: Cloud infrastructure security is the responsibility of cloud providers. Cloud provider compromise is accepted as a risk at the workstation level.

**Examples**:
- AWS/Azure/GCP infrastructure vulnerabilities
- Cloud provider insider threats
- Data center physical security
- Cloud service availability and integrity

### 6. Network Infrastructure
**Rationale**: NubiferOS cannot control network infrastructure but reduces endpoint exposure through security measures.

**Examples**:
- Man-in-the-middle attacks on network traffic
- DNS poisoning and BGP hijacking
- ISP-level surveillance and interception
- Network infrastructure compromise

**Endpoint Protections Provided**:
- HTTPS-only browser configuration
- Firewall with deny-by-default policy
- DNS hardening where implemented
- VPN guidance and compatibility

### 7. Application-Level Vulnerabilities
**Rationale**: NubiferOS does not guarantee third-party application security but uses sandboxing and mandatory access controls to reduce blast radius.

**Examples**:
- Vulnerabilities in cloud CLIs (aws, az, gcloud)
- Browser vulnerabilities and exploits
- IDE and development tool vulnerabilities
- Third-party application malware

**Blast Radius Reduction**:
- AppArmor mandatory access control profiles
- Firejail application sandboxing
- Workspace isolation limiting credential access
- Wayland display server isolation

### 8. Compliance and Regulatory Requirements
**Rationale**: Compliance is a business and legal concern, not a technical security feature.

**Examples**:
- GDPR, HIPAA, SOX compliance requirements
- Industry-specific security standards
- Audit and reporting requirements
- Legal and regulatory obligations

## Attack Scenarios Addressed

### Scenario 1: Malware Credential Theft
**Attack**: Malware attempts to steal cloud credentials
**Mitigation**: GPG encryption + Wayland isolation + AppArmor profiles
**Result**: Credentials at rest remain encrypted; runtime theft risk reduced via isolation and confinement. A fully compromised user session can still expose credentials during active use.

### Scenario 2: Cross-Account Credential Confusion
**Attack**: User accidentally uses wrong cloud account credentials
**Mitigation**: Firejail workspace isolation
**Result**: Blast radius limited to single workspace; accidental cross-account operations prevented through isolation

### Scenario 3: Physical Device Theft
**Attack**: Laptop stolen with sensitive data
**Mitigation**: LUKS full disk encryption
**Result**: Data at rest remains encrypted and inaccessible without passphrase; running system memory may still contain sensitive data

### Scenario 4: Keylogger Attack
**Attack**: Malicious application attempts to capture keystrokes
**Mitigation**: Wayland display server isolation
**Result**: Risk reduced through application isolation; kernel-level keyloggers or compromised display server may still succeed

### Scenario 5: Privilege Escalation
**Attack**: Compromised application attempts to gain root access
**Mitigation**: AppArmor mandatory access control
**Result**: Blast radius limited by security profiles; kernel exploits or misconfigurations may still allow escalation

## Risk Assessment

### High Risk (Actively Mitigated)
- Credential theft and exposure
- Cross-account operational mistakes
- Physical device compromise
- Application-level attacks

### Medium Risk (Partially Mitigated)
- Network-based attacks (firewall protection)
- System-level exploits (kernel hardening)
- Brute force attacks (fail2ban protection)

### Low Risk (Accepted)
- Hardware-level attacks
- Nation-state threats
- Social engineering
- Cloud provider compromise

## Assumptions

### Security Assumptions
1. **Hardware Integrity**: The underlying hardware platform is trusted
2. **Firmware Trust**: UEFI/BIOS firmware is not compromised
3. **Secure Boot**: Secure Boot is supported and recommended where available, but not universally assumed or enforced
4. **Installation Integrity**: The NubiferOS ISO is properly verified
5. **User Competence**: Users follow basic security practices
6. **Update Availability**: Security updates are available and applied

### Operational Assumptions
1. **Physical Security**: Workstations are used in reasonably secure environments
2. **Network Security**: Basic network security measures are in place
3. **Backup Strategy**: Users maintain appropriate backup procedures
4. **Recovery Planning**: Recovery keys are stored securely
5. **Incident Response**: Users can respond appropriately to security incidents

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: December 26, 2025  
**Scope**: Cloud engineer workstation security