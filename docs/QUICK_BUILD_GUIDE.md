# Quick Build Guide

## Build the ISO (One Command)

```bash
sudo ./build-nubiferos.sh
```

This will:
1. Check dependencies
2. Check disk space
3. Build the ISO (~35-55 minutes)
4. Create `output/nubiferos-1.0-amd64.iso`

## Test in VirtualBox

### Option 1: GUI
1. Open VirtualBox
2. Click "New"
3. Name: NubiferOS-Test
4. Type: Linux
5. Version: Debian (64-bit)
6. RAM: 4096 MB
7. Create virtual hard disk: 20 GB
8. Settings → Storage → Add optical drive
9. Select `output/nubiferos-1.0-amd64.iso`
10. Start VM

### Option 2: Command Line
```bash
# Quick VM creation script
VBoxManage createvm --name "NubiferOS" --ostype Debian_64 --register
VBoxManage modifyvm "NubiferOS" --memory 4096 --vram 128 --cpus 2
VBoxManage createhd --filename ~/VirtualBox\ VMs/NubiferOS/disk.vdi --size 20480
VBoxManage storagectl "NubiferOS" --name "SATA" --add sata
VBoxManage storageattach "NubiferOS" --storagectl "SATA" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/NubiferOS/disk.vdi
VBoxManage storagectl "NubiferOS" --name "IDE" --add ide
VBoxManage storageattach "NubiferOS" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium $(pwd)/output/nubiferos-1.0-amd64.iso
VBoxManage startvm "NubiferOS"
```

## What to Test

### 1. Boot and Desktop
- [ ] ISO boots successfully
- [ ] GNOME desktop loads
- [ ] Can log in
- [ ] Desktop is responsive

### 2. Workspace Manager
```bash
# Open terminal
nubifer-workspace create --name "AWS Test" --provider aws --account-id 123
nubifer-workspace list
nubifer-workspace switch <workspace-id>
```

### 3. GNOME Virtual Desktop Integration
```bash
# Create multiple workspaces
nubifer-workspace create --name "AWS" --provider aws --account-id 111
nubifer-workspace create --name "Azure" --provider azure --account-id 222
nubifer-workspace create --name "GCP" --provider gcp --account-id 333

# Switch and watch desktops change!
nubifer-workspace switch <aws-id>
nubifer-workspace switch <azure-id>
nubifer-workspace switch <gcp-id>

# Try keyboard shortcuts
# Super+1, Super+2, Super+3
```

### 4. Terminal Prompt
```bash
# After switching workspace, check prompt shows context
# Should see: [☁️ account-name] user@host:~$
```

### 5. Wallpapers
- [ ] Wallpaper changes when switching workspaces
- [ ] AWS = Orange theme
- [ ] Azure = Blue theme
- [ ] GCP = Multi-color theme

## Feedback Checklist

While testing, note:
- [ ] What works well?
- [ ] What doesn't work?
- [ ] Any error messages?
- [ ] Performance issues?
- [ ] UI/UX improvements?
- [ ] Missing features?

## Common Issues

### ISO won't boot
- Check VM settings (64-bit, VT-x enabled)
- Try increasing RAM to 4GB+

### Desktop doesn't load
- Wait 2-3 minutes (first boot is slow)
- Check VM has enough RAM

### Workspace manager not found
- Open terminal
- Run: `which nubifer-workspace`
- Should be in `/usr/local/bin/`

### Desktop switching doesn't work
- Install: `sudo apt-get install wmctrl xdotool`
- Or it will use gdbus (Wayland fallback)

## Quick Commands Reference

```bash
# Workspace management
nubifer-workspace create --name "Name" --provider aws --account-id 123
nubifer-workspace list
nubifer-workspace switch <id>
nubifer-workspace current

# GNOME integration
nubifer-desktop setup
nubifer-desktop list
nubifer-desktop assign <workspace-id> --desktop 2

# Credential management
nubifer-creds add --type aws --name prod
nubifer-creds list

# System info
nubifer-update-checker
nubifer-setup-wizard
```

## Build Time

Expect **35-55 minutes** for full build:
- Download: 5-10 min
- Extract: 10-15 min
- Install: 15-20 min
- ISO creation: 5-10 min

## Output

```
output/
├── nubiferos-1.0-amd64.iso          # ~2-3GB
└── nubiferos-1.0-amd64.iso.sha256   # Checksum
```

## Next Steps

1. **Build**: `sudo ./build-nubiferos.sh`
2. **Test**: Boot in VirtualBox
3. **Feedback**: Note what works/doesn't work
4. **Iterate**: Fix issues and rebuild
5. **Enjoy**: Use NubiferOS!

---

**Ready to build?** Run: `sudo ./build-nubiferos.sh`
