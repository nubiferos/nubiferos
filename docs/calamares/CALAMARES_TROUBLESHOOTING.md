# Calamares Systematic Troubleshooting

## Current Status
Calamares 3.3.8 still segfaults after "Checking module requirements"

## Troubleshooting Strategy

### Phase 1: Minimal Configuration ✅ IN PROGRESS
**Goal:** Get Calamares to launch with absolute minimum config

Changes:
1. ✅ Switch to default branding (not nubiferos)
2. ✅ Disable packagechooser module
3. ⏳ Test if it launches

**Test:**
```bash
sudo ./build-nubiferos.sh
# In VM:
pkexec calamares -d
```

**Expected:** Calamares should launch with default Debian branding

---

### Phase 2: Add Back Modules (If Phase 1 works)
Add modules back one at a time:

1. Enable packagechooser
2. Test each time

---

### Phase 3: Add Back Branding (If Phase 2 works)
Create minimal nubiferos branding:

1. Start with absolute minimum branding.desc
2. Add settings one by one:
   - Basic strings only
   - Add images
   - Add stylesheet
   - Add sidebar/navigation
   - Add slideshow (last!)

---

### Phase 4: Identify Root Cause
Once we find what breaks it, we know what to fix or remove.

## Minimal Branding Template

If default branding works, start with this minimal nubiferos branding:

```yaml
---
componentName: nubiferos

strings:
    productName: "NubiferOS"
    version: "1.0"
    bootloaderEntryName: "NubiferOS"

# That's it! No images, no slideshow, no styling
```

Then add back piece by piece.

## Known Issues to Watch For

1. **Slideshow** - QML threading issues
2. **PackageChooser** - Complex module, might have bugs
3. **Custom images** - Path issues
4. **Stylesheet** - Qt parsing issues

## Quick Test Commands

```bash
# Check Calamares version
calamares --version

# Run with debug
pkexec calamares -d 2>&1 | tee calamares.log

# Check for specific errors
grep -i "error\|warning\|segfault" calamares.log
```
