# NubiferOS Context Manager - systemd Service

This directory contains systemd service files for running the NubiferOS Context Manager as a user service.

## Files

- `nubifer-context-manager.service` - systemd user service unit file
- `org.nubiferos.ContextManager.service` - D-Bus service activation file

## Installation

### Automatic Installation

The installation script handles systemd service setup:

```bash
cd components/context-manager
sudo ./install.sh
```

### Manual Installation

If you need to install the systemd service manually:

```bash
# Copy systemd service file
mkdir -p ~/.config/systemd/user
cp systemd/nubifer-context-manager.service ~/.config/systemd/user/

# Copy D-Bus service file
mkdir -p ~/.local/share/dbus-1/services
cp systemd/org.nubiferos.ContextManager.service ~/.local/share/dbus-1/services/

# Reload systemd
systemctl --user daemon-reload

# Enable and start the service
systemctl --user enable nubifer-context-manager.service
systemctl --user start nubifer-context-manager.service
```

## Service Management

### Check Service Status

```bash
systemctl --user status nubifer-context-manager.service
```

### View Service Logs

```bash
journalctl --user -u nubifer-context-manager.service -f
```

### Restart Service

```bash
systemctl --user restart nubifer-context-manager.service
```

### Stop Service

```bash
systemctl --user stop nubifer-context-manager.service
```

### Disable Service

```bash
systemctl --user disable nubifer-context-manager.service
```

## Service Dependencies

The Context Manager service depends on:

- **dbus.service** - Required for D-Bus communication
- **nubifer-credential-manager.service** - Recommended for credential integration

The service will start after the credential manager if it's available, but will still function without it (workspaces can be created without credentials).

## D-Bus Activation

The service can be automatically started on-demand when a D-Bus client tries to access it. This is configured via the `org.nubiferos.ContextManager.service` file.

To test D-Bus activation:

```bash
# Stop the service if running
systemctl --user stop nubifer-context-manager.service

# Try to access via D-Bus (will auto-start the service)
nubifer-workspace list
```

## Security Features

The service includes several security hardening measures:

- **NoNewPrivileges=true** - Prevents privilege escalation
- **PrivateTmp=true** - Isolated /tmp directory
- **ProtectSystem=strict** - Read-only system directories
- **ProtectHome=read-only** - Read-only home directory (except workspace database)
- **ReadWritePaths=%h/.config/nubiferos** - Only workspace database is writable

## Troubleshooting

### Service Won't Start

Check the logs:
```bash
journalctl --user -u nubifer-context-manager.service -n 50
```

Common issues:
- Missing Python dependencies: `pip3 install -r requirements.txt`
- D-Bus not running: `systemctl --user status dbus.service`
- Permission issues: Check `~/.config/nubiferos` permissions

### D-Bus Connection Failed

Verify D-Bus service is registered:
```bash
dbus-send --session --print-reply \
  --dest=org.freedesktop.DBus \
  /org/freedesktop/DBus \
  org.freedesktop.DBus.ListNames | grep nubiferos
```

### Service Crashes on Startup

Check Python path and dependencies:
```bash
# Test the service manually
/usr/local/bin/nubifer-context-service
```

## Development Mode

For development, you can run the service manually without systemd:

```bash
cd components/context-manager/src
python3 dbus_interface.py
```

This allows you to see output directly in the terminal for debugging.

## Note on Beta Status

As noted in the task list, systemd service integration is deferred to beta. For now, the service can be run manually:

```bash
# Run the D-Bus service manually
nubifer-context-service
```

Or use the CLI directly without the D-Bus service:

```bash
# CLI works without the service running
nubifer-workspace create --name "AWS Prod" --provider aws --account-id 123456789012
nubifer-workspace list
```

The systemd service provides automatic startup and D-Bus activation, but is not required for basic functionality.
