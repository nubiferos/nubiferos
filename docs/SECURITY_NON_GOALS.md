# NubiferOS Security Non-Goals

This document explicitly defines what NubiferOS does **NOT** attempt to protect against. These are intentional scope boundaries, not security failures.

## Purpose

Security systems must have clear boundaries. Attempting to protect against every possible threat leads to:
- Unrealistic security claims
- User confusion about actual protections
- Wasted resources on unsolvable problems
- False sense of security

NubiferOS focuses on **cloud engineer workstation security** within well-defined boundaries.

---

## Hardware-Level Threats

### ❌ CPU Side-Channel Attacks
**What we don't fully protect against**:
- Advanced Spectre/Meltdown variants
- Cache timing attacks
- Branch prediction attacks
- Microarchitectural data sampling

**Why this is limited scope**:
- NubiferOS applies available CPU mitigations but cannot fully eliminate hardware-level risks
- Performance impact often unacceptable for full protection
- Constantly evolving threat landscape
- Limited effectiveness of software-only solutions

**What we do instead**:
- Enable basic CPU mitigations where practical
- Document RETBleed warnings and trade-offs
- Provide tools to enable full mitigations if needed

### ❌ Hardware Implants and Tampering
**What we don't protect against**:
- Hardware keyloggers
- Modified firmware chips
- Supply chain hardware attacks
- Physical device modification

**Why this is out of scope**:
- Cannot be detected or prevented by software
- Requires specialized hardware security measures
- Outside the control of the operating system
- Extremely rare for typical cloud engineers

### ❌ DMA and Bus Attacks
**What we don't guarantee protection against**:
- Thunderbolt DMA attacks
- PCIe device attacks
- FireWire attacks
- USB device attacks (beyond basic precautions)

**Why this is limited scope**:
- Platform-specific mitigations (IOMMU, etc.) may exist but are not guaranteed
- May conflict with legitimate device usage
- Hardware-dependent protections outside OS control

---

## Nation-State and Advanced Persistent Threats

### ❌ Targeted Nation-State Attacks
**What we don't protect against**:
- Custom zero-day exploit chains
- Advanced persistent threats with unlimited resources
- Targeted surveillance and monitoring
- State-sponsored cyber warfare

**Why this is out of scope**:
- Requires specialized security measures beyond general-purpose OS
- Constantly evolving and highly sophisticated threats
- May require air-gapped systems and specialized procedures
- Not the primary threat model for typical cloud engineers

### ❌ Supply Chain Attacks on Dependencies
**What we don't protect against**:
- Compromised upstream packages
- Malicious code in dependencies
- Build system compromise
- Repository poisoning attacks

**Why this is out of scope**:
- Requires ecosystem-wide solutions
- Cannot be solved at the OS level alone
- Depends on upstream security practices
- Would require extensive code auditing of all packages

---

## Social Engineering and Human Factors

### ❌ Phishing and Social Engineering
**What we don't protect against**:
- Email phishing attacks
- Phone-based social engineering
- Pretexting and impersonation
- Physical social engineering

**Why this is out of scope**:
- Human behavior cannot be controlled by software
- Requires education and awareness training
- Context-dependent and highly variable
- Outside the technical scope of an operating system

### ❌ Insider Threats with Legitimate Access
**What we don't protect against**:
- Authorized users intentionally misusing their access
- Credential sharing between users
- Intentional data exfiltration by legitimate users
- Abuse of administrative privileges

**Why this is out of scope**:
- Cannot distinguish between legitimate and malicious use by authorized users
- Requires organizational policies and procedures
- May conflict with legitimate user workflows
- Needs business-level controls, not technical ones

**What we do provide**:
- Workspace isolation to prevent accidental cross-account operations
- Context indicators to reduce operator errors
- Audit logging to track user actions
- These measures mitigate accidental misuse but do not prevent deliberate abuse

---

## Network and Infrastructure Security

### ❌ Network Infrastructure Attacks
**What we don't protect against**:
- BGP hijacking and route manipulation
- DNS poisoning and cache attacks
- ISP-level surveillance and interception
- Network infrastructure compromise

**Why this is out of scope**:
- Outside the control of endpoint systems
- Requires network-level security measures
- Cannot be solved by individual workstations
- Depends on external infrastructure providers

### ❌ Cloud Provider Security
**What we don't protect against**:
- AWS/Azure/GCP infrastructure vulnerabilities
- Cloud provider insider threats
- Data center physical security breaches
- Cloud service availability and integrity issues

**Why this is out of scope**:
- Cloud infrastructure security is provider responsibility
- Cannot be controlled from client systems
- Requires trust in cloud provider security measures
- Outside the scope of workstation security

---

## Application and Software Security

### ❌ Third-Party Application Vulnerabilities
**What we don't guarantee**:
- The absence of vulnerabilities in cloud CLIs (aws, az, gcloud)
- Browser security vulnerabilities
- IDE and development tool exploits
- Third-party application malware

**Why this is out of scope**:
- NubiferOS does not audit or guarantee the security of upstream software
- Cannot control third-party software security practices
- Would require extensive code auditing of all packages
- Users need flexibility to install required tools

**What we do provide**:
- AppArmor profiles to reduce blast radius of compromised applications
- Firejail sandboxing to limit application access
- Wayland isolation to prevent cross-application attacks
- These measures reduce impact but do not eliminate third-party risks

### ❌ Web Application and Service Security
**What we don't protect against**:
- Vulnerabilities in web applications accessed via browser
- API security issues in cloud services
- Cross-site scripting and injection attacks
- Web service authentication bypasses

**Why this is out of scope**:
- Cannot control external web application security
- Browser security is a separate concern
- Requires application-level security measures
- Outside the scope of workstation protection

---

## Compliance and Regulatory Requirements

### ❌ Specific Compliance Standards
**What we don't protect against**:
- GDPR compliance violations
- HIPAA compliance requirements
- SOX audit requirements
- Industry-specific regulatory compliance

**Why this is out of scope**:
- Compliance is a business and legal concern, not a technical one
- Requirements vary by organization and jurisdiction
- Cannot be solved by technology alone
- Requires organizational policies and procedures

### ❌ Audit and Reporting Requirements
**What we don't protect against**:
- Automated compliance reporting
- Audit trail formatting for specific standards
- Legal discovery and e-discovery requirements
- Regulatory reporting obligations

**Why this is out of scope**:
- Highly organization-specific requirements
- Requires business process integration
- Cannot be generalized across all users
- Outside the scope of workstation security

---

## Availability and Business Continuity

### ❌ Denial of Service Attacks
**What we don't protect against**:
- Distributed denial of service (DDoS) attacks
- Resource exhaustion attacks
- Network flooding attacks
- Application-level DoS attacks

**Why this is out of scope**:
- Primarily a network and infrastructure concern
- Cannot be solved at the workstation level
- Requires upstream filtering and protection
- May conflict with legitimate high-resource usage

### ❌ Business Continuity and Disaster Recovery
**What we don't protect against**:
- Natural disasters and physical destruction
- Long-term system unavailability
- Data center outages and failures
- Business process continuity

**Why this is out of scope**:
- Requires organizational planning and procedures
- Cannot be solved by individual workstation security
- Needs redundant systems and processes
- Outside the scope of endpoint protection

---

## Data Protection Limitations

### ❌ Data Loss Prevention (DLP)
**What we don't protect against**:
- Intentional data exfiltration by authorized users
- Accidental data sharing and exposure
- Data classification and labeling enforcement
- Content-based data protection

**Why this is out of scope**:
- Requires deep content inspection that may break functionality
- Highly organization-specific requirements
- May conflict with legitimate data usage
- Needs business-level policies and procedures

### ❌ Backup and Recovery Guarantees
**What we don't protect against**:
- Data loss due to hardware failure
- Corruption of backup data
- Ransomware affecting backup systems
- Long-term data preservation

**Why this is out of scope**:
- Backup strategy is user responsibility
- Cannot guarantee external backup system security
- Requires redundant storage and testing procedures
- Outside the scope of workstation protection

---

## Performance and Usability Trade-offs

### ❌ Zero Performance Impact Security
**What we don't accept**:
- Security measures that have no performance impact
- Transparent security that users never notice
- Security that doesn't require any user behavior changes

**Why this is realistic**:
- Effective security often requires trade-offs
- Users must understand and participate in security
- Some performance impact is acceptable for security benefits
- Transparency can hide security failures

### ❌ Perfect Usability
**What we don't guarantee**:
- Security measures that never interfere with workflows
- Compatibility with all possible software and hardware
- Zero learning curve for security features
- No additional steps or procedures for users

**Why this is realistic**:
- Security and usability often conflict
- Some user education and adaptation is necessary
- Perfect compatibility may compromise security
- Users must participate in their own security

---

## Scope Boundaries Summary

### ✅ What NubiferOS DOES Protect
- Cloud credentials from application-level theft
- Cross-workspace credential isolation
- Data at rest via full disk encryption
- Desktop isolation via Wayland
- Basic network intrusion prevention
- System integrity via mandatory access controls

### ❌ What NubiferOS Does NOT Protect
- Hardware-level attacks and side channels
- Nation-state and advanced persistent threats
- Social engineering and human factors
- Network infrastructure security
- Third-party application vulnerabilities
- Compliance and regulatory requirements
- Business continuity and disaster recovery

### 🎯 Our Focus
NubiferOS focuses on **cloud engineer workstation security** within realistic and achievable boundaries. We provide strong protection against common threats while being honest about our limitations.

---

**Principle**: It is better to provide strong protection against realistic threats than weak protection against all possible threats.

**Version**: 1.0 (Nimbus)  
**Last Updated**: December 26, 2025  
**Scope**: Intentional security boundaries