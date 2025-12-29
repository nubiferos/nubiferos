# Security Dashboard Concept

## Visual Mockup (Text-based)

```
┌─────────────────────────────────────────────────────────────┐
│  NubiferOS Security Dashboard                    [_][□][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                                                       │   │
│   │              Security Score: 85                       │   │
│   │                                                       │   │
│   │         ████████████████████░░░░░░░░░░░░░░           │   │
│   │                                                       │   │
│   │              ⚠️  Caution Level                        │   │
│   │                                                       │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                               │
│   ┌──────────────────────┐  ┌──────────────────────┐        │
│   │  CPU Security        │  │  Credentials         │        │
│   │  ⚠️  Partial         │  │  ✓ Protected         │        │
│   │                      │  │                      │        │
│   │  • Spectre v2: ✓     │  │  42 passwords        │        │
│   │  • RETBleed: ⚠️      │  │  15 SSH keys         │        │
│   │  • Meltdown: ✓       │  │  8 API tokens        │        │
│   │                      │  │                      │        │
│   │  [Configure...]      │  │  [Manage...]         │        │
│   └──────────────────────┘  └──────────────────────┘        │
│                                                               │
│   ┌──────────────────────┐  ┌──────────────────────┐        │
│   │  Network Exposure    │  │  System Hardening    │        │
│   │  ✓ Secure            │  │  ✓ Enabled           │        │
│   │                      │  │                      │        │
│   │  Firewall: Active    │  │  • AppArmor: ✓       │        │
│   │  Open Ports: 0       │  │  • Encryption: ✓     │        │
│   │  SSH: Disabled       │  │  • Kernel: ✓         │        │
│   │                      │  │                      │        │
│   │  [Details...]        │  │  [Configure...]      │        │
│   └──────────────────────┘  └──────────────────────┘        │
│                                                               │
│   ┌─────────────────────────────────────────────────────┐   │
│   │  Recent Security Events                             │   │
│   │                                                       │   │
│   │  • 2 hours ago: RETBleed vulnerability detected      │   │
│   │  • 1 day ago: 3 new credentials added                │   │
│   │  • 2 days ago: System hardening applied              │   │
│   │                                                       │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                               │
│                    [Refresh]  [Settings]  [Help]             │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Notification Examples

### CPU Vulnerability Notification
```
┌─────────────────────────────────────────┐
│  ⚠️  Security Alert                     │
├─────────────────────────────────────────┤
│  CPU Vulnerability Detected             │
│                                         │
│  Your CPU is vulnerable to RETBleed     │
│  attacks. Click to review mitigation    │
│  options.                               │
│                                         │
│  [Dismiss]  [View Details]              │
└─────────────────────────────────────────┘
```

### Firewall Inactive Notification
```
┌─────────────────────────────────────────┐
│  🔴 Critical Security Issue             │
├─────────────────────────────────────────┤
│  Firewall Inactive                      │
│                                         │
│  Your firewall has been disabled.       │
│  Your system may be exposed to          │
│  network attacks.                       │
│                                         │
│  [Enable Firewall]  [Dismiss]           │
└─────────────────────────────────────────┘
```

## Detailed View Examples

### CPU Security Detail View
```
┌─────────────────────────────────────────────────────────────┐
│  CPU Security Status                              [Back][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Processor: Intel Core i7-8550U                              │
│  Architecture: x86_64                                         │
│                                                               │
│  Vulnerability Status:                                        │
│                                                               │
│  ✓ Spectre v1                                                │
│    Status: Mitigation: usercopy/swapgs barriers              │
│    Performance Impact: ~5%                                    │
│                                                               │
│  ✓ Spectre v2                                                │
│    Status: Mitigation: Full generic retpoline                │
│    Performance Impact: ~10%                                   │
│                                                               │
│  ⚠️ RETBleed                                                  │
│    Status: Vulnerable                                         │
│    Risk: Low (requires local code execution)                 │
│    Mitigation Available: Yes (15-30% performance cost)        │
│                                                               │
│    [Enable Full Mitigation]  [Learn More]  [Dismiss]         │
│                                                               │
│  ✓ Meltdown                                                  │
│    Status: Mitigation: PTI                                    │
│    Performance Impact: ~5%                                    │
│                                                               │
│  ✓ MDS                                                       │
│    Status: Mitigation: Clear CPU buffers                     │
│    Performance Impact: ~3%                                    │
│                                                               │
│  [Run Full Diagnostic]  [View Documentation]                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Network Exposure Detail View
```
┌─────────────────────────────────────────────────────────────┐
│  Network Exposure Status                          [Back][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Firewall Status: ✓ Active (ufw)                            │
│  Default Policy: Deny incoming, Allow outgoing               │
│                                                               │
│  Open Ports: None                                            │
│                                                               │
│  Listening Services:                                          │
│  • None detected                                             │
│                                                               │
│  Recent Blocked Connections:                                  │
│  • 192.168.1.105:54321 → 22/tcp (SSH) - Blocked             │
│  • 10.0.0.45:12345 → 80/tcp (HTTP) - Blocked                │
│                                                               │
│  Network Interfaces:                                          │
│  • eth0: 192.168.1.100 (Private)                            │
│  • wlan0: Not connected                                      │
│                                                               │
│  [Configure Firewall]  [View Logs]  [Scan Ports]            │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Frontend
- **GTK 4** - GNOME's native UI toolkit
- **Python 3** - Main application language
- **PyGObject** - Python bindings for GTK

### Backend Checks
- **Bash scripts** - Reuse existing diagnostic scripts
- **Python modules** - Extensible check system
- **D-Bus** - System integration and notifications

### Data Sources
- `/sys/devices/system/cpu/vulnerabilities/` - CPU status
- `pass` command - Credential count
- `ufw status` - Firewall status
- `ss -tulpn` - Open ports
- `aa-status` - AppArmor status
- `lsblk` - Disk encryption status

## Security Score Calculation

```python
def calculate_security_score():
    score = 100
    
    # CPU Mitigations (20 points)
    cpu_vulns = check_cpu_vulnerabilities()
    for vuln in cpu_vulns:
        if vuln.status == "Vulnerable":
            score -= 5
        elif vuln.status == "Partial":
            score -= 2
    
    # Credentials (15 points)
    if not credential_manager_setup():
        score -= 15
    elif credential_count() == 0:
        score -= 10
    
    # Network Exposure (25 points)
    if not firewall_active():
        score -= 15
    open_ports = count_open_ports()
    score -= min(open_ports * 2, 10)
    
    # System Hardening (40 points)
    if not apparmor_enabled():
        score -= 15
    if not disk_encrypted():
        score -= 20
    if not kernel_hardened():
        score -= 5
    
    return max(0, min(100, score))
```

## Integration Points

### With Existing Tools
- `testing/check-cpu-mitigations.sh` - CPU status
- `configs/security/configure-cpu-mitigations.sh` - CPU config
- `components/credential-manager/nubifer-creds` - Credential management
- `configs/security/security-monitor.sh` - System monitoring

### With GNOME
- Application menu entry
- System tray indicator (optional)
- Desktop notifications
- Settings integration

### With System
- Systemd service for background monitoring
- D-Bus service for IPC
- PolicyKit for privilege escalation

## Future Enhancements

### Most Risky Workspace

The Security Dashboard includes a "Most Risky Workspace" feature that provides a computed attention signal to help users prioritize workspace security maintenance.

#### Definition
The Most Risky Workspace is a **computed, read-only signal** that identifies the single workspace with the highest relative risk across all configured workspaces. This feature is designed to direct user attention, not take automated actions.

#### Key Characteristics
- **Read-only signal**: Displays information only, never executes actions
- **Attention-directing**: Helps users prioritize which workspace needs review
- **Relative ranking**: Compares risk across workspaces, not absolute threat levels
- **User judgment preserved**: Does not replace user decision-making

#### Explicit Non-Actions
The Most Risky Workspace feature explicitly:
- **Does not expose secrets** or credential content
- **Does not execute actions** or make changes automatically
- **Does not replace user judgment** about workspace security
- **Does not imply compromise** - only indicates elevated relative risk

#### Risk Input Examples
The risk calculation considers factors such as (non-exhaustive, adjustable):
- **Credential age**: Older credentials weighted higher in risk calculation
- **Write-enabled mode**: Production environments with write access enabled
- **Workspace inactivity**: Unused workspaces with still-valid credentials
- **Security check status**: Missing or failed recent security validations
- **Posture drift**: Deviation from recommended settings (e.g., read-only mode disabled)

#### Output Characteristics
- **Single workspace surfaced**: Only one workspace highlighted at a time
- **Clickable interface**: Selecting the workspace drills into detailed workspace view
- **Neutral labeling**: Marked as "Requires Attention" rather than "Unsafe" or "Compromised"
- **Local computation**: Risk assessment computed from locally indexed metadata
- **Rank-only display**: No numerical scores exposed to users

#### Technical Non-Goals
- **No provider-specific logic**: Risk calculation remains cloud-agnostic at this layer
- **No automatic remediation**: Feature provides information only, never takes corrective action
- **No cloud API calls**: Risk assessment does not trigger external service requests
- **No scoring exposure**: Users see relative ranking only, not numerical risk scores

#### Future Evolution
- **Risk inputs and weights may evolve** based on user feedback and threat landscape changes
- **User-configurable policies may be added** in later versions for customizable risk assessment
- **Initial versions use conservative defaults** to minimize false positives and user alarm

This feature integrates with the global dashboard → drill-down model, allowing users to quickly identify and investigate workspaces that may benefit from security attention.

### Phase 2
- Real-time monitoring with live updates
- Historical security score tracking
- Security recommendations based on usage patterns
- Integration with system updates

### Phase 3
- Cloud security posture (AWS/Azure/GCP credentials)
- Compliance checking (CIS benchmarks)
- Security audit logs
- Automated remediation options

### Phase 4
- Multi-system dashboard (manage multiple machines)
- Security alerts via email/SMS
- Integration with SIEM systems
- Custom security policies
