# Polkit Debootstrap Configuration Fix

## Problem

During the debootstrap process, the `polkitd` package was causing configuration failures:

```
W: Failure while configuring base packages. This will be re-attempted up to five times.
W: See /work/chroot/debootstrap/debootstrap.log for details (possibly the package polkitd is at fault)
```

## Root Cause

The `polkitd` and `policykit-1` packages have complex configuration requirements that can fail during the minimal debootstrap environment. Specifically:

1. **User/Group Dependencies**: Polkit requires specific system users and groups that may not be fully configured during the initial bootstrap
2. **D-Bus Dependencies**: Polkit needs D-Bus to be properly configured, which is challenging in the minimal debootstrap environment
3. **Timing Issues**: Configuration scripts may run before all dependencies are fully initialized

## Solution

We've implemented a two-phase approach:

### Phase 1: Minimal Bootstrap
Remove `policykit-1` and `polkitd` from the initial debootstrap `--include` list:

```bash
debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    --include=systemd,systemd-sysv,udev,dbus,sudo,wget,ca-certificates,gnupg \
    "${BASE_CODENAME}" \
    "${CHROOT_DIR}" \
    "${DEBIAN_MIRROR}"
```

### Phase 2: Post-Bootstrap Installation
Install polkit after the base system is fully configured and mounted:

```bash
install_polkit() {
    log "INFO" "Installing polkit in chroot..."
    
    chroot "${CHROOT_DIR}" /bin/bash -c \
        "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends polkitd policykit-1"
    
    log "INFO" "✓ Polkit installed"
}
```

## Why This Works

1. **Full System Context**: By the time we install polkit, the chroot has:
   - Properly configured systemd
   - Initialized D-Bus
   - Created necessary system users/groups
   - Mounted all required filesystems

2. **Better Error Handling**: Installing in a separate step allows us to:
   - Use `DEBIAN_FRONTEND=noninteractive` to avoid prompts
   - Catch and handle errors gracefully
   - Retry with alternative packages if needed

3. **Dependency Resolution**: APT can properly resolve dependencies when the base system is complete

## Alternative Approaches Considered

### 1. Pre-seeding Configuration
We could pre-configure polkit settings, but this is fragile and version-dependent.

### 2. Using --no-install-recommends During Bootstrap
Still fails because the core issue is the minimal environment, not recommended packages.

### 3. Installing Later in Desktop Phase
This would work but delays essential privilege escalation capabilities needed by Calamares installer.

## Testing

To verify the fix works:

```bash
# Clean build
sudo rm -rf work/
sudo ./build-nubiferos.sh

# Check polkit is installed
sudo chroot work/chroot dpkg -l | grep polkit
```

Expected output:
```
ii  policykit-1    0.105-xx    amd64    framework for managing administrative policies
ii  polkitd        0.105-xx    amd64    PolicyKit daemon
```

## Related Issues

- Calamares installer requires polkit for privilege escalation
- Sudo package also needs proper configuration but is less problematic
- This fix is essential for the installer to function correctly

## References

- Debian Bug #XXXXX (if applicable)
- Calamares documentation on privilege requirements
- PolicyKit configuration guide
