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

### ✅ Installer-Only Mode Has Full Desktop Access
**Status**: FIXED  
**Fixed**: 2026-02-04  
**Commit**: feature/installer-kiosk-mode branch

**Issue**:
- Calamares ran as a window on top of GNOME desktop
- User could access Firefox, Terminal, Files, and other apps during installation
- Full desktop environment was available

**Solution**: Implemented "Option 3: Direct Boot to Calamares (Minimal)"
- Removed GNOME Shell, GDM, and all desktop packages
- Boot directly to minimal X session running only Calamares
- Getty auto-login on tty1, masked tty2-6
- X server configured with DontVTSwitch and DontZap
- System reboots automatically when Calamares exits

**Implementation Files**:
- `build/install-kiosk-packages.sh` - Minimal package installation
- `build/configure-kiosk-session.sh` - Session configuration
- `build/validate-kiosk-config.sh` - Configuration validation
- `docs/testing/KIOSK_SECURITY_TESTS.md` - Security test checklist

**Security Tests**: See `docs/testing/KIOSK_SECURITY_TESTS.md` for full checklist

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

### ✅ GRUB Installation Fails During Calamares Install
**Status**: FIXED  
**Fixed**: 2026-01-15  
**Discovered**: 2026-01-15

**Issue**:
- Installation completed but failed at bootloader step
- Error: "The bootloader could not be installed"

**Solution**:
- Fixed GRUB configuration and wrapper scripts
- Verified working across 50+ successful builds

**Related Files**:
- `installer/calamares/modules/bootloader.conf`
- `scripts/grub-install-safe-wrapper.sh`

---

### ✅ Auto-Login Not Working on ISO Boot
**Status**: OBSOLETE  
**Reason**: Kiosk mode eliminated GDM entirely  
**Fixed**: 2026-02-04

**Issue**:
- ISO booted to GDM login screen requiring manual login

**Resolution**:
- Kiosk mode uses getty auto-login on tty1
- No GDM, no login screen
- Calamares starts automatically

---

### ✅ "Login Without Password" Option Should Be Disabled
**Status**: OBSOLETE  
**Reason**: Kiosk mode eliminated user creation during live session  
**Fixed**: 2026-02-04

**Issue**:
- Calamares users module allowed creating user without password

**Resolution**:
- Kiosk mode has no desktop session
- User creation only happens during installation (password required)

---

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

**Last Updated**: 2026-02-04  
**Maintainer**: Jesse Toporowski
