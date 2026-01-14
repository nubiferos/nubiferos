# Live User Quick Reference

## TL;DR

You're seeing two users because:
- **live** - Created by our build scripts (use this one)
- **installer** - Created by Debian's live-boot system

Both should work, but **use "live"** with password **"live"**.

## Quick Fixes

### If Calamares doesn't autostart:

```bash
# Run this in the live environment
pkexec calamares
```

### If you want to check which users exist:

```bash
./testing/check-users.sh
```

### If you want to test Calamares:

```bash
./testing/quick-calamares-test.sh
```

## What We Fixed

1. **Added autostart configuration** - Calamares now launches automatically
2. **Set explicit username** - Boot parameters now specify `username=live`
3. **Created test scripts** - Easy ways to verify and troubleshoot

## After Rebuilding

The next ISO build will:
- Explicitly use "live" as the username
- Auto-launch Calamares on login
- Have both users configured (just in case)

## More Info

- `docs/LIVE_USER_EXPLANATION.md` - Full explanation of the user situation
- `docs/CALAMARES_TESTING.md` - Complete testing guide
- `CALAMARES_FIX_SUMMARY.md` - Detailed fix summary
