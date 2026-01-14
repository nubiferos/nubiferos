# Systemd Service Quick Start

Quick reference for managing the NubiferOS Credential Manager systemd service.

## Installation

The service is automatically installed by the main installation script:

```bash
cd components/credential-manager
sudo ./install.sh
```

## Basic Commands

### Start the service
```bash
systemctl --user start nubifer-credential-manager.service
```

### Stop the service
```bash
systemctl --user stop nubifer-credential-manager.service
```

### Restart the service
```bash
systemctl --user restart nubifer-credential-manager.service
```

### Check status
```bash
systemctl --user status nubifer-credential-manager.service
```

### View logs
```bash
journalctl --user -u nubifer-credential-manager.service
```

### Follow logs in real-time
```bash
journalctl --user -u nubifer-credential-manager.service -f
```

## Enable Auto-Start

To have the service start automatically when you log in:

```bash
systemctl --user enable nubifer-credential-manager.service
```

To disable auto-start:

```bash
systemctl --user disable nubifer-credential-manager.service
```

## D-Bus Activation

The service supports automatic D-Bus activation. It will start automatically when accessed via D-Bus, even if not running.

Test D-Bus activation:
```bash
dbus-send --session --print-reply \
  --dest=org.nubiferos.CredentialManager \
  /org/nubiferos/CredentialManager \
  org.nubiferos.CredentialManager.CheckPrerequisites
```

## Troubleshooting

### Service won't start

1. Check status and logs:
   ```bash
   systemctl --user status nubifer-credential-manager.service
   journalctl --user -u nubifer-credential-manager.service -n 50
   ```

2. Verify prerequisites:
   ```bash
   nubifer-creds status
   ```

3. Check if pass is initialized:
   ```bash
   nubifer-creds init
   ```

### Permission errors

Ensure the service has access to:
- `~/.password-store` (pass storage)
- `~/.config/nubiferos` (metadata database)

```bash
ls -ld ~/.password-store ~/.config/nubiferos
```

### Reload after changes

After modifying the service file:

```bash
systemctl --user daemon-reload
systemctl --user restart nubifer-credential-manager.service
```

## Manual Operation

You can also run the service manually without systemd:

```bash
nubifer-creds-service
```

This is useful for:
- Development and debugging
- Testing without systemd
- Running in environments without systemd

## Notes

- This is a **user service** (runs per-user, not system-wide)
- Uses D-Bus SessionBus (not SystemBus)
- **Not enabled by default** - manual opt-in required
- Supports D-Bus activation for on-demand startup
- Includes security hardening (NoNewPrivileges, PrivateTmp, etc.)

## See Also

- [Full Documentation](README.md) - Complete service documentation
- [Main README](../README.md) - Credential Manager user guide
- [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/systemd.service.html) - systemd service manual
