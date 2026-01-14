# NubiferOS Credential Manager Systemd Service

This directory contains systemd service files for the NubiferOS Credential Manager D-Bus service.

## Files

### nubifer-credential-manager.service
User systemd service unit file that runs the credential manager D-Bus service.

**Installation Location**: `/usr/lib/systemd/user/nubifer-credential-manager.service`

**Type**: User service (runs per-user, not system-wide)

**Features**:
- D-Bus activation support
- Automatic restart on failure
- Security hardening (NoNewPrivileges, PrivateTmp, ProtectSystem)
- Read-only access to home directory except for pass store and config
- Journal logging

### org.nubiferos.CredentialManager.service
D-Bus service activation file that allows the credential manager to be started automatically when accessed via D-Bus.

**Installation Location**: `/usr/share/dbus-1/services/org.nubiferos.CredentialManager.service`

**Purpose**: Enables D-Bus to automatically start the credential manager service when a client tries to access it.

## Installation

The service files are automatically installed by the main installation script:

```bash
cd components/credential-manager
sudo ./install.sh
```

## Usage

### Manual Service Management

**Start the service:**
```bash
systemctl --user start nubifer-credential-manager.service
```

**Stop the service:**
```bash
systemctl --user stop nubifer-credential-manager.service
```

**Check status:**
```bash
systemctl --user status nubifer-credential-manager.service
```

**View logs:**
```bash
journalctl --user -u nubifer-credential-manager.service
```

### Enable Auto-Start on Boot

To have the service start automatically when you log in:

```bash
systemctl --user enable nubifer-credential-manager.service
```

To disable auto-start:

```bash
systemctl --user disable nubifer-credential-manager.service
```

### D-Bus Activation

The service supports D-Bus activation, which means it will automatically start when a client tries to access it via D-Bus, even if it's not running.

Test D-Bus activation:
```bash
# The service will start automatically when accessed
dbus-send --session --print-reply \
  --dest=org.nubiferos.CredentialManager \
  /org/nubiferos/CredentialManager \
  org.nubiferos.CredentialManager.CheckPrerequisites
```

## Service Configuration

### Security Hardening

The service includes several security hardening options:

- **NoNewPrivileges=true**: Prevents the service from gaining new privileges
- **PrivateTmp=true**: Provides a private /tmp directory
- **ProtectSystem=strict**: Makes most of the filesystem read-only
- **ProtectHome=read-only**: Makes home directory read-only except for specified paths
- **ReadWritePaths**: Allows write access only to:
  - `~/.password-store` (pass credential storage)
  - `~/.config/nubiferos` (credential metadata database)

### Restart Policy

- **Restart=on-failure**: Automatically restarts if the service crashes
- **RestartSec=5**: Waits 5 seconds before restarting

### Logging

All service output is sent to the systemd journal with the identifier `nubifer-credential-manager`.

View logs:
```bash
journalctl --user -u nubifer-credential-manager.service -f
```

## Troubleshooting

### Service won't start

Check the service status and logs:
```bash
systemctl --user status nubifer-credential-manager.service
journalctl --user -u nubifer-credential-manager.service -n 50
```

Common issues:
1. **Pass not initialized**: Run `nubifer-creds init` first
2. **No GPG key**: Create a GPG key with `gpg --gen-key`
3. **Python dependencies missing**: Reinstall with `sudo ./install.sh`

### D-Bus activation not working

Check if the D-Bus service file is installed:
```bash
ls -l /usr/share/dbus-1/services/org.nubiferos.CredentialManager.service
```

Reload D-Bus configuration:
```bash
systemctl --user reload dbus.service
```

### Permission errors

The service needs read-write access to:
- `~/.password-store` (pass storage)
- `~/.config/nubiferos` (metadata database)

Check permissions:
```bash
ls -ld ~/.password-store ~/.config/nubiferos
```

## Development

### Testing the service

1. Stop any running instance:
   ```bash
   systemctl --user stop nubifer-credential-manager.service
   ```

2. Run manually for debugging:
   ```bash
   /usr/local/bin/nubifer-creds-service
   ```

3. Test D-Bus interface:
   ```bash
   # In another terminal
   nubifer-creds list
   ```

### Modifying the service

After modifying the service file:

1. Reinstall:
   ```bash
   sudo ./install.sh
   ```

2. Reload systemd:
   ```bash
   systemctl --user daemon-reload
   ```

3. Restart the service:
   ```bash
   systemctl --user restart nubifer-credential-manager.service
   ```

## Notes

- This is a **user service**, not a system service. It runs with user privileges.
- The service uses D-Bus SessionBus, not SystemBus.
- Each user has their own instance of the service.
- The service is **not enabled by default** - users must explicitly enable it if they want auto-start.
- For manual operation, users can run `nubifer-creds-service` directly without systemd.

## Future Enhancements

Potential improvements for future versions:

- [ ] Socket activation for on-demand startup
- [ ] Credential expiration monitoring
- [ ] Automatic credential rotation
- [ ] Integration with systemd credential storage
- [ ] Support for hardware security keys (YubiKey)
- [ ] Audit logging integration

## References

- [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [systemd.unit(5)](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [D-Bus Activation](https://dbus.freedesktop.org/doc/dbus-daemon.1.html)
