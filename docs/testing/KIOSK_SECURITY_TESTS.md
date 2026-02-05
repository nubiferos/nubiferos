# Kiosk Mode Security Tests

This document provides a manual security test checklist for verifying the NubiferOS installer kiosk mode is properly locked down.

## Overview

The kiosk mode implementation prevents users from:
- Accessing a desktop environment
- Opening terminal emulators
- Switching to virtual terminals
- Using keyboard shortcuts to escape
- Accessing any application other than Calamares

## Test Environment

**Requirements:**
- Built NubiferOS ISO with kiosk mode enabled
- QEMU or physical hardware for testing
- Keyboard and mouse access

**Test Command (QEMU):**
```bash
qemu-system-x86_64 \
    -cdrom output/nubiferos-*.iso \
    -m 4096 \
    -enable-kvm \
    -boot d
```

## Security Test Checklist

### Visual Verification

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| VIS-01 | Boot ISO and wait for session | Only Calamares visible, no desktop | ☐ |
| VIS-02 | Check for desktop icons | No desktop icons visible | ☐ |
| VIS-03 | Check for taskbar/panel | No taskbar or panel visible | ☐ |
| VIS-04 | Check background | Solid color (#2e3440), no wallpaper | ☐ |

### Virtual Terminal Tests

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| VT-01 | Press Ctrl+Alt+F1 | Nothing happens, stays on Calamares | ☐ |
| VT-02 | Press Ctrl+Alt+F2 | Nothing happens, stays on Calamares | ☐ |
| VT-03 | Press Ctrl+Alt+F3 | Nothing happens, stays on Calamares | ☐ |
| VT-04 | Press Ctrl+Alt+F4 | Nothing happens, stays on Calamares | ☐ |
| VT-05 | Press Ctrl+Alt+F5 | Nothing happens, stays on Calamares | ☐ |
| VT-06 | Press Ctrl+Alt+F6 | Nothing happens, stays on Calamares | ☐ |
| VT-07 | Press Ctrl+Alt+F7 | Nothing happens, stays on Calamares | ☐ |

### Keyboard Shortcut Tests

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| KEY-01 | Press Alt+Tab | Nothing happens | ☐ |
| KEY-02 | Press Alt+F4 | Nothing happens OR system reboots | ☐ |
| KEY-03 | Press Super key (Windows key) | Nothing happens | ☐ |
| KEY-04 | Press Ctrl+Alt+Delete | Nothing happens | ☐ |
| KEY-05 | Press Ctrl+Alt+T | No terminal opens | ☐ |
| KEY-06 | Press Ctrl+Alt+Backspace | Nothing happens (X doesn't restart) | ☐ |
| KEY-07 | Press Alt+SysRq+R | Nothing happens (SysRq disabled) | ☐ |
| KEY-08 | Press F11 (fullscreen toggle) | Nothing happens | ☐ |

### Mouse Interaction Tests

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| MOU-01 | Right-click on background | No context menu appears | ☐ |
| MOU-02 | Click on background | Nothing happens | ☐ |
| MOU-03 | Double-click on background | Nothing happens | ☐ |
| MOU-04 | Middle-click on background | Nothing happens | ☐ |

### Exit Behavior Tests

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| EXIT-01 | Cancel installation in Calamares | System reboots automatically | ☐ |
| EXIT-02 | Complete installation successfully | System reboots automatically | ☐ |
| EXIT-03 | Force-close Calamares (if possible) | System reboots automatically | ☐ |
| EXIT-04 | Wait for X session timeout | No screensaver, stays on Calamares | ☐ |

### Application Access Tests

| Test ID | Test Description | Expected Result | Pass/Fail |
|---------|------------------|-----------------|-----------|
| APP-01 | Try to open terminal | No terminal available | ☐ |
| APP-02 | Try to open file browser | No file browser available | ☐ |
| APP-03 | Try to open web browser | No web browser available | ☐ |
| APP-04 | Try to open text editor | No text editor available | ☐ |
| APP-05 | Try to access Activities overview | No Activities overview | ☐ |

## Test Results Summary

**Date:** _______________

**Tester:** _______________

**ISO Version:** _______________

**Test Environment:** ☐ QEMU  ☐ VirtualBox  ☐ Physical Hardware

**Boot Mode:** ☐ BIOS  ☐ UEFI

### Results

| Category | Passed | Failed | Notes |
|----------|--------|--------|-------|
| Visual Verification | /4 | | |
| Virtual Terminal | /7 | | |
| Keyboard Shortcuts | /8 | | |
| Mouse Interaction | /4 | | |
| Exit Behavior | /4 | | |
| Application Access | /5 | | |
| **TOTAL** | **/32** | | |

### Overall Status

☐ **PASS** - All tests passed, kiosk mode is secure

☐ **FAIL** - One or more tests failed, see notes above

### Notes

_Document any issues, observations, or recommendations here:_

---

## Troubleshooting

### If VT switching works (VT tests fail)

1. Check `/etc/X11/xorg.conf.d/10-no-vt-switch.conf` exists
2. Verify `DontVTSwitch` is set to `true`
3. Check getty services are masked: `systemctl status getty@tty2`

### If keyboard shortcuts work (KEY tests fail)

1. Check `.xinitrc` includes `setxkbmap -option srvrkeys:none`
2. Verify no window manager is running
3. Check for GNOME Shell or other DE processes

### If system doesn't reboot on exit (EXIT tests fail)

1. Check `.xinitrc` includes reboot command after Calamares
2. Verify sudoers allows passwordless reboot
3. Check `.bash_logout` exists as fallback

### If applications are accessible (APP tests fail)

1. Verify forbidden packages are not installed
2. Run `build/validate-kiosk-config.sh` to check
3. Rebuild ISO with `install-kiosk-packages.sh`

---

**Last Updated:** 2026-02-04
**Document Version:** 1.0
