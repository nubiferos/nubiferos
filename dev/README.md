# NubiferOS Development Workflow

Fast iteration without rebuilding the ISO every time.

## Overview

Instead of the slow cycle:
```
Change code → Build ISO (25 min) → Download → Boot VM → Test → Repeat
```

Use the fast cycle:
```
Change code → Push to VM (5 sec) → Test → Repeat
```

## Setup

### 1. Get a Working NubiferOS VM

After a successful ISO install, you have a running NubiferOS system. This becomes your dev VM.

### 2. Enable SSH on the VM

```bash
# On the VM
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Allow through firewall
sudo ufw allow ssh
```

### 3. Get VM IP Address

```bash
# On the VM
ip addr show | grep "inet "
# Look for the IP on your network interface (not 127.0.0.1)
```

### 4. Set Up SSH Key Authentication

```bash
# On your dev machine
ssh-copy-id installer@<VM_IP>

# Test it works without password
ssh installer@<VM_IP>
```

### 5. Configure Environment (Optional)

Add to your `~/.bashrc` or `~/.zshrc`:
```bash
export NUBIFER_VM_HOST=192.168.x.x  # Your VM's IP
export NUBIFER_VM_USER=installer
```

## Using dev-deploy.sh

### Deploy a Single Component

```bash
# Deploy GNOME extension
./dev/dev-deploy.sh context-indicator 192.168.1.100

# Deploy workspace manager service
./dev/dev-deploy.sh context-manager 192.168.1.100

# Deploy credential manager service
./dev/dev-deploy.sh credential-manager 192.168.1.100

# Deploy terminal prompt integration
./dev/dev-deploy.sh prompt 192.168.1.100
```

### Deploy All Components

```bash
./dev/dev-deploy.sh all 192.168.1.100
```

### Using Environment Variables

```bash
export NUBIFER_VM_HOST=192.168.1.100
./dev/dev-deploy.sh context-indicator
./dev/dev-deploy.sh context-manager
```

## Component Development

### Context Indicator (GNOME Extension)

**Location:** `components/context-indicator/gnome-extension/`

**Files:**
- `extension.js` - Main extension code
- `stylesheet.css` - Visual styling
- `metadata.json` - Extension metadata

**Deploy & Test:**
```bash
./dev/dev-deploy.sh context-indicator $VM_IP

# On VM: Restart GNOME Shell
# X11: Alt+F2, type 'r', Enter
# Wayland: Log out and back in
```

**View Logs:**
```bash
ssh $VM_IP "journalctl -f | grep -i nubiferos"
```

### Context Manager

**Location:** `components/context-manager/src/`

**Files:**
- `workspace_service.py` - Workspace management logic
- `dbus_interface.py` - D-Bus service interface
- `cli.py` - CLI tool (`nubifer-workspace`)
- `environment.py` - Environment variable handling

**Deploy & Test:**
```bash
./dev/dev-deploy.sh context-manager $VM_IP

# On VM: Test CLI
ssh $VM_IP "nubifer-workspace list"
ssh $VM_IP "nubifer-workspace create --name 'Test' --provider aws"
```

### Credential Manager

**Location:** `components/credential-manager/src/`

**Files:**
- `credential_service.py` - Credential storage logic
- `pass_backend.py` - Pass (password-store) integration
- `dbus_interface.py` - D-Bus service interface
- `cli.py` - CLI tool (`nubifer-creds`)

**Deploy & Test:**
```bash
./dev/dev-deploy.sh credential-manager $VM_IP

# On VM: Test CLI
ssh $VM_IP "nubifer-creds list"
```

## When to Rebuild the ISO

Only rebuild the ISO for:

1. **Calamares/Installer changes** - Partition configs, install sequence
2. **Boot process changes** - GRUB, Plymouth, initramfs
3. **Base system changes** - Kernel, core packages
4. **Final release testing** - Before publishing

For everything else, use `dev-deploy.sh`.

## VM Snapshots

Take snapshots before major changes:

### VMware Workstation
- VM → Snapshot → Take Snapshot

### VirtualBox
- Machine → Take Snapshot

### libvirt/QEMU
```bash
virsh snapshot-create-as nubiferos-dev "before-context-manager"
virsh snapshot-revert nubiferos-dev "before-context-manager"
```

## Troubleshooting

### SSH Connection Failed

```bash
# Check VM is running and has network
ping <VM_IP>

# Check SSH is running on VM
ssh installer@<VM_IP>  # If fails, on VM run:
sudo systemctl start ssh

# Check firewall
sudo ufw status  # Should show SSH allowed
```

### Extension Not Appearing

```bash
# Check extension is installed
ssh $VM_IP "gnome-extensions list | grep nubiferos"

# Enable it
ssh $VM_IP "gnome-extensions enable nubiferos-context@nubiferos.org"

# Check for errors
ssh $VM_IP "journalctl -b | grep -i nubiferos"
```

### D-Bus Service Not Running

```bash
# Check service status
ssh $VM_IP "systemctl --user status org.nubiferos.ContextManager"

# Restart it
ssh $VM_IP "systemctl --user restart org.nubiferos.ContextManager"

# Check logs
ssh $VM_IP "journalctl --user -u org.nubiferos.ContextManager -f"
```

## Tips

1. **Keep VM running** - Don't shut down between tests
2. **Use snapshots** - Easy rollback if something breaks
3. **Watch logs** - `journalctl -f` catches errors quickly
4. **Test incrementally** - Deploy one component, verify, then next
5. **Sync back to repo** - When changes work, update the build scripts

## File Locations on VM

| Component | Install Location |
|-----------|------------------|
| GNOME Extension | `~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org/` |
| Context Manager | `/usr/lib/nubiferos/context-manager/` |
| Credential Manager | `/usr/lib/nubiferos/credential-manager/` |
| CLI Tools | `/usr/local/bin/nubifer-workspace`, `/usr/local/bin/nubifer-creds` |
| Prompt Integration | `/etc/profile.d/nubiferos-prompt.sh` |
| Systemd Services | `~/.config/systemd/user/` |
