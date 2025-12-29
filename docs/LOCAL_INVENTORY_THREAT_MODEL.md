# Local Cloud Inventory & Posture Subsystem Threat Model

This document defines the security boundaries and threat considerations specific to the **optional** Local Cloud Inventory & Posture Subsystem. This is a scoped threat model that supplements the main NubiferOS threat model.

## Scope

This threat model covers **only** the Local Cloud Inventory & Posture Subsystem when enabled. It does not replace the main NubiferOS threat model but provides additional analysis for this optional component.

## New Assets Introduced

### Primary Assets
1. **Local Cloud Metadata**
   - Resource inventories and relationships
   - Security posture snapshots
   - Configuration drift data
   - Risk analysis results

2. **Inventory Database**
   - PostgreSQL/SQLite database files
   - Database connection credentials (local only)
   - Indexed metadata for fast queries

3. **Collection Processes**
   - Collector service configurations
   - Sync schedules and timers
   - Process state and logs

### Secondary Assets
4. **Dashboard Data**
   - Risk scoring algorithms
   - Workspace comparisons
   - Historical trend data

## New Threats Introduced

### 1. Local Privilege Escalation via Collector
**Threat**: Compromised collector process attempts to escalate privileges
**Attack Vectors**:
- Exploit vulnerabilities in collector code
- Abuse cloud API response parsing
- Leverage systemd service misconfigurations

**Mitigations**:
- systemd hardening (NoNewPrivileges, ProtectSystem, ProtectHome)
- AppArmor profiles restricting file system access
- Least privilege execution (dedicated user account)
- Input validation on all cloud API responses

### 2. Malicious Local User Access
**Threat**: Unauthorized local user attempts to access inventory data
**Attack Vectors**:
- Direct database file access
- Process memory inspection
- Log file examination
- Dashboard UI access

**Mitigations**:
- Strict filesystem permissions (600/700)
- Database binding to 127.0.0.1/Unix socket only
- User-based access controls
- Encrypted storage via system LUKS

### 3. Compromised Collector Process
**Threat**: Collector process compromised by malicious cloud API responses
**Attack Vectors**:
- Malicious JSON/XML in cloud API responses
- Buffer overflow in parsing libraries
- Injection attacks via crafted resource names
- Denial of service via large responses

**Mitigations**:
- Input sanitization and validation
- Memory-safe parsing libraries
- Response size limits and timeouts
- Process isolation via systemd and AppArmor

### 4. Database Compromise
**Threat**: Local database accessed by unauthorized processes
**Attack Vectors**:
- SQL injection via compromised collector
- Direct file system access to database files
- Memory dumps containing database content
- Backup file exposure

**Mitigations**:
- Parameterized queries only (no dynamic SQL)
- Database file permissions (600)
- Process memory protection
- Secure backup procedures

## Trust Boundaries

### Subsystem Trust Boundary

**Trusted Components**:
- NubiferOS base system (from main threat model)
- Collector processes (when properly configured)
- Local database (when properly secured)
- Dashboard UI (local access only)

**Untrusted Components**:
- Cloud API responses and data
- Network traffic during collection
- User input to dashboard
- External analysis tools

**Boundary Controls**:
- Input validation on all cloud data
- Network isolation (no inbound listeners)
- User authentication for dashboard access
- Process isolation via systemd/AppArmor

## Explicit Threat Scope Limitations

### Out of Scope (Inherited from Main Threat Model)
- **Kernel compromise**: Cannot protect against kernel-level attacks
- **Malicious authorized users**: Cannot prevent intentional abuse by legitimate users
- **Hardware attacks**: No additional hardware-level protections
- **Network infrastructure**: Cannot control external network security

### Subsystem-Specific Limitations
- **Cloud provider compromise**: Cannot detect if cloud APIs return malicious data
- **Credential compromise**: Does not protect cloud credentials (handled by pass/GPG)
- **Real-time attacks**: Inventory is point-in-time, not real-time monitoring
- **Cross-system attacks**: Limited to single NubiferOS installation

## Risk Assessment

### High Risk (Actively Mitigated)
- Local privilege escalation via collector processes
- Unauthorized access to inventory database
- Malicious cloud API response handling
- Database file exposure

### Medium Risk (Partially Mitigated)
- Process memory inspection attacks
- Log file information disclosure
- Dashboard UI vulnerabilities
- Backup file security

### Low Risk (Accepted)
- Cloud provider data integrity
- Network-level attacks during collection
- Advanced persistent threats targeting metadata
- Social engineering for dashboard access

## Attack Scenarios

### Scenario 1: Malicious Cloud API Response
**Attack**: Cloud provider returns crafted response to exploit collector
**Mitigation**: Input validation + process isolation + AppArmor profiles
**Result**: Blast radius limited to collector process; cannot access credentials or escalate privileges

### Scenario 2: Local User Database Access
**Attack**: Unauthorized local user attempts to read inventory database
**Mitigation**: File permissions + database binding + user access controls
**Result**: Database files protected by filesystem permissions; no network access possible

### Scenario 3: Compromised Collector Process
**Attack**: Collector process compromised via parsing vulnerability
**Mitigation**: systemd hardening + AppArmor + least privilege execution
**Result**: Process confined to defined security profile; cannot access other system resources

### Scenario 4: Dashboard UI Exploitation
**Attack**: Malicious input to dashboard interface
**Mitigation**: Input sanitization + local-only access + user authentication
**Result**: Impact limited to dashboard functionality; no system-level access

## Security Assumptions

### Subsystem-Specific Assumptions
1. **Cloud API Integrity**: Cloud providers return data in good faith (malicious responses handled via input validation)
2. **Local System Security**: Base NubiferOS security measures are effective
3. **User Trustworthiness**: Authorized users do not intentionally abuse the system
4. **Network Security**: Basic network security measures protect collection traffic

### Operational Assumptions
1. **Proper Installation**: Subsystem installed and configured correctly
2. **Regular Updates**: Security updates applied to collector components
3. **Monitoring**: Users monitor system for unusual activity
4. **Data Retention**: Old data purged according to retention policy

## Blast Radius Analysis

### Maximum Impact if Fully Compromised
- **Local metadata exposure**: Inventory data visible to attacker
- **Resource enumeration**: Cloud resources and configurations revealed
- **Posture analysis**: Security posture information disclosed
- **Historical data**: Past snapshots and changes exposed

### What Remains Protected
- **Cloud credentials**: Still protected by pass/GPG (separate system)
- **Other workspaces**: Workspace isolation still effective
- **System integrity**: Base NubiferOS security unaffected
- **Network services**: No inbound listeners to exploit
- **Cloud resources**: No write access to cloud environments

## Mitigation Summary

### Process Security
- **systemd hardening**: NoNewPrivileges, ProtectSystem, ProtectHome, PrivateTmp
- **AppArmor profiles**: Restrict file system and network access
- **Least privilege**: Dedicated user accounts with minimal permissions
- **Process isolation**: Separate processes per cloud provider/workspace

### Data Security
- **Filesystem permissions**: 600/700 on all sensitive files
- **Database security**: Local binding only, parameterized queries
- **Encryption at rest**: System LUKS protects all stored data
- **Data retention**: Automatic purging of old snapshots

### Network Security
- **No inbound listeners**: All services local-only
- **Outbound only**: Collection traffic only, no incoming connections
- **Rate limiting**: Prevent API abuse and cost escalation
- **TLS verification**: Validate cloud provider certificates

### Access Control
- **User authentication**: Dashboard requires local user authentication
- **File permissions**: Strict access controls on all components
- **Process boundaries**: Clear separation between collection and analysis
- **Audit logging**: Track access to sensitive operations

## Compliance Considerations

### Data Protection
- **No PII storage**: Only technical metadata collected
- **Data minimization**: Collect only security-relevant information
- **Retention limits**: Automatic data purging after 30-90 days
- **Local processing**: No data transmitted to external services

### Security Standards
- **Defense in depth**: Multiple security layers
- **Least privilege**: Minimal permissions for all components
- **Secure by default**: Feature disabled unless explicitly enabled
- **Regular updates**: Security patches applied promptly

---

**Principle**: The subsystem provides valuable security insights while maintaining strict isolation and minimal attack surface expansion.

**Version**: 1.0 (Nimbus)  
**Last Updated**: December 26, 2025  
**Scope**: Local Cloud Inventory & Posture Subsystem Only