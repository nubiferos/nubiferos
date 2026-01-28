# NubiferOS Tweaks & Customizations

This document lists modifications NubiferOS makes to default behavior for improved UX and security.

## CLI Behavior

### AWS CLI Pager Disabled

**What:** AWS CLI pager is disabled by default (`AWS_PAGER=""`).

**Why:** 
- Prevents terminal corruption when pressing Ctrl+C to exit long JSON output
- Enables clean piping to `jq`, `grep`, and other tools
- More predictable behavior for scripting

**Default behavior:** Output streams directly to terminal without paging.

**To re-enable pager:** Add to your `~/.bashrc`:
```bash
export AWS_PAGER="less"
```

**Per-command pager:** 
```bash
aws ec2 describe-instances | less
```

---

## Desktop Environment

### Minimize/Maximize Buttons Enabled

**What:** Window minimize and maximize buttons are enabled in GNOME.

**Why:** Standard window management expected by most users.

**Setting:** `org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'`

---

## Security Defaults

### Firewall (UFW) Deny-by-Default

**What:** UFW is enabled with default deny incoming policy.

**Why:** Reduces attack surface on untrusted networks.

### AppArmor Enforcing

**What:** AppArmor is enabled with profiles enforced.

**Why:** Mandatory access control limits application capabilities.

### Automatic Security Updates

**What:** Unattended-upgrades enabled for security patches.

**Why:** Critical vulnerabilities patched automatically.

---

## Workspace Behavior

### Region Required for Workspaces

**What:** `--region` is a required parameter when creating workspaces.

**Why:** Prevents "None" region errors in AWS CLI calls. Region is essential context for cloud operations.

---

## Adding New Tweaks

When adding OS customizations:
1. Document the change here
2. Add to release notes (CHANGELOG.md)
3. Explain the "why" - users should understand the reasoning
4. Provide instructions to revert if needed
