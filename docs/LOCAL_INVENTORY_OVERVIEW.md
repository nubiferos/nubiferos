# Local Cloud Inventory & Posture Overview

## Introduction

The Local Cloud Inventory & Posture Subsystem is an **optional, installer-selectable** component of NubiferOS that provides offline-first cloud inventory and security posture analysis. This subsystem powers dashboards and risk analysis without increasing cloud costs or exposing network services.

**Key Principle**: Inventory and posture-focused first, not time-series observability.

## Goals

- **Offline-first cloud inventory** and posture analysis
- **Minimize cloud API usage** and associated costs
- **Avoid introducing new remote attack surfaces**
- **Enable "Most Risky Workspace"** and cross-account insights
- **Keep NubiferOS secure-by-default** (feature is optional)

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                 NubiferOS System                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐    ┌─────────────────────┐    │
│  │   Workspaces    │    │   Security          │    │
│  │   (pass/GPG)    │    │   Dashboard         │    │
│  │                 │    │                     │    │
│  │  ┌─────────────┐│    │  ┌─────────────────┐│    │
│  │  │ AWS Creds   ││    │  │ Most Risky      ││    │
│  │  │ Azure Creds ││    │  │ Workspace       ││    │
│  │  │ GCP Creds   ││    │  │                 ││    │
│  │  └─────────────┘│    │  └─────────────────┘│    │
│  └─────────────────┘    └─────────────────────┘    │
│           │                        ▲               │
│           │                        │               │
│           ▼                        │               │
│  ┌─────────────────────────────────────────────┐   │
│  │     Local Inventory & Posture Subsystem    │   │
│  │                 (Optional)                  │   │
│  │                                             │   │
│  │  ┌─────────────┐  ┌─────────────────────┐  │   │
│  │  │ Collectors  │  │   Local Database    │  │   │
│  │  │             │  │   (PostgreSQL)      │  │   │
│  │  │ • AWS       │  │                     │  │   │
│  │  │ • Azure     │  │ • 127.0.0.1 only   │  │   │
│  │  │ • GCP       │  │ • Encrypted at rest │  │   │
│  │  │             │  │ • 30-90 day TTL     │  │   │
│  │  └─────────────┘  └─────────────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Core Components

### 1. Data Collection
- **Batch-based ingestion** (not streaming)
- **Manual sync** (`nubifer-sync` command)
- **Scheduled sync** (systemd timer)
- **Read-only cloud credentials** only
- **Rate-limited, cached, and incremental** where possible

### 2. Local Storage
- **Local database only** (PostgreSQL preferred, SQLite for MVP)
- **Binds to 127.0.0.1 or Unix socket only**
- **Never listens on external interfaces**
- **Strict filesystem permissions**
- **Data encrypted at rest** via system LUKS

### 3. Security Posture Analysis
- **Resource inventory and relationships**
- **IAM posture analysis** (high-level, no secrets)
- **Security-relevant metadata** (public exposure, age, drift)
- **Change detection** via snapshot diffing

## Data Model

### Periodic Snapshots
The subsystem captures point-in-time snapshots containing:

- **Accounts**: Cloud account identifiers and metadata
- **Regions**: Geographic regions and availability zones
- **Resource types**: Compute, storage, network, database resources
- **IAM posture**: High-level permissions and roles (no credential material)
- **Security metadata**: Public exposure, resource age, configuration drift

### Change Detection
- **Snapshot diffing** to identify changes over time
- **Resource lifecycle tracking** (created, modified, deleted)
- **Configuration drift detection** from security baselines
- **Compliance posture changes** over time

## Security Constraints (Hard Requirements)

### Network Security
- ❌ **No inbound network listeners**
- ❌ **No web UI exposed beyond localhost**
- ❌ **No anonymous access**
- ✅ **Local-only database binding**

### Data Security
- ❌ **No credential material stored**
- ✅ **Clear data retention policy** (default 30-90 days)
- ✅ **Encrypted at rest** via system LUKS
- ✅ **Strict filesystem permissions**

### Process Security
- ✅ **Least privilege execution**
- ✅ **systemd hardening** (NoNewPrivileges, ProtectSystem, etc.)
- ✅ **AppArmor profiles** for all components
- ✅ **Feature disabled by default**

## Dashboard Integration

### Workspace-Level Dashboard
- **Inventory summary** for single workspace
- **Security posture indicators**
- **Resource age and drift analysis**
- **Warnings and security flags**

### Global Dashboard
- **Cross-cloud overview** across all workspaces
- **"Most Risky Workspace" scoring**
- **Outdated credentials indicators**
- **High-risk patterns** (public exposure, stale resources)

## Risk Scoring (Initial Heuristics)

The system evaluates relative risk based on:

- **Publicly exposed resources** (higher risk)
- **Old/unrotated credentials** (higher risk)
- **Wide IAM permissions** (higher risk)
- **Large blast-radius resources** (higher risk)
- **Lack of recent activity** (higher risk)

*Note: Exact scoring algorithms will evolve based on user feedback and threat landscape.*

## Installation Options

### Calamares Installer Integration
During installation, users can select:

**"Enable Local Cloud Inventory & Posture Engine (Optional)"**
- **Default**: OFF (secure-by-default)
- **If enabled**: Install database, collectors, timers, dashboard components
- **If disabled**: No database, no background services, no additional attack surface

### Post-Installation
The subsystem can be enabled/disabled post-installation via:
```bash
# Enable subsystem
sudo nubifer-inventory enable

# Disable subsystem  
sudo nubifer-inventory disable

# Check status
nubifer-inventory status
```

## Usage Examples

### Manual Sync
```bash
# Sync all configured workspaces
nubifer-sync

# Sync specific workspace
nubifer-sync --workspace production-aws

# Sync with verbose output
nubifer-sync --verbose
```

### Scheduled Sync
```bash
# Enable daily sync at 2 AM
sudo systemctl enable nubifer-inventory-sync.timer

# Check sync status
systemctl status nubifer-inventory-sync.service
```

### Dashboard Access
```bash
# Launch security dashboard
nubifer-dashboard

# View workspace inventory
nubifer-inventory show --workspace production-aws

# Generate risk report
nubifer-inventory risk-report
```

## Explicit Non-Goals

### What This Subsystem Does NOT Do
- ❌ **Live observability stack** by default
- ❌ **Prometheus/Grafana** unless explicitly enabled later
- ❌ **Remote dashboards** or external access
- ❌ **API proxying** or cloud service forwarding
- ❌ **Cloud write operations** or resource modification
- ❌ **Credential storage** (credentials remain in pass/GPG)
- ❌ **Time-series metrics** or streaming data

### Scope Boundaries
- **Focus**: Resource inventory, relationships, and posture
- **NOT**: Live metrics streaming
- **NOT**: Remote-access dashboards
- **NOT**: Credential storage or management

## Security Benefits

### Risk Reduction
- **Offline-first design** reduces cloud API exposure
- **Local-only storage** eliminates remote data exposure
- **No inbound listeners** prevents network-based attacks
- **Optional installation** maintains secure-by-default posture

### Enhanced Visibility
- **Cross-account insights** without credential sharing
- **Posture drift detection** for compliance monitoring
- **Risk prioritization** through "Most Risky Workspace" scoring
- **Change tracking** for security incident investigation

## Future Evolution

### Planned Enhancements
- **Additional cloud providers** (Oracle Cloud, DigitalOcean)
- **Compliance frameworks** (CIS, NIST, SOC 2)
- **Custom risk scoring** rules and weights
- **Export capabilities** for external analysis

### Optional Integrations
- **Prometheus/Grafana** for users who explicitly enable observability
- **SIEM integration** for enterprise environments
- **Custom alerting** based on posture changes

---

**Version**: 1.0 (Nimbus)  
**Last Updated**: December 26, 2025  
**Status**: Design Phase