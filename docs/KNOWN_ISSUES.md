# Known Issues - NubiferOS

This document tracks known bugs, issues, and planned fixes for NubiferOS.

## Status Legend
- 🔴 **CRITICAL** - Blocks installation/boot
- 🟡 **HIGH** - Impacts user experience significantly
- 🟢 **MEDIUM** - Minor inconvenience
- 🔵 **LOW** - Nice to have

---

## Active Issues

### 🟡 MEDIUM: Automated Installation Testing Needed
**Status**: PLANNED  
**Priority**: After Phase 1 complete  
**Discovered**: 2026-01-15

**Current State**:
- Manual testing of installation in QEMU
- No automated post-installation smoke tests
- No verification that installed system boots
- No testing of core features after install

**Desired State**:
- Automated unattended Calamares installation
- Post-install smoke tests (network, sudo, CLI tools)
- Verify installed system boots successfully
- Test core NubiferOS features work

**Blocked By**:
- Phase 1 must complete first (basic installer working)
- Need unattended Calamares configuration
- Need SSH/serial console access to installed system

**Implementation Plan**:
1. Create unattended Calamares config
2. Extend pytest suite with installation tests
3. Add post-install smoke test script
4. Integrate into GitHub Actions workflow

**Estimated Effort**: 6-8 hours

**Related Files**:
- `testing/test-iso-pytest.py` - Existing test suite
- `.github/workflows/build-iso.yml` - CI workflow
- Future: `scripts/smoke-test.sh`
- Future: `installer/calamares/unattended.conf`

**Next Steps**:
1. Complete Phase 1 (installer working)
2. Document manual test checklist
3. Design unattended installation approach
4. Implement automated tests

---

### 🔴 CRITICAL: GRUB Installation Fails During Calamares Install
**Status**: INVESTIGATING  
**Discovered**: 2026-01-15  
**Affects**: All installations via Calamares

**Symptoms**:
- Installation completes but fails at bootloader step
- Error: "The bootloader could not be installed"
- Command: `grub-install --target=i386-pc --recheck --force /dev/sda` returns error code 1

**Impact**:
- System installs but won't boot without manual GRUB installation
- Blocks production use

**Investigation**:
- Disk appears as `/dev/sda` (IDE interface working correctly)
- GRUB binaries are installed in ISO
- May be related to chroot environment or missing dependencies
- `skipBootloaderOnFailure: true` is set but error still displays

**Related Files**:
- `installer/calamares/modules/bootloader.conf`
- `scripts/grub-install-safe-wrapper.sh`
- `build/install-desktop-installer.sh`

**Next Steps**:
1. Check if grub-install-safe-wrapper is being used
2. Verify GRUB packages in chroot
3. Check Calamares logs for detailed error
4. Test manual GRUB installation in chroot

---

### 🟡 HIGH: Installer-Only Mode Has Full Desktop Access
**Status**: DESIGN ISSUE  
**Discovered**: 2026-01-15  
**Affects**: Installer ISO security posture

**Symptoms**:
- Calamares runs as a window on top of GNOME desktop
- User can access Firefox, Terminal, Files, and other apps during installation
- Full desktop environment is available

**Expected Behavior** (Installer-Only Mode):
- Calamares should run fullscreen, no desktop visible
- No access to other applications during installation
- Minimal attack surface
- Locked down environment

**Current Behavior** (More Like Live ISO):
- Full GNOME desktop available
- Can browse web, open terminal, access files
- Calamares is just another window

**Impact**:
- Security: Larger attack surface during installation
- User confusion: Looks like a live environment
- Not truly "installer-only"

**Decision**:
- **Short-term**: Keep desktop access for debugging
- **Requirement**: Lock down to Calamares fullscreen (Option A) before production

**Related Files**:
- `build/install-desktop-installer.sh`
- `build/configure-installer-autostart.sh`
- Calamares launch configuration

**Options to Lock Down**:
1. Launch Calamares with `--fullscreen` flag
2. Disable desktop environment, run Calamares in kiosk mode
3. Use a minimal window manager instead of GNOME
4. Block access to other applications via policy

**Next Steps**:
1. Decide on desired behavior
2. Research Calamares fullscreen/kiosk mode
3. Consider separate build modes: installer-only vs live-installer

---

### 🟡 HIGH: Auto-Login Not Working on ISO Boot
**Status**: CONFIRMED  
**Discovered**: 2026-01-15  
**Affects**: Installer ISO only (not installed system)

**Symptoms**:
- ISO boots to GDM login screen
- User must manually login as `installer/installer`
- Calamares auto-starts after manual login (working correctly)

**Expected Behavior**:
- Should auto-login as `installer` user
- No login screen should appear

**Impact**:
- Minor inconvenience - user must know credentials
- Not critical since Calamares still auto-starts

**Investigation**:
- GDM config in `build/configure-installer-autostart.sh` sets `AutomaticLoginEnable=true`
- Config may be overwritten by another script
- May be timing issue with GDM service startup

**Related Files**:
- `build/configure-installer-autostart.sh`
- `build/install-desktop-installer.sh` (removed GDM config from configure_wayland)
- `/etc/gdm3/custom.conf` in ISO

**Workaround**:
- Login manually with `installer/installer`
- Calamares will auto-start

**Next Steps**:
1. Check GDM config in built ISO
2. Verify no other scripts overwrite auto-login settings
3. Check systemd service ordering

---

### 🟢 MEDIUM: "Login Without Password" Option Should Be Disabled
**Status**: CONFIRMED  
**Discovered**: 2026-01-15  
**Affects**: User creation during installation

**Symptoms**:
- Calamares users module allows creating user without password
- Security risk for production systems

**Expected Behavior**:
- Password should be mandatory
- No option to skip password

**Impact**:
- Security concern if users skip password
- Not blocking but should be fixed

**Investigation**:
- Controlled by `installer/calamares/modules/users.conf`
- Setting: `allowWeakPasswords: false` (already set)
- May need additional setting to disable no-password option

**Related Files**:
- `installer/calamares/modules/users.conf`
- `build/setup-calamares-minimal.sh`

**Next Steps**:
1. Research Calamares users module options
2. Find setting to disable no-password option
3. Test with updated config

---

### 🔵 LOW: AI Development Tools Integration
**Status**: PLANNED  
**Priority**: Phase 3 (after Phase 1 complete + read-only mode)  
**Discovered**: 2026-01-18

**Description**:
Add optional AI development tools during Calamares installation to support cloud engineers working with AI/ML services.

**Scope**:

**1. AI Coding Assistants (Calamares Package Selection)**:
- Kiro (VS Code extension)
- Claude Desktop (Anthropic's desktop app)
- GitHub Copilot (VS Code extension)
- Cursor (AI-first code editor)
- Continue.dev (open source AI assistant)

**2. AI CLI Tools**:
- aider (AI pair programming in terminal)
- fabric (AI patterns for CLI)
- llm (Simon Willison's CLI tool)

**3. Cloud Provider AI Services Documentation**:

**AWS AI Services**:
- Amazon Bedrock (managed LLMs - Claude, Llama, etc.)
- SageMaker (ML model training/deployment)
- CodeWhisperer (AI coding assistant)
- Q Developer (AI assistant for AWS)

**Azure AI Services**:
- Azure OpenAI Service (GPT-4, GPT-3.5, DALL-E)
- Azure AI Studio (model deployment)
- GitHub Copilot (Microsoft-owned)
- Azure Cognitive Services (vision, speech, language)

**GCP AI Services**:
- Vertex AI (unified ML platform)
- Gemini API (Google's LLM)
- Duet AI (coding assistant)
- AI Platform (model training/serving)

**4. Implementation Tasks**:
1. Pre-install CLI tools for AI services (boto3 for Bedrock, Azure SDK, GCP SDK)
2. Add workspace templates for AI development workflows
3. Include example configs for common AI/ML tasks
4. Document API key management for each cloud provider's AI services
5. Create Calamares `netinstall.conf` module for optional AI tools
6. Package AI tools via snap/flatpak/npm for easy installation
7. Post-install script to configure API keys (optional, secure)

**Benefits**:
- Positions NubiferOS as AI-ready cloud workstation
- Supports growing AI/ML use cases in cloud engineering
- Differentiates from generic Linux distros
- Aligns with market trends (AI adoption in DevOps)

**Implementation Plan**:
1. Research Calamares netinstall module configuration
2. Create package groups for AI tools
3. Document cloud provider AI services
4. Create workspace templates for AI workflows
5. Add API key management documentation
6. Test installation and configuration

**Estimated Effort**: 12-16 hours

**Related Files**:
- Future: `installer/calamares/modules/netinstall.conf`
- Future: `docs/AI_TOOLS.md`
- Future: `docs/CLOUD_AI_SERVICES.md`
- Future: `scripts/configure-ai-tools.sh`
- Future: `workspaces/templates/ai-development/`

**Dependencies**:
- Phase 1 complete (basic installer working)
- Read-only mode implemented (alpha blocker)
- Workspace system functional

**Next Steps**:
1. Complete Phase 1 and read-only mode
2. Research Calamares netinstall module
3. Survey popular AI tools and SDKs
4. Create documentation structure
5. Design workspace templates

---

## Fixed Issues

### ✅ GRUB Boot - ISO Drops to Rescue Shell
**Status**: FIXED  
**Fixed**: 2026-01-15  
**Commit**: Current

**Issue**:
- ISO booted to GRUB rescue shell
- Required manual commands: `set root=(cd)`, `set prefix=...`, `configfile ...`
- Happened 3+ times with different "fixes"

**Root Cause**:
- Conditional logic in embedded GRUB config doesn't work
- Absolute paths to config files break grub-mkstandalone
- Search commands are slow and unreliable

**Solution**:
- Sequential device tries without conditionals
- Relative paths for embedded.cfg
- Simple approach: try (cd), (cd0), (cd1) in order

**Protection**:
- Critical documentation: `docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md`
- Validation script: `build/validate-grub-config.sh`
- Code comments in `build/build-iso.sh`

---

### ✅ Calamares Slideshow - Only 3 Slides Repeating
**Status**: FIXED  
**Fixed**: 2026-01-15  
**Commit**: Current

**Issue**:
- Slideshow showed only 3 generic slides during installation
- Repeated the same content
- Not NubiferOS-specific

**Root Cause**:
- `build/setup-calamares-minimal.sh` was generating a simple 3-slide slideshow
- Overwrote the proper 15-slide version in `installer/calamares/branding/nubiferos/show.qml`

**Solution**:
- Removed slideshow generation from setup script
- Proper 15-slide QML file is now used
- Each slide displays for 35 seconds

**Verification**:
- ✅ All 15 slides display during installation
- ✅ Content is NubiferOS-specific (security features, benefits, etc.)

---

## Issue Tracking Guidelines

### When to Add an Issue Here

Add issues that are:
- Confirmed and reproducible
- Not immediately fixable
- Need tracking across sessions
- Require investigation
- Impact multiple users

### When to Create a Task

Create a task in `.kiro/specs/*/tasks.md` when:
- Issue has a clear solution
- Work is planned/scheduled
- Part of a larger feature
- Needs formal tracking

### When to Create a Critical Doc

Create a critical doc in `docs/fixes/*_CRITICAL.md` when:
- Same issue fixed 2+ times
- Non-obvious solution
- High cost of failure
- Multiple "clever" alternatives exist

See: `docs/WHAT_IS_A_CRITICAL_DOC.md`

---

## Related Documentation

- `docs/WHAT_IS_A_CRITICAL_DOC.md` - When to create critical docs
- `docs/fixes/` - Directory for fix documentation
- `.kiro/specs/*/tasks.md` - Formal task tracking
- Git commit history - Detailed change log

---

**Last Updated**: 2026-01-15  
**Maintainer**: Jesse Toporowski
