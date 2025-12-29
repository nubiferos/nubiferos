# NubiferOS Dashboard Design

This document describes the design of the NubiferOS Security Dashboard, including integration with the optional Local Cloud Inventory & Posture Subsystem.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NubiferOS Dashboard                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────┐    │
│  │   System Security   │    │   Cloud Inventory       │    │
│  │   Dashboard         │    │   Dashboard             │    │
│  │                     │    │   (Optional)            │    │
│  │  • CPU Security     │    │                         │    │
│  │  • Network Status   │    │  • Workspace Overview  │    │
│  │  • Disk Encryption  │    │  • Risk Analysis        │    │
│  │  • AppArmor         │    │  • Resource Inventory   │    │
│  │                     │    │  • Posture Tracking     │    │
│  └─────────────────────┘    └─────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Global Overview                        │   │
│  │                                                     │   │
│  │  • Overall Security Score                           │   │
│  │  • Most Risky Workspace (if inventory enabled)     │   │
│  │  • Recent Security Events                           │   │
│  │  • System Health Summary                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Dashboard Components

### 1. System Security Dashboard (Always Available)

#### Core Security Metrics
- **CPU Security Status**: Vulnerability mitigations and performance impact
- **Network Exposure**: Firewall status, open ports, listening services
- **Disk Encryption**: LUKS status and configuration
- **System Hardening**: AppArmor, kernel parameters, security services

#### Visual Layout
```
┌─────────────────────────────────────────────────────────────┐
│  NubiferOS Security Dashboard                    [_][□][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Security Score: 85                       │   │
│   │         ████████████████████░░░░░░░░░░░░░░           │   │
│   │              ⚠️  Caution Level                        │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                               │
│   ┌──────────────────────┐  ┌──────────────────────┐        │
│   │  CPU Security        │  │  Network Exposure    │        │
│   │  ⚠️  Partial         │  │  ✓ Secure            │        │
│   │                      │  │                      │        │
│   │  • Spectre v2: ✓     │  │  Firewall: Active    │        │
│   │  • RETBleed: ⚠️      │  │  Open Ports: 0       │        │
│   │  • Meltdown: ✓       │  │  SSH: Disabled       │        │
│   │                      │  │                      │        │
│   │  [Configure...]      │  │  [Details...]        │        │
│   └──────────────────────┘  └──────────────────────┘        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 2. Cloud Inventory Dashboard (Optional)

#### Workspace-Level View
When Local Cloud Inventory & Posture Subsystem is enabled:

```
┌─────────────────────────────────────────────────────────────┐
│  Workspace: production-aws                        [Back][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Inventory Summary                                  │   │
│  │                                                       │   │
│  │  • 47 EC2 Instances    • 12 RDS Databases           │   │
│  │  • 23 S3 Buckets       • 8 Load Balancers           │   │
│  │  • 156 IAM Users       • 34 Security Groups         │   │
│  │                                                       │   │
│  │  Last Updated: 2 hours ago                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Security Posture                                   │   │
│  │                                                       │   │
│  │  ⚠️  3 Public S3 Buckets                            │   │
│  │  ⚠️  12 Resources > 90 days old                     │   │
│  │  ✓  All RDS instances encrypted                     │   │
│  │  ✓  MFA enabled on root account                     │   │
│  │                                                       │   │
│  │  Risk Level: Medium                                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Recent Changes                                     │   │
│  │                                                       │   │
│  │  • 1 day ago: New S3 bucket created (public)        │   │
│  │  • 3 days ago: IAM policy modified                   │   │
│  │  • 1 week ago: Security group rule added            │   │
│  │                                                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│                    [Sync Now]  [Export]  [Settings]          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

#### Global Cloud Overview
```
┌─────────────────────────────────────────────────────────────┐
│  Cloud Overview - All Workspaces                 [_][□][×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Most Risky Workspace: Requires Attention          │   │
│  │                                                       │   │
│  │  📋 staging-azure                                    │   │
│  │                                                       │   │
│  │  • Credentials 127 days old                          │   │
│  │  • 5 public resources detected                       │   │
│  │  • Write mode enabled in production                  │   │
│  │                                                       │   │
│  │  [Review Workspace →]                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  production-aws      │  │  development-gcp     │        │
│  │  ✓ Low Risk          │  │  ⚠️  Medium Risk     │        │
│  │                      │  │                      │        │
│  │  • 47 resources      │  │  • 23 resources      │        │
│  │  • Updated 2h ago    │  │  • Updated 1d ago    │        │
│  │  • All encrypted     │  │  • 2 public buckets  │        │
│  │                      │  │                      │        │
│  │  [View Details]      │  │  [View Details]      │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                               │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  staging-azure       │  │  testing-aws         │        │
│  │  🔴 High Risk        │  │  ✓ Low Risk          │        │
│  │                      │  │                      │        │
│  │  • 89 resources      │  │  • 12 resources      │        │
│  │  • Updated 3d ago    │  │  • Updated 4h ago    │        │
│  │  • Old credentials   │  │  • Read-only mode    │        │
│  │                      │  │                      │        │
│  │  [View Details]      │  │  [View Details]      │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Most Risky Workspace Integration

### Computation Logic
The "Most Risky Workspace" feature integrates with the dashboard as follows:

#### Risk Factors (Weighted)
```python
def calculate_workspace_risk(workspace):
    risk_score = 0
    
    # Credential age (25% weight)
    credential_age_days = get_credential_age(workspace)
    if credential_age_days > 90:
        risk_score += 25
    elif credential_age_days > 60:
        risk_score += 15
    elif credential_age_days > 30:
        risk_score += 5
    
    # Write mode in production (20% weight)
    if is_production_workspace(workspace) and is_write_enabled(workspace):
        risk_score += 20
    
    # Workspace inactivity (15% weight)
    days_since_activity = get_days_since_activity(workspace)
    if days_since_activity > 30:
        risk_score += 15
    elif days_since_activity > 14:
        risk_score += 10
    
    # Security check failures (20% weight)
    failed_checks = get_failed_security_checks(workspace)
    risk_score += min(failed_checks * 5, 20)
    
    # Public resource exposure (20% weight)
    public_resources = count_public_resources(workspace)
    risk_score += min(public_resources * 3, 20)
    
    return min(risk_score, 100)
```

#### Display Characteristics
- **Single workspace highlighted** at top of global dashboard
- **Neutral language**: "Requires Attention" not "Unsafe" or "Compromised"
- **Clickable**: Drills down to detailed workspace view
- **Contextual information**: Shows specific risk factors
- **No numerical scores**: Only relative ranking displayed

### Dashboard Integration Points

#### Global Dashboard
```
┌─────────────────────────────────────────────────────┐
│  Most Risky Workspace: Requires Attention          │
│                                                     │
│  📋 staging-azure                                   │
│                                                     │
│  Risk factors identified:                           │
│  • Credentials 127 days old                        │
│  • 5 public resources detected                     │
│  • Write mode enabled in production environment    │
│  • No security scan in 45 days                     │
│                                                     │
│  [Review Workspace →]                              │
└─────────────────────────────────────────────────────┘
```

#### Workspace Detail View
When user clicks through from "Most Risky Workspace":

```
┌─────────────────────────────────────────────────────┐
│  Workspace: staging-azure (Requires Attention)     │
│                                                     │
│  Attention Factors:                                 │
│                                                     │
│  🕐 Credential Age                                  │
│     Last rotated: 127 days ago                     │
│     Recommendation: Rotate credentials              │
│     [Rotate Now] [Schedule Rotation]               │
│                                                     │
│  🌐 Public Resources                                │
│     5 resources publicly accessible                │
│     • storage-bucket-logs (S3)                     │
│     • web-assets-cdn (S3)                          │
│     • api-gateway-prod (API Gateway)               │
│     [Review Access] [Generate Report]              │
│                                                     │
│  ✏️  Write Mode Active                              │
│     Production environment has write access        │
│     Recommendation: Enable read-only mode          │
│     [Enable Read-Only] [Configure Schedule]        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Technical Implementation

### Data Sources

#### System Security (Always Available)
- `/sys/devices/system/cpu/vulnerabilities/` - CPU vulnerability status
- `ufw status` - Firewall configuration
- `ss -tulpn` - Open ports and listening services
- `aa-status` - AppArmor profile status
- `lsblk` - Disk encryption status
- `systemctl status` - Security service status

#### Cloud Inventory (Optional)
- Local PostgreSQL/SQLite database
- Cached cloud API responses
- Workspace configuration files
- Historical snapshot data

### Security Constraints

#### Network Security
- **Dashboard binds to 127.0.0.1 only** - no external access
- **No inbound network listeners** for cloud data
- **Local database connections only** - no remote database access
- **HTTPS verification** for all cloud API calls

#### Process Security
- **systemd hardening** for all dashboard processes
- **AppArmor profiles** restricting file system access
- **Least privilege execution** with dedicated user accounts
- **Input sanitization** on all user inputs and cloud data

#### Data Security
- **No credential storage** in dashboard database
- **Encrypted at rest** via system LUKS
- **Strict file permissions** (600/700) on all data files
- **Automatic data purging** after retention period

### Performance Characteristics

#### System Requirements
- **Memory usage**: < 100MB for dashboard UI
- **CPU usage**: < 5% during normal operation
- **Disk usage**: < 500MB for database and cache
- **Startup time**: < 3 seconds for dashboard launch

#### Scalability Limits
- **Maximum workspaces**: 50 workspaces per installation
- **Database size**: < 1GB for typical usage
- **Sync frequency**: Minimum 1 hour between syncs
- **Retention period**: 30-90 days of historical data

## User Experience

### Navigation Flow
1. **Launch Dashboard** → Global overview with security score
2. **System Security** → CPU, network, disk, hardening details
3. **Cloud Overview** → All workspaces (if inventory enabled)
4. **Most Risky Workspace** → Specific workspace requiring attention
5. **Workspace Details** → Inventory, posture, and recommendations

### Accessibility
- **Keyboard navigation** for all dashboard functions
- **High contrast mode** support
- **Screen reader compatibility** with proper ARIA labels
- **Configurable font sizes** for visual accessibility

### Internationalization
- **English by default** with UTF-8 support
- **Localization framework** for future language support
- **Cultural date/time formats** based on system locale
- **Right-to-left language support** in UI framework

## Future Enhancements

### Phase 2 Features
- **Custom risk scoring** rules and weights
- **Compliance framework** integration (CIS, NIST)
- **Export capabilities** for external analysis
- **Advanced filtering** and search functionality

### Phase 3 Features
- **Multi-system dashboard** (manage multiple NubiferOS installations)
- **Alerting integration** with external systems
- **API endpoints** for programmatic access (local only)
- **Plugin architecture** for custom security checks

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: December 26, 2025  
**Status**: Design Phase