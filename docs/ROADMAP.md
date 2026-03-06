# NubiferOS Roadmap

**Last Updated**: 2026-02-07
**Maintainer**: Jesse Toporowski

This document tracks planned features, their actual status, and known contradictions between docs. Each item has been audited against the codebase, internal docs, and the published website.

> **Legend**: Done = shipped in trunk | Partial = some code exists but incomplete | Planned = no implementation yet

---

## Alpha Blockers

### 1. Read-Only Mode: AWS CLI Enforcement

| | |
|---|---|
| **Priority** | CRITICAL |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` REQ-1 |
| **Status** | **Partial** |

**What exists**: `components/workspace-manager/cli-wrappers/aws` has pattern-based verb matching (create, delete, update, modify, terminate, etc. + S3 write commands). Blocks operations when `NUBIFER_WORKSPACE_READ_ONLY=true`.

**What's missing**: No special-case handling for S3 source/destination detection (spec calls for distinguishing `s3 cp` read vs write). No `nubifer-exec --force` emergency override (spec designed it but never implemented).

**Doc contradictions found**:
- `requirements.md` says "only works for kubectl" (written Jan 2026) but the AWS wrapper already exists with verb matching.
- `SECURITY_SUMMARY.md` and website claim read-only is fully "Protected" with a checkmark.
- **Ground truth**: AWS wrapper works for common verbs but lacks the sophistication described in `design.md`.

---

### 2. Read-Only Mode: Azure CLI Enforcement

| | |
|---|---|
| **Priority** | CRITICAL |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` REQ-2 |
| **Status** | **Partial (over-blocking)** |

**What exists**: `cli-wrappers/az` blocks ALL operations when read-only is active (blanket block, no pattern detection).

**What's missing**: Should detect specific write verbs (like the AWS wrapper does) to allow `az account show`, `az group list`, etc.

**Doc contradictions found**:
- `requirements.md` lists this as Phase 2 (Beta), but a wrapper already exists.
- Website presents read-only as working for all CLIs. Technically it "works" but blocks reads too.
- **Ground truth**: Over-restrictive. Users can't run ANY `az` commands in RO mode, not just writes.

---

### 3. Read-Only Mode: GCP gcloud Enforcement

| | |
|---|---|
| **Priority** | CRITICAL |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` REQ-3 |
| **Status** | **Partial (over-blocking)** |

Same issue as Azure. `cli-wrappers/gcloud` blanket-blocks all operations. Same for `oci`.

---

### 4. Read-Only Mode: Terraform Enforcement

| | |
|---|---|
| **Priority** | CRITICAL |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` REQ-4 |
| **Status** | **Planned (not implemented)** |

**What exists**: Nothing. No Terraform wrapper in `cli-wrappers/`.

**What's missing**: Should block `terraform apply`, `destroy`, `import`, `taint`, `untaint`. Should allow `terraform plan`, `show`, `state list`. Spec even designed special-case handling for `terraform apply tfplan.out` (applying a saved plan).

**Doc contradictions found**:
- `requirements.md` lists this as Phase 1 Alpha Blocker (2-3 hours effort).
- `design.md` has a complete Python implementation design.
- Website doesn't mention Terraform in read-only context.
- **Ground truth**: Completely missing despite being spec'd as critical.

---

### 5. Context Manager D-Bus Service & GNOME Indicator

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `.kiro/specs/custom-linux-distro/tasks.md` 4.7/5.1 |
| **Status** | **Partial** |

**What exists**: GNOME Shell extension installed. Context Manager D-Bus service files exist. Shell prompt integration works.

**What's missing**: Extension shows "No Workspace" until D-Bus service runs. Service startup not verified. Integration between context-manager and credential-manager incomplete (TODO at `components/context-manager/src/cli.py:73`).

---

### 6. CLI Audit Trail for Read-Only Overrides

| | |
|---|---|
| **Priority** | HIGH |
| **Source** | `.kiro/specs/read-only-mode/requirements.md` US-3 |
| **Status** | **Planned** |

**What exists**: sudo logs capture `nubifer-workspace rw` invocations.

**What's missing**: No dedicated audit log (`~/.local/share/nubifer/audit.log`). No `nubifer-audit log` command. No `nubifer-exec --force` emergency override with logging. No security dashboard integration.

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

### 8. Security Dashboard MVP (GTK4)

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
| **Status** | **Planned** |

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
| **Status** | **Planned (v2.0)** |

Strategy doc exists covering AWS NitroTPM, Azure vTPM, GCP Shielded VM, and hardware TPM. Consistently documented as "FUTURE IMPLEMENTATION" in both internal docs and website (v2.0 Cumulus).

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
