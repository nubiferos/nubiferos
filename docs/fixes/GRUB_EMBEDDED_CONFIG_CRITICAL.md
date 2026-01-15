# ⚠️ CRITICAL: GRUB Embedded Config - DO NOT MODIFY ⚠️

## 🔴 THIS CONFIGURATION HAS BEEN FIXED MULTIPLE TIMES - DO NOT CHANGE IT 🔴

**Last Fixed**: 2026-01-14 (3rd time)  
**File**: `build/build-iso.sh` (lines ~477-510)  
**Status**: ✅ WORKING - DO NOT TOUCH

---

## The ONLY Working Configuration

```bash
# Create embedded config in ISO directory
cat > "${ISO_DIR}/boot/grub/embedded.cfg" << 'EOF'
set root=(cd)
configfile (cd)/boot/grub/grub.cfg
set root=(cd0)
configfile (cd0)/boot/grub/grub.cfg
set root=(cd1)
configfile (cd1)/boot/grub/grub.cfg
echo "Error: Could not find grub.cfg on any CD device"
ls
EOF

# Use RELATIVE path in grub-mkstandalone
grub-mkstandalone \
    --format=i386-pc \
    --output="boot/grub/core.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt" \
    --modules="linux normal iso9660 biosdisk memdisk search search_fs_file configfile part_msdos part_gpt" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=boot/grub/embedded.cfg"
```

---

## Why This Works

1. **Sequential Device Tries**: GRUB silently fails on invalid devices and continues
2. **No Conditionals**: The `if [ -e ... ]` syntax doesn't work in embedded configs
3. **Relative Paths**: Config file must be in ISO directory, referenced with relative path
4. **Simple Logic**: Just try each device - (cd), (cd0), (cd1) - in order

---

## ❌ What DOESN'T Work (Don't Try These)

### ❌ Conditionals (BROKEN)
```bash
# THIS BREAKS - conditionals don't work in embedded config
if [ -e (cd)/boot/grub/grub.cfg ]; then
    set root=(cd)
elif [ -e (cd0)/boot/grub/grub.cfg ]; then
    set root=(cd0)
fi
```

**Why it fails**: Test commands execute before modules are fully loaded

### ❌ Search Commands (UNRELIABLE)
```bash
# THIS IS SLOW AND UNRELIABLE
search --file --set=root /boot/grub/grub.cfg
```

**Why it fails**: Search is slow, times out, and doesn't work consistently

### ❌ Absolute Paths (BROKEN)
```bash
# THIS BREAKS - file outside ISO directory
cat > "${WORK_DIR}/grub-early.cfg" << 'EOF'
...
EOF

grub-mkstandalone \
    "boot/grub/grub.cfg=${WORK_DIR}/grub-early.cfg"
```

**Why it fails**: grub-mkstandalone can't find files outside ISO when using relative paths

### ❌ Setting prefix First (BROKEN)
```bash
# THIS BREAKS - prefix set before root
set prefix=($root)/boot/grub
set root=(cd)
```

**Why it fails**: $root is undefined when prefix is set

---

## History of This Bug

### Attempt 1 (Commit 91d8acd - 2026-01-14)
- Used conditionals with `if [ -e ... ]`
- Used `${WORK_DIR}/grub-early.cfg` (absolute path)
- **Result**: FAILED - dropped to GRUB rescue shell

### Attempt 2 (Commit 2d95554 - 2026-01-14)
- Tried search command as fallback
- Still used conditionals
- **Result**: FAILED - same issue

### Attempt 3 (Commit 1004f3f - Previous working version)
- Sequential device tries (no conditionals)
- Relative path `boot/grub/embedded.cfg`
- **Result**: ✅ WORKED

### Current Fix (2026-01-14)
- Reverted to working sequential approach
- Added critical warnings in code
- Created this documentation
- **Result**: ✅ WORKING

---

## Testing Checklist

After any changes to GRUB config, test:

1. ✅ QEMU with KVM (uses `cd`)
2. ✅ VirtualBox (uses `cd0`)
3. ✅ VMware Workstation (uses `cd0`)
4. ✅ Physical hardware (varies)

**Test command**:
```bash
rm testing/nubiferos-test-disk.qcow2
./testing/qemu-with-spice.sh
```

**Expected**: Boot directly to GRUB menu, no manual commands needed

**If broken**: You'll see GRUB rescue shell and need to manually run:
```
set root=(cd)
set prefix=(cd)/boot/grub
configfile (cd)/boot/grub/grub.cfg
```

---

## Code Location

**File**: `build/build-iso.sh`

**BIOS Config**: Lines ~477-510
```bash
cat > "${ISO_DIR}/boot/grub/embedded.cfg" << 'EOF'
...
EOF
```

**EFI Config**: Lines ~520-535
```bash
cat > "${ISO_DIR}/EFI/boot/embedded.cfg" << 'EOF'
...
EOF
```

**Both must be identical** (except EFI uses different grub-mkstandalone format)

---

## Protection Mechanisms

1. **Code Comments**: Large warning block in `build/build-iso.sh`
2. **This Document**: Explains why changes break things
3. **Git History**: Reference commits that worked/failed
4. **Test Script**: `testing/qemu-with-spice.sh` for quick validation

---

## If You Must Change It

**DON'T.**

But if you absolutely must:

1. Read this entire document first
2. Test on ALL platforms (QEMU, VirtualBox, VMware, physical)
3. Document why the change is needed
4. Keep the sequential device-try approach
5. Never use conditionals in embedded config
6. Always use relative paths for embedded.cfg

---

## Related Files

- `build/build-iso.sh` - Main build script with GRUB config
- `docs/fixes/GRUB_MODULE_LOADING_FIX.md` - Original fix documentation
- `testing/qemu-with-spice.sh` - Test script
- `.github/workflows/build-iso.yml` - CI build workflow

---

## Summary

**The Rule**: Sequential device tries, no conditionals, relative paths.

**The Working Config**:
```bash
set root=(cd)
configfile (cd)/boot/grub/grub.cfg
set root=(cd0)
configfile (cd0)/boot/grub/grub.cfg
set root=(cd1)
configfile (cd1)/boot/grub/grub.cfg
```

**Don't overthink it. This works. Leave it alone.**

---

## Commit References

- ✅ Working: `1004f3f` - "fix: properly embed grub.cfg in GRUB core image"
- ❌ Broken: `91d8acd` - "testing fix for embedded on iso" (used conditionals)
- ❌ Broken: `2d95554` - "testing another fix" (still used conditionals)
- ✅ Fixed: Current commit - Reverted to sequential approach

---

**Last Updated**: 2026-01-14  
**Maintainer**: Jesse Toporowski  
**Status**: 🔴 CRITICAL - DO NOT MODIFY WITHOUT TESTING ON ALL PLATFORMS
