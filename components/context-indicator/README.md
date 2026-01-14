# NubiferOS Context Indicator

Visual "always know which account you're in" indicator for GNOME Shell and terminal prompts.

## Features

- ✅ Always-visible indicator in GNOME top bar
- ✅ Color-coded by cloud provider (AWS orange, Azure blue, GCP red)
- ✅ Shows: Provider | Account Name | Region | Mode
- ✅ Read-only mode visual indication (red border + 🔒)
- ✅ Read-write mode visual indication (green border)
- ✅ Dropdown menu to switch workspaces
- ✅ Real-time updates via D-Bus signals
- ✅ Terminal prompt integration with colors
- ✅ Prevents account confusion

## Components

### 1. GNOME Shell Extension

**Location**: `~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org/`

**Features**:
- Shows in top bar (system status area)
- Subscribes to D-Bus signal: `ContextManager.WorkspaceSwitched`
- Updates immediately when workspace changes
- Click to open workspace switcher menu

**Display Format**:
```
[☁️ AWS | Production | us-east-1 | 🔒 READ-ONLY]
[⛅ Azure | Dev Subscription | eastus]
[🔵 GCP | Staging Project | us-central1]
```

### 2. Terminal Prompt Integration

**Location**: `/etc/profile.d/nubiferos-prompt.sh`

**Features**:
- Adds workspace context to terminal prompt
- Color-coded by provider
- Shows read-only indicator
- Updates when workspace changes

**Prompt Format**:
```bash
[☁️ AWS-Prod 🔒] user@host:~$
[⛅ Azure-Dev] user@host:~$
[🔵 GCP-Staging] user@host:~$
```

## Visual Theming

### Provider Colors

| Provider | Background | Icon | Text Color |
|----------|-----------|------|------------|
| AWS      | #FF9900 (Orange) | ☁️ | White |
| Azure    | #0078D4 (Blue) | ⛅ | White |
| GCP      | #EA4335 (Red) | 🔵 | White |
| Oracle   | #FF0000 (Red) | 🔴 | White |
| Multi    | #6B46C1 (Purple) | 🌐 | White |
| None     | #555555 (Gray) | - | Light Gray |

### Mode Indicators

| Mode | Border Color | Icon |
|------|-------------|------|
| Read-Only | #DC3545 (Red) | 🔒 |
| Read-Write | #28A745 (Green) | - |

## Installation

```bash
cd components/context-indicator
./install-indicator.sh
```

For system-wide terminal prompt integration:
```bash
sudo ./install-indicator.sh
```

## Post-Installation

### Restart GNOME Shell

**Method 1**: Alt+F2, type `r`, press Enter

**Method 2**: Log out and log back in

**Method 3** (Wayland): Log out and log back in (required)

### Verify Installation

```bash
# Check if extension is installed
gnome-extensions list | grep nubiferos

# Check if extension is enabled
gnome-extensions info nubiferos-context@nubiferos.org

# Check terminal prompt integration
ls -la /etc/profile.d/nubiferos-prompt.sh
```

## Usage

### Automatic Display

Once installed, the indicator automatically shows the current workspace:

1. Create a workspace:
   ```bash
   nubifer-workspace create --name "AWS Prod" --provider aws --account-id 123456789012
   ```

2. Switch to it:
   ```bash
   nubifer-workspace switch <workspace-id>
   ```

3. The indicator updates immediately in the top bar

### Workspace Switcher Menu

Click the indicator to open the menu:

- **Workspace List**: Shows all workspaces with checkmark on active one
- **Refresh**: Reload workspace list
- **Create New Workspace**: Opens terminal with create command
- **Manage Workspaces**: Opens terminal with list command

Click any workspace to switch to it.

### Terminal Prompt

Open a new terminal after activating a workspace:

```bash
# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Open new terminal - prompt shows workspace context
[☁️ AWS-Prod] user@host:~$
```

## Visual Examples

### AWS Production (Read-Only)
```
┌─────────────────────────────────────────────────┐
│ [☁️ AWS | Production | us-east-1 | 🔒 READ-ONLY] │
└─────────────────────────────────────────────────┘
  Orange background, red border, lock icon
```

### Azure Dev (Read-Write)
```
┌──────────────────────────────────────┐
│ [⛅ Azure | Dev Subscription | eastus] │
└──────────────────────────────────────┘
  Blue background, green border
```

### GCP Staging (Read-Write)
```
┌────────────────────────────────────────────┐
│ [🔵 GCP | Staging Project | us-central1] │
└────────────────────────────────────────────┘
  Red background, green border
```

### No Workspace
```
┌──────────────────┐
│ [No Workspace]   │
└──────────────────┘
  Gray background
```

## D-Bus Integration

The extension subscribes to the `WorkspaceSwitched` signal:

```javascript
// Signal definition
signal WorkspaceSwitched(
    workspace_id: string,
    provider: string,
    account_id: string
)

// When workspace is switched via CLI or menu
nubifer-workspace switch <workspace-id>
  ↓
ContextManager emits WorkspaceSwitched signal
  ↓
Extension receives signal and updates display
```

## Troubleshooting

### Extension Not Appearing

**Check if installed**:
```bash
gnome-extensions list | grep nubiferos
```

**Check if enabled**:
```bash
gnome-extensions info nubiferos-context@nubiferos.org
```

**Enable manually**:
```bash
gnome-extensions enable nubiferos-context@nubiferos.org
```

**Restart GNOME Shell**:
- Alt+F2, type `r`, press Enter
- Or log out and log back in

### Extension Shows "No Workspace"

**Check if workspace is active**:
```bash
nubifer-workspace current
```

**Check if D-Bus service is running**:
```bash
dbus-send --session --print-reply \
  --dest=org.nubiferos.ContextManager \
  /org/nubiferos/ContextManager \
  org.freedesktop.DBus.Introspectable.Introspect
```

**Start D-Bus service if needed**:
```bash
nubifer-context-service &
```

### Extension Not Updating

**Check D-Bus signals**:
```bash
dbus-monitor --session "type='signal',interface='org.nubiferos.ContextManager'"
```

**Manually refresh**:
- Click the indicator
- Click "🔄 Refresh" in the menu

### Terminal Prompt Not Showing

**Check if script is installed**:
```bash
ls -la /etc/profile.d/nubiferos-prompt.sh
```

**Source the script manually**:
```bash
source /etc/profile.d/nubiferos-prompt.sh
```

**Open new terminal**:
- Prompt integration only applies to new shells
- Close and reopen terminal

**Check environment variables**:
```bash
echo $NUBIFEROS_WORKSPACE_ID
echo $NUBIFEROS_WORKSPACE_NAME
echo $NUBIFEROS_PROMPT_ICON
echo $NUBIFEROS_PROMPT_COLOR
```

### View Extension Logs

```bash
# Real-time logs
journalctl -f -o cat /usr/bin/gnome-shell

# Recent logs
journalctl -xe | grep -i nubiferos
```

## Customization

### Change Colors

Edit `stylesheet.css`:
```css
.nubiferos-aws {
    background-color: #YOUR_COLOR;
}
```

### Change Prompt Format

Edit `nubiferos-prompt.sh`:
```bash
NUBIFEROS_PS1_PREFIX="[YOUR FORMAT] "
```

### Disable Extension

```bash
gnome-extensions disable nubiferos-context@nubiferos.org
```

### Uninstall

```bash
# Remove extension
rm -rf ~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org

# Remove prompt integration
sudo rm /etc/profile.d/nubiferos-prompt.sh

# Restart GNOME Shell
# Alt+F2, type 'r', press Enter
```

## Development

### Project Structure

```
components/context-indicator/
├── gnome-extension/
│   ├── extension.js       # Main extension code
│   ├── metadata.json      # Extension metadata
│   └── stylesheet.css     # Visual styling
├── nubiferos-prompt.sh    # Terminal prompt integration
├── install-indicator.sh   # Installation script
└── README.md              # This file
```

### Testing Changes

```bash
# After modifying extension files
cp gnome-extension/* ~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org/

# Restart GNOME Shell
# Alt+F2, type 'r', press Enter

# View logs
journalctl -f -o cat /usr/bin/gnome-shell
```

### Debugging

Add log statements in `extension.js`:
```javascript
log('NubiferOS: Debug message');
```

View in logs:
```bash
journalctl -f -o cat /usr/bin/gnome-shell | grep NubiferOS
```

## Security Considerations

- Extension runs in GNOME Shell process (trusted)
- Uses D-Bus for secure communication
- No credentials displayed in indicator
- Only shows account names and metadata
- Read-only mode clearly indicated

## Future Enhancements

- [ ] KDE Plasma widget
- [ ] Notification on workspace switch
- [ ] Keyboard shortcuts for workspace switching
- [ ] Workspace favorites/pinning
- [ ] Cost tracking integration
- [ ] Alert on approaching budget limits
- [ ] Integration with approval workflows

## License

Part of NubiferOS - GPL-3.0
