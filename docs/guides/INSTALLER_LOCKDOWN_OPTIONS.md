# Installer Lockdown Options

**Status**: IMPLEMENTED - Option 3 (Minimal) deployed  
**Date**: 2026-02-04  
**Purpose**: Prevent users from accessing live environment, force installer-only usage

---

## Security Requirement

The live CD environment is a security vulnerability because:
- Users can bypass encryption by accessing the live environment
- Users can explore the system without installing
- Violates the security model requiring full disk encryption

**Solution**: Lock down the live environment so users can ONLY run the installer.

**Implementation**: Option 3 (Direct Boot to Calamares) was implemented. See:
- `build/install-kiosk-packages.sh` - Minimal package installation
- `build/configure-kiosk-session.sh` - Session configuration
- `docs/testing/KIOSK_SECURITY_TESTS.md` - Security test checklist

---

## Option 1: Auto-launch Calamares in Kiosk Mode (RECOMMENDED)

### Overview
Configure the session to launch Calamares fullscreen immediately, blocking all access to the desktop.

### Implementation Steps

1. **Auto-login Configuration**
   - Configure GDM/LightDM to auto-login the `installer` user
   - No password prompt, boots directly to session

2. **Custom Session File**
   - Create `/usr/share/xsessions/calamares-installer.desktop`
   - Set as default session for installer user
   - Launches custom script instead of GNOME Shell

3. **Kiosk Launch Script**
   ```bash
   #!/bin/bash
   # /usr/local/bin/calamares-kiosk.sh
   
   # Disable all keyboard shortcuts
   gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "[]"
   gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "[]"
   gsettings set org.gnome.desktop.wm.keybindings close "[]"
   gsettings set org.gnome.desktop.wm.keybindings minimize "[]"
   
   # Disable virtual terminal switching
   setxkbmap -option srvrkeys:none
   
   # Launch Calamares fullscreen
   calamares --fullscreen --kiosk
   
   # When Calamares exits, reboot immediately
   systemctl reboot
   ```

4. **Window Manager Lockdown**
   - Use Mutter/GNOME Shell in kiosk mode
   - Disable all panels, menus, and controls
   - Force Calamares window to stay on top
   - Disable Alt+Tab, Alt+F4, Super key

5. **Disable Virtual Terminals**
   - Mask getty services
   - Disable Ctrl+Alt+F1-F6 switching
   - Only allow the X session

### Advantages
- Professional appearance (GUI installer)
- User-friendly
- Familiar GNOME environment (but locked down)
- Easy to implement

### Disadvantages
- Still loads full GNOME (heavier)
- Potential for escape if lockdown has holes
- More attack surface

---

## Option 3: Direct Boot to Calamares (MINIMAL)

### Overview
Skip the desktop environment entirely. Boot to minimal X server with only Calamares running.

### Implementation Steps

1. **Minimal X Configuration**
   - Install only: xorg, xinit, basic drivers
   - NO desktop environment
   - NO window manager (or minimal like openbox)

2. **Auto-login to Console**
   - Configure getty to auto-login installer user
   - No graphical login manager

3. **Auto-start X with Calamares**
   ```bash
   # /home/installer/.bash_profile
   if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
       exec startx
   fi
   ```

4. **Minimal .xinitrc**
   ```bash
   #!/bin/bash
   # /home/installer/.xinitrc
   
   # Disable screen blanking
   xset s off
   xset -dpms
   
   # Set background color (no wallpaper)
   xsetroot -solid "#2e3440"
   
   # Launch Calamares (only thing running)
   exec calamares
   
   # When Calamares exits, X exits, triggering reboot
   ```

5. **Reboot on Exit**
   ```bash
   # /home/installer/.bash_logout
   sudo systemctl reboot
   ```

6. **Disable Virtual Terminals**
   - Mask all getty services except tty1
   - Disable Ctrl+Alt+F2-F6

### Advantages
- Minimal resource usage
- Smaller attack surface
- Faster boot time
- Harder to escape (nothing else running)
- Cleaner approach

### Disadvantages
- Less polished appearance
- No window decorations
- Calamares might not look as good without WM
- Requires testing to ensure Calamares works without WM

---

## Comparison

| Feature | Option 1 (Kiosk) | Option 3 (Minimal) |
|---------|------------------|-------------------|
| Resource Usage | High (full GNOME) | Low (X only) |
| Security | Good (if locked properly) | Better (less to exploit) |
| User Experience | Professional | Basic but functional |
| Implementation | Medium complexity | Low complexity |
| Boot Time | Slower | Faster |
| Escape Risk | Medium | Low |

---

## Recommended Approach

**Start with Option 3 (Minimal)**, then add Option 1 features if needed:

1. Implement Option 3 first (minimal X + Calamares)
2. Test that it works and is secure
3. If UX is poor, add minimal window manager (openbox)
4. If still not good enough, upgrade to Option 1 (full kiosk)

This gives you the most secure baseline, then you can add polish as needed.

---

## Additional Security Measures (Both Options)

1. **Disable Root Access**
   - Lock root password
   - Disable sudo for installer user
   - No way to get a shell

2. **Disable Terminal Access**
   - Remove all terminal emulators
   - Disable Ctrl+Alt+T
   - Disable virtual terminals

3. **Network Restrictions**
   - Only allow connections needed for installation
   - Block SSH server
   - Firewall rules

4. **Filesystem Restrictions**
   - Mount live filesystem read-only where possible
   - No persistence
   - Clear any temporary files on reboot

5. **Timeout/Watchdog**
   - If installer is idle for X minutes, reboot
   - Prevent someone from leaving it running

---

## Implementation Checklist

When ready to implement:

- [ ] Choose Option 1 or Option 3
- [ ] Create session/xinitrc files
- [ ] Configure auto-login
- [ ] Disable virtual terminals
- [ ] Disable keyboard shortcuts
- [ ] Test escape attempts
- [ ] Test Calamares functionality
- [ ] Test on BIOS and UEFI
- [ ] Document for users
- [ ] Update security model docs

---

## Testing Checklist

Before considering it secure:

- [ ] Try to access desktop/shell
- [ ] Try Ctrl+Alt+F1-F6
- [ ] Try Alt+Tab
- [ ] Try Alt+F4
- [ ] Try Super key
- [ ] Try right-click menus
- [ ] Try keyboard shortcuts
- [ ] Try to open terminal
- [ ] Try to access file browser
- [ ] Verify reboot on Calamares exit

---

**Status**: IMPLEMENTED  
**Next Step**: Run security tests from `docs/testing/KIOSK_SECURITY_TESTS.md`  
**Priority**: COMPLETE

