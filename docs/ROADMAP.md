# NubiferOS Roadmap

**Last Updated**: 2026-03-09
**Maintainer**: Jesse Toporowski

This document tracks planned features, their actual status, and known contradictions between docs. Each item has been audited against the codebase, internal docs, and the published website.

> **Legend**: Done = shipped in trunk | Partial = some code exists but incomplete | Planned = no implementation yet

---

## Completed (March 2026)

### OTA Update Infrastructure

| | |
|---|---|
| **Priority** | CRITICAL |
| **Status** | **Done** |

Full OTA update pipeline so installed systems receive updates without ISO rebuilds:

- **APT repository**: S3-hosted (`packages.nubiferos.org`) with CloudFront CDN, GPG-signed
- **9 .deb packages**: nubifer-core, nubifer-creds, nubifer-workspace, nubifer-dashboard, nubifer-tools, nubifer-welcome, nubifer-updater, nubifer-security, nubifer-branding
- **CI/CD**: `publish-packages.yml` auto-publishes on push to trunk; `release.yml` for manual version bumps
- **ISO bootstrap**: GPG key + APT source + systemd timer baked into ISO for first-boot repo access
- **Auto-updates**: `nubifer-update.timer` checks every 6 hours, auto-installs nubifer-* updates
- **Kernel reboots**: `needrestart` + `kexec-tools` for fast kernel update reboots
- **Security hardening package**: AppArmor, UFW, fail2ban, auditd, sysctl, SSH hardening, PAM policies
- **Branding package**: os-release, Plymouth, wallpapers, icons, dconf, GDM branding, GNOME extension

---

## Alpha Blockers

### 1. Read-Only Mode: CLI Enforcement

| | |
|---|---|
| **Priority** | CRITICAL |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` REQ-1 through REQ-4 |
| **Status** | **Done** (March 2026) |

All CLI wrappers now use word-boundary verb matching to block writes while allowing reads:
- **AWS**: Comprehensive write verb list + S3-specific shorthand handling
- **Azure**: Word-boundary matching with `grep -w`, 30+ write verbs
- **GCP**: Same approach, cloud-specific verbs (deploy, patch, submit, etc.)
- **OCI**: Same approach, OCI-specific verbs (terminate, launch, migrate, etc.)
- **Terraform**: Blocks apply (without plan file), destroy, import, taint, untaint. Allows `terraform apply planfile.out` (pre-approved)

**Remaining gaps** (non-blocking):
- No `nubifer-exec --force` emergency override (deferred)
- AWS S3 source/destination detection not implemented (blocks all S3 cp/sync/mv)
- CLI audit trail for write overrides not implemented

---

### ~~5.~~ 2. Context Manager D-Bus Service & GNOME Indicator

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `.kiro/specs/custom-linux-distro/tasks.md` 4.7/5.1 |
| **Status** | **Done** (March 2026) |

Fixed critical bugs:
- Implemented missing `create_workspace()` method in `workspace_service.py`
- Fixed `db_path` crash in CLI status command
- Fixed systemd service path mismatch (`nubiferos` → `nubifer`)
- Fixed `environment.py` to export both `NUBIFER_*` and `NUBIFEROS_*` variable naming conventions

**Remaining gaps** (non-blocking):
- Integration between context-manager and credential-manager (TODO at `cli.py:73`)
- D-Bus service auto-start not verified on live system

---

### 6. CLI Audit Trail

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` US-3 |
| **Status** | **Done** (March 2026) |

Local cloud command history — logs ALL commands through CLI wrappers, not just blocked ones:
- **SQLite database** at `~/.local/share/nubifer/audit/commands.db` (WAL mode for concurrent writes)
- **Logged fields**: timestamp, user, workspace, provider, cloud account, full command, read-only status, allowed/blocked, credential hint (last 4 chars), session ID
- **`nubifer-audit` CLI**: log (with filtering), search, stats, rotate, export (JSON/CSV)
- **All wrappers instrumented**: aws, az, gcloud, oci, terraform
- **Auto-rotation**: systemd timer prunes entries older than 90 days
- **Shell alias**: `na` for quick access

**Remaining gaps** (non-blocking):
- No `nubifer-exec --force` emergency override with logging
- No security dashboard integration for audit data
- Exit code capture requires replacing `exec` in wrappers (deferred)

---

## Beta / Core Features

### 7. Automated Post-Install Smoke Tests

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/KNOWN_ISSUES.md` |
| **Status** | **Planned** |

No unattended Calamares config. No post-install test script. Manual QEMU testing only. Estimated effort: 6-8 hours.

---

### 8. Security Dashboard MVP (GTK3)

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/specs/security-dashboard/ROADMAP.md` |
| **Status** | **Partial** |

**What exists**: `components/security-dashboard/nubifer-dashboard` is a working GTK app (~1,338 lines). Shows security score, CPU vulns, credential count, LUKS status, firewall, AppArmor, auto-updates, grype/lynis integration.

**Doc contradictions found**:
- **GTK version**: All docs say "GTK 4". Implementation uses **GTK 3** (`gi.require_version('Gtk', '3.0')`).
- **ROADMAP.md**: Marks ALL phases 1-4 as complete with checkmarks. Phases 3-4 are NOT implemented (no notifications, no background service, no D-Bus, no localization, no settings panel).
- **Website**: Claims "Monitor your security posture in real-time" and "no unexpected open ports" — no port scanning exists, no real-time monitoring (manual refresh only).
- **Website features table** claims "Credential Status: rotation reminders" and "Workspace Mode: Read-only vs read-write" — neither exists in the dashboard.
- **Ground truth**: Phase 1 MVP works well. Phase 2 partially done (firewall/AppArmor yes, port scanning no). Phases 3-4 not started.

---

### 9. Unified `nubifer` CLI Tool

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `.kiro/specs/nubifer-unified-cli/requirements.md` |
| **Status** | **Planned** |

No implementation. Currently uses separate commands: `nubifer-workspace`, `nubifer-creds`, `nubifer-dashboard`.

---

### 10. Resource Viewer & GUI Cloud Browser

| | |
|---|---|
| **Priority** | MEDIUM |
| **Source** | `.kiro/specs/custom-linux-distro/requirements.md` Req 6/7/10 |
| **Status** | **Done** (July 2026 — `nubifer-resources`, AWS; Azure/GCP tracked in issue #26) |

Phase 2 feature. No implementation.

---

### 11. Local Inventory & Security Posture Engine

| | |
|---|---|
| **Priority** | MEDIUM |
| **Source** | `docs/LOCAL_INVENTORY_OVERVIEW.md`, `docs/LOCAL_INVENTORY_THREAT_MODEL.md` |
| **Status** | **Planned** |

Design docs exist with threat model. No implementation. `DASHBOARD_DESIGN.md` describes cloud inventory integration but none exists in dashboard code.

---

## Cloud & Platform

### 12. TPM 2.0 Support (NitroTPM, vTPM, Hardware)

| | |
|---|---|
| **Priority** | MEDIUM |
| **Source** | `docs/LUKS_TPM_CLOUD_STRATEGY.md` |
| **Status** | **Done early** (July 2026 — shipped ahead of the v2.0 Cumulus plan) |

Shipped via runtime detection in one ISO: TPM 2.0 present → LUKS2+Argon2id root
with unencrypted /boot and clevis PCR-7 auto-unlock; no TPM → LUKS1 unchanged.
Covers hardware TPM and vTPMs exposing /dev/tpmrm0 (cloud variants — NitroTPM,
Azure Trusted Launch, GCP Shielded VM — become reachable once cloud image
builds exist, issue #18). End-to-end swtpm/hardware validation pending (#17).

---

### 13. Cloud Image Builds (AMI, Azure VHD, GCP Image)

| | |
|---|---|
| **Priority** | MEDIUM |
| **Source** | Implied by TPM doc + cloud focus |
| **Status** | **Planned** |

No build scripts for cloud images. Only ISO builds exist. The TPM doc references cloud deployments but no image pipeline.

**Doc contradiction found**:
- `about/_index.md` (website): "Unencrypted installation: LUKS is currently required (may be optional for cloud/VM deployments in future)" — acknowledges cloud images may need different encryption approach, but no implementation.

---

### 14. ARM64 Architecture Support

| | |
|---|---|
| **Priority** | LOW |
| **Source** | Build system gap |
| **Status** | **Planned** |

Build targets amd64 only. No ARM64 testing or cross-compilation.

---

### 15. Xfce Lightweight Desktop Option

| | |
|---|---|
| **Priority** | LOW |
| **Source** | `docs/DESIGN_DECISIONS.md` Decision 2 |
| **Status** | **Planned (v1.1+)** |

Design decision documents the trade-off (GNOME for security via Wayland vs Xfce for performance). Deferred to post-v1.0.

---

## Documentation

### 16. Installation Guide

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/README.md` (listed as "To be added") |
| **Status** | **Partial** |

Website has `/docs/getting-started/installation.md` and `/docs/getting-started/quick-start.md`. Internal `docs/guides/INSTALLER_QUICKSTART.md` exists. But no comprehensive end-to-end guide covering BIOS/UEFI, USB creation, and troubleshooting.

---

### 17. User Guide / Getting Started

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/README.md` |
| **Status** | **Partial** |

Website has workspaces and credentials guides. Internal docs have quick reference. Missing: consolidated user guide.

---

### 18. Credential Setup & Management Guide

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/README.md` |
| **Status** | **Partial** |

Website has `/docs/user-guide/credentials.md`. Internal `docs/CREDENTIAL_SECURITY.md` exists. Missing: step-by-step per-provider setup (AWS SSO, Azure Service Principal, GCP service account).

---

### 19. Security Architecture Documentation

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `docs/README.md` |
| **Status** | **Partial** |

Website has comprehensive `/security/` section. Internal `docs/SECURITY_SUMMARY.md` and `docs/THREAT_MODEL.md` exist. Missing: single consolidated architecture doc.

---

### 20. Internationalization & Accessibility

| | |
|---|---|
| **Priority** | LOW |
| **Source** | `docs/specs/security-dashboard/ROADMAP.md` Phase 4 |
| **Status** | **Planned** |

No i18n support anywhere. Dashboard has minimal accessibility (tooltips only, no screen reader labels).

---

## Known Doc Contradictions (Action Required)

These contradictions were found during the audit and need resolution:

### LUKS Version: Website says LUKS2, reality is LUKS1

| File | Claims | Reality |
|------|--------|---------|
| `website/about/_index.md` line 58 | "LUKS2 (mandatory)" | **LUKS1** |
| `website/about/_index.md` line 75 | "LUKS1 full disk encryption" | LUKS1 (correct) |
| `website/why-nubiferos/_index.md` line 92 | "LUKS2" | **LUKS1** |
| `CLAUDE.md` | "LUKS1 encryption" | LUKS1 (correct) |
| `partition.conf` | `luksGeneration: luks1` | LUKS1 (correct) |

**Action**: Fix website `about/_index.md` line 58 and `why-nubiferos/_index.md` line 92 to say LUKS1.

---

### Encryption "Mandatory" but technically uncheckable

| File | Claims | Reality |
|------|--------|---------|
| Website + internal docs | "LUKS is mandatory" | User CAN uncheck encryption in Calamares |
| `partition.conf` line 36 | `preCheckEncryption: true` | Pre-checked but optional |

**Action**: Either force encryption in Calamares (remove uncheck option) or update marketing to "strongly recommended / enabled by default".

---

### Read-Only Mode: Spec says partial, website says complete

| File | Claims | Reality |
|------|--------|---------|
| `requirements.md` | "70% complete, only kubectl works" | AWS wrapper exists too |
| Website (features, security pages) | Read-only fully working | Azure/GCP over-block, Terraform missing |
| `SECURITY_SUMMARY.md` | "Protected" checkmark | Partially true |

**Action**: Update `requirements.md` to reflect current state (AWS + kubectl work, az/gcloud over-block, Terraform missing). Update website to note read-only is "available for AWS and kubectl; expanding to other CLIs".

---

### Security Dashboard: ROADMAP marks everything done

| File | Claims | Reality |
|------|--------|---------|
| `specs/security-dashboard/ROADMAP.md` | Phases 1-4 all checkmarked | Only Phase 1 + partial Phase 2 done |
| All dashboard docs | "GTK 4" | Implementation uses GTK 3 |
| Website | "real-time monitoring", "open ports", "rotation reminders" | Manual refresh, no port scan, no rotation |

**Action**: Un-checkmark Phases 3-4 in ROADMAP.md. Update GTK version references. Remove unimplemented claims from website.

---

### Homepage code snippet uses wrong command name

| File | Claims | Reality |
|------|--------|---------|
| `website/_index.html` line 96-103 | `nubiferos workspace create` | Command is `nubifer-workspace create` |

**Action**: Fix command in website homepage code snippet.

---

## Related Documentation

- `docs/KNOWN_ISSUES.md` - Active bugs and fixes
- `docs/status/COMPLETION_CHECKLIST.md` - Feature checklist
- `docs/build/ISO_BUILD_ROADMAP.md` - Build-specific roadmap
- `docs/specs/security-dashboard/ROADMAP.md` - Dashboard phases
- `.kiro/specs/read-only-mode/` - Read-only mode specs
