# Calamares Installer Decision Point

## Current Status
Calamares continues to segfault despite multiple fixes:
- ✅ Fixed power check
- ✅ Added QML dependencies  
- ✅ Fixed deprecated config warnings
- ✅ Disabled slideshow
- ❌ Still crashes with QThread errors

## Root Cause
The segfault is a **Qt/QML threading issue** in VirtualBox:
- "QThread set priority: cannot set priority, thread is not running"
- This is a known Calamares bug in virtualized environments
- Affects VirtualBox specifically (QEMU/KVM usually works)

## Options

### Option 1: Switch to Debian Installer (d-i) ✅ RECOMMENDED
**Pros:**
- Rock solid, battle-tested
- Works perfectly in VMs
- No Qt/QML dependencies
- Smaller ISO size
- Faster installation

**Cons:**
- Text-based UI (less pretty)
- No custom branding
- Less user-friendly

**Effort:** Low (2-3 hours)

### Option 2: Use Preseed for Automated Install
**Pros:**
- Fully automated
- No user interaction needed
- Perfect for cloud deployments
- Works with d-i

**Cons:**
- No GUI at all
- Requires pre-configuration

**Effort:** Medium (4-6 hours)

### Option 3: Keep Fighting Calamares
**Pros:**
- Pretty GUI
- Custom branding
- Modern look

**Cons:**
- Unstable in VMs
- Complex to debug
- May never work reliably
- Wastes more time

**Effort:** High (unknown, could be days)

### Option 4: Test in QEMU Instead
**Pros:**
- Calamares might work in QEMU
- Better VM support
- Faster than VirtualBox

**Cons:**
- Requires different test setup
- May still have issues

**Effort:** Low (30 minutes to test)

## Recommendation

**Try Option 4 first (QEMU test), then switch to Option 1 (Debian Installer)**

### Why?
1. **QEMU Test (30 min):** Quick check if it's VirtualBox-specific
   ```bash
   qemu-system-x86_64 -cdrom output/nubiferos-*.iso -m 4096 -enable-kvm
   ```

2. **If still crashes → Debian Installer:** 
   - Proven, reliable, works everywhere
   - You can still have custom packages, security hardening, etc.
   - Just loses the pretty GUI

## Debian Installer Implementation

If switching to d-i:

1. Remove Calamares from build
2. Add debian-installer to ISO
3. Create preseed file for defaults
4. Keep all your custom packages/configs
5. Post-install scripts handle the rest

**Result:** Same final system, different installer.

## Decision

What do you want to do?

- [ ] Test in QEMU (quick)
- [ ] Switch to Debian Installer (reliable)
- [ ] Keep debugging Calamares (risky)
- [ ] Use preseed automation (advanced)
