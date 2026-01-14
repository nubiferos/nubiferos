# Context Manager systemd Service - Quick Start

This guide helps you quickly set up and test the NubiferOS Context Manager as a systemd user service.

## Prerequisites

- NubiferOS Context Manager installed (`sudo ./install.sh` from parent directory)
- Python 3 with D-Bus bindings (`python3-dbus`, `python3-gi`)
- systemd user session running

## Quick Setup

### 1. Install the Service

From the `components/context-manager` directory:

```bash
# Install the context manager (includes systemd service)
sudo ./install.sh
```

This will:
- Install Python dependencies
- Copy service files to `~/.config/systemd/user/`
- Copy D-Bus activation file to `~/.local/share/dbus-1/services/`
- Create CLI wrapper at `/usr/local/bin/nubifer-workspace`

### 2. Start the Service

```bash
# Reload systemd to recognize new service
systemctl --user daemon-reload

# Start the service
systemctl --user start nubifer-context-manager.service

# Check status
systemctl --user status nubifer-context-manager.service
```

### 3. Enable Auto-Start (Optional)

To start the service automatically on login:

```bash
systemctl --user enable nubifer-context-manager.service
```

### 4. Test the Service

Run the test script:

```bash
cd systemd
./test-service.sh
```

Or test manually:

```bash
# List workspaces (should work even if empty)
nubifer-workspace list

# Create a test workspace
nubifer-workspace create \
  --name "AWS Test" \
  --provider aws \
  --account-id 123456789012 \
  --region us-east-1

# List again to see the new workspace
nubifer-workspace list
```

## Verify D-Bus Integration

Check if the D-Bus service is registered:

```bash
dbus-send --session --print-reply \
  --dest=org.freedesktop.DBus \
  /org/freedesktop/DBus \
  org.freedesktop.DBus.ListNames | grep nubiferos
```

You should see: `string "org.nubiferos.ContextManager"`

## View Logs

```bash
# Follow logs in real-time
journalctl --user -u nubifer-context-manager.service -f

# View last 50 lines
journalctl --user -u nubifer-context-manager.service -n 50
```

## Common Commands

```bash
# Service management
systemctl --user start nubifer-context-manager.service
systemctl --user stop nubifer-context-manager.service
systemctl --user restart nubifer-context-manager.service
systemctl --user status nubifer-context-manager.service

# Enable/disable auto-start
systemctl --user enable nubifer-context-manager.service
systemctl --user disable nubifer-context-manager.service

# View logs
journalctl --user -u nubifer-context-manager.service -f
```

## Workspace Management

```bash
# Create workspace
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --region us-east-1

# List workspaces
nubifer-workspace list

# Switch workspace
nubifer-workspace switch <workspace-id>

# Get current workspace
nubifer-workspace current

# Set read-only mode
nubifer-workspace set-readonly <workspace-id> true

# Delete workspace
nubifer-workspace delete <workspace-id>
```

## Troubleshooting

### Service Won't Start

1. Check the logs:
   ```bash
   journalctl --user -u nubifer-context-manager.service -n 50
   ```

2. Verify Python dependencies:
   ```bash
   python3 -c "import dbus; import gi; print('OK')"
   ```

3. Check if D-Bus session is running:
   ```bash
   systemctl --user status dbus.service
   ```

### D-Bus Service Not Found

1. Verify D-Bus service file is installed:
   ```bash
   ls -l ~/.local/share/dbus-1/services/org.nubiferos.ContextManager.service
   ```

2. Restart D-Bus (or log out and back in):
   ```bash
   systemctl --user restart dbus.service
   ```

### CLI Command Not Found

1. Check if wrapper is installed:
   ```bash
   ls -l /usr/local/bin/nubifer-workspace
   ```

2. Verify it's in your PATH:
   ```bash
   echo $PATH | grep /usr/local/bin
   ```

3. Re-run installation:
   ```bash
   cd components/context-manager
   sudo ./install.sh
   ```

### Permission Errors

The service needs write access to `~/.config/nubiferos/`. Check permissions:

```bash
ls -ld ~/.config/nubiferos
chmod 700 ~/.config/nubiferos
```

## Manual Mode (Without systemd)

If you prefer to run without systemd, you can start the service manually:

```bash
# Start D-Bus service in foreground
/usr/local/bin/nubifer-context-service

# Or in background
/usr/local/bin/nubifer-context-service &
```

The CLI will still work:

```bash
nubifer-workspace list
```

## Integration with Credential Manager

The Context Manager can integrate with the Credential Manager service. If both are running:

1. Create credentials in Credential Manager
2. Reference credential ID when creating workspace:
   ```bash
   nubifer-workspace create \
     --name "AWS Prod" \
     --provider aws \
     --account-id 123456789012 \
     --credential-id <credential-id-from-cred-manager>
   ```

The Context Manager will start after the Credential Manager if both are enabled.

## Next Steps

- Set up shell integration: Source `/etc/profile.d/nubiferos-context.sh`
- Install the Context Indicator GNOME extension
- Configure CLI wrappers for cloud tools
- Create workspaces for your cloud accounts

## Beta Status Note

As noted in the implementation plan, systemd service integration is marked for beta. The service files are complete and functional, but are not required for basic operation. You can use the CLI directly without running the systemd service.
