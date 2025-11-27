# QEMU Testing Guide

## Quick Start

### Option 1: Standard QEMU (No clipboard)
```bash
qemu-system-x86_64 -cdrom output/nubiferos-*.iso -m 4096 -enable-kvm
```

### Option 2: With SPICE (Clipboard support)
```bash
# Start QEMU with SPICE
./testing/qemu-with-spice.sh

# In another terminal, connect with SPICE client
spicy --uri=spice://localhost:5930
```

### Option 3: With VNC (Remote access)
```bash
# Start QEMU with VNC
./testing/qemu-with-vnc.sh

# In another terminal, connect with VNC
vncviewer localhost:0
```

### Option 4: Debug Mode (Capture logs)
```bash
# Start QEMU with logging
./testing/qemu-debug.sh

# In another terminal, watch logs
tail -f logs/qemu/boot_*.log
```

## Clipboard Sharing with SPICE

### Install SPICE Client
```bash
# Ubuntu/Debian
sudo apt install spice-client-gtk

# Or use virt-viewer
sudo apt install virt-viewer
```

### Using SPICE
1. Start QEMU with SPICE:
   ```bash
   ./testing/qemu-with-spice.sh
   ```

2. Connect with SPICE client:
   ```bash
   spicy --uri=spice://localhost:5930
   ```

3. Clipboard works automatically:
   - Copy in guest: Ctrl+C
   - Paste in guest: Ctrl+V
   - Copy/paste between host and guest works seamlessly

## Capturing Logs

### Method 1: Serial Console to File
```bash
./testing/qemu-debug.sh

# View logs
cat logs/qemu/boot_*.log

# Search for errors
grep -i error logs/qemu/boot_*.log
grep -i calamares logs/qemu/boot_*.log
```

### Method 2: Inside the VM
Once booted, open terminal in the VM:
```bash
# View system logs
journalctl -xe > /tmp/system.log

# View Calamares logs
journalctl -xe | grep calamares > /tmp/calamares.log

# Copy to shared location (if you set up shared folder)
```

### Method 3: Screenshot
In QEMU window:
- Press `Ctrl+Alt+Shift+S` to take screenshot
- Saved to current directory

## Shared Folder (Alternative to Clipboard)

### Setup Shared Folder
```bash
# Create shared directory
mkdir -p ~/qemu-shared

# Start QEMU with shared folder
qemu-system-x86_64 \
    -enable-kvm \
    -cdrom output/nubiferos-*.iso \
    -m 4096 \
    -virtfs local,path=~/qemu-shared,mount_tag=host0,security_model=passthrough,id=host0
```

### Mount in Guest
```bash
# In the VM
sudo mkdir -p /mnt/shared
sudo mount -t 9p -o trans=virtio,version=9p2000.L host0 /mnt/shared

# Copy logs
journalctl -xe > /mnt/shared/system.log
```

## Quick Commands

### Start with specific options
```bash
# More RAM
./testing/qemu-with-spice.sh -m 8192

# More CPUs
./testing/qemu-with-spice.sh -smp 4

# Specific ISO
./testing/qemu-with-spice.sh path/to/custom.iso
```

### QEMU Monitor Commands
Press `Ctrl+Alt+2` to access monitor:
```
info status          # VM status
info registers       # CPU registers
info block           # Block devices
screendump file.ppm  # Take screenshot
quit                 # Exit QEMU
```

Press `Ctrl+Alt+1` to return to VM display

## Troubleshooting

### SPICE client won't connect
```bash
# Check if QEMU is listening
netstat -tlnp | grep 5930

# Try with remote-viewer instead
remote-viewer spice://localhost:5930
```

### No KVM acceleration
```bash
# Check KVM availability
ls -la /dev/kvm

# Add user to kvm group
sudo usermod -a -G kvm $USER
# Log out and back in
```

### Clipboard not working in SPICE
1. Ensure spice-vdagent is running in guest:
   ```bash
   systemctl status spice-vdagent
   ```

2. Restart the agent:
   ```bash
   sudo systemctl restart spice-vdagent
   ```

## Best Practices

1. **For Development**: Use SPICE for clipboard support
2. **For CI/CD**: Use VNC or serial console logging
3. **For Debugging**: Use debug mode with serial console
4. **For Screenshots**: Use QEMU's built-in screenshot feature

## Scripts Summary

- `qemu-with-spice.sh` - Full SPICE support with clipboard
- `qemu-with-vnc.sh` - VNC server for remote access
- `qemu-debug.sh` - Serial console logging for debugging
- All scripts auto-detect ISO in output/ directory
- All scripts support passing additional QEMU options

## Example Workflow

```bash
# 1. Build ISO
sudo ./build-nubiferos.sh

# 2. Test with SPICE (for interactive testing)
./testing/qemu-with-spice.sh

# 3. In another terminal, connect
spicy --uri=spice://localhost:5930

# 4. Test Calamares, copy any errors with clipboard

# 5. For automated testing, use debug mode
./testing/qemu-debug.sh

# 6. Check logs
cat logs/qemu/boot_*.log | grep -i error
```
