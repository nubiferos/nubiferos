# Calamares Warnings Fix

## Issues Fixed

Based on the segfault log, fixed all configuration warnings:

### 1. Branding Warnings ✅
**File:** `installer/calamares/branding/nubiferos/branding.desc`

Fixed warnings:
- `windowExpanding` - Added: `normal`
- `windowPlacement` - Added: `free`
- `windowSize` - Added: `800px,520px`
- `sidebar` position - Added: `left`
- `navigation` position - Added: `bottom`
- `slideshowAPI` - Already set to `2`

### 2. Keyboard Module Warning ✅
**File:** `installer/calamares/modules/keyboard.conf` (created)

Fixed warning:
- "No config file for keyboard found"
- Created minimal keyboard configuration with US layout defaults

### 3. Partition Module Warning ✅
**File:** `installer/calamares/modules/partition.conf`

Fixed warning:
- `defaultPartitionTableType` - Added: `gpt`

### 4. Users Module Warning ✅
**File:** `installer/calamares/modules/users.conf`

Fixed warning:
- Deprecated `userShell` - Replaced with `shellsFile: /etc/shells`
- Added `forbidden` hostname list

### 5. Welcome Module (Root Check) ✅
**File:** `installer/calamares/modules/welcome.conf`

Fixed:
- Removed `root` from requirements check (causes segfault)
- Kept `storage` and `ram` checks only

### 6. Finished Module ✅
**File:** `installer/calamares/modules/finished.conf`

Already using modern settings:
- `restartNowMode` instead of deprecated `restartNowEnabled`

## Expected Result

After rebuild, Calamares should:
- Launch without segfault
- Show no configuration warnings
- Display properly with correct branding

## Testing

```bash
# Rebuild ISO
sudo ./build-nubiferos.sh

# Test in QEMU
./testing/qemu-with-spice.sh

# Check for warnings
pkexec calamares -d 2>&1 | grep WARNING
```

Should see minimal or no warnings, and no segfault!
