# Kernel Installation Fix Summary

## Issue

After installing NubiferOS using Calamares, systems boot to GRUB but fail with:
```
/boot/vmlinuz not found
```

## Root Cause

The Calamares `packages.conf` didn't explicitly list kernel packages for installation. While Calamares typically handles kernel installation automatically, explicit package specification is more reliable.

## Fix Applied

Updated `installer/calamares/modules/packages.conf` to explicitly install:

```yaml
- linux-image-amd64    # Kernel
- linux-headers-amd64  # Kernel headers
- grub-pc              # GRUB bootloader
- grub-common          # GRUB common files
```

## For Users Experiencing This Issue

If you've already installed NubiferOS and are experiencing this boot issue:

**See: [docs/POST_INSTALL_BOOT_FIX.md](docs/POST_INSTALL_BOOT_FIX.md)**

That document provides step-by-step instructions to:
1. Boot from live ISO
2. Mount your installed system
3. Install the kernel
4. Fix GRUB
5. Reboot successfully

## For New Installations

Rebuild the ISO with this fix:

```bash
sudo ./build-nubiferos.sh
```

New installations will automatically include the kernel.

## Testing

After rebuilding, test the installation:

1. Boot from new ISO
2. Run Calamares installer
3. Complete installation
4. Reboot
5. Verify system boots without errors
6. Check kernel is installed: `uname -r`

## Files Modified

- `installer/calamares/modules/packages.conf` - Added kernel packages
- `docs/POST_INSTALL_BOOT_FIX.md` - New recovery guide
- `docs/BOOT_TROUBLESHOOTING.md` - Updated with post-install reference

## Related Documentation

- [Boot Troubleshooting Guide](docs/BOOT_TROUBLESHOOTING.md)
- [GRUB Bootloader Fix](docs/GRUB_BOOTLOADER_FIX.md)
- [Post-Installation Boot Fix](docs/POST_INSTALL_BOOT_FIX.md)
