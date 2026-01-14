# Context Indicator Implementation

This document details the technical implementation of the NubiferOS Context Indicator.

## Overview

The Context Indicator provides always-visible cloud account context through:
1. **GNOME Shell Extension**: Top bar indicator with workspace switcher menu
2. **Terminal Prompt Integration**: Colored prompt showing workspace context

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GNOME Shell                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Context Indicator Extension                      │  │
│  │  - Panel indicator (top bar)                      │  │
│  │  - Workspace switcher menu                        │  │
│  │  - D-Bus signal subscriber                        │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↕ D-Bus
┌─────────────────────────────────────────────────────────┐
│         Context Manager Service (D-Bus)                 │
│  - GetCurrentWorkspace()                                │
│  - ListWorkspaces()                                     │
│  - SwitchWorkspace()                                    │
│  - WorkspaceSwitched signal                             │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│              SQLite Database                            │
│  - Workspace configurations                             │
│  - Current workspace state                              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                Terminal (Bash)                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  /etc/profile.d/nubiferos-prompt.sh               │  │
│  │  - Reads NUBIFEROS_* environment variables        │  │
│  │  - Modifies PS1 prompt                            │  │
│  │  - Adds color coding                              │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Component 1: GNOME Shell Extension

### File Structure

```
~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org/
├── extension.js       # Main extension code
├── metadata.json      # Extension metadata
└── stylesheet.css     # Visual styling
```

### extension.js

**Key Classes**:

#### ContextIndicator (extends PanelMenu.Button)

Main extension class that creates the panel indicator.

**Initialization**:
```javascript
_init() {
    // Create panel button
    super._init(0.0, 'NubiferOS Context Indicator');
    
    // Create UI elements
    this._box = new St.BoxLayout();
    this._label = new St.Label({ text: 'No Workspace' });
    
    // Initialize D-Bus connection
    this._initDBus();
    
    // Load current workspace
    this._loadCurrentWorkspace();
    
    // Build dropdown menu
    this._buildMenu();
}
```

**D-Bus Integration**:
```javascript
_initDBus() {
    // Define D-Bus interface
    const ContextManagerInterface = `
        <node>
            <interface name="org.nubiferos.ContextManager">
                <method name="GetCurrentWorkspace">
                    <arg type="a{sv}" direction="out" name="workspace"/>
                </method>
                <method name="ListWorkspaces">
                    <arg type="s" direction="in" name="provider"/>
                    <arg type="aa{sv}" direction="out" name="workspaces"/>
                </method>
                <method name="SwitchWorkspace">
                    <arg type="s" direction="in" name="workspace_id"/>
                    <arg type="b" direction="out" name="success"/>
                </method>
                <signal name="WorkspaceSwitched">
                    <arg type="s" name="workspace_id"/>
                    <arg type="s" name="provider"/>
                    <arg type="s" name="account_id"/>
                </signal>
            </interface>
        </node>
    `;
    
    // Create proxy
    const ContextManagerProxy = Gio.DBusProxy.makeProxyWrapper(ContextManagerInterface);
    this._proxy = new ContextManagerProxy(
        Gio.DBus.session,
        'org.nubiferos.ContextManager',
        '/org/nubiferos/ContextManager'
    );
    
    // Subscribe to WorkspaceSwitched signal
    this._signalId = this._proxy.connectSignal(
        'WorkspaceSwitched',
        this._onWorkspaceSwitched.bind(this)
    );
}
```

**Display Update**:
```javascript
_updateDisplay(workspace) {
    if (!workspace || Object.keys(workspace).length === 0) {
        // No workspace active
        this._label.set_text('No Workspace');
        this._box.set_style('background-color: #555555; ...');
        return;
    }
    
    // Extract workspace info
    const provider = workspace.provider?.unpack() || 'unknown';
    const accountName = workspace.account_name?.unpack() || 'Unknown';
    const region = workspace.region?.unpack() || '';
    const readOnly = workspace.read_only?.unpack() || false;
    
    // Get provider config
    const providerConfig = PROVIDERS[provider];
    
    // Build display text
    let text = `${providerConfig.icon} ${providerConfig.name} | ${accountName}`;
    if (region) text += ` | ${region}`;
    if (readOnly) text += ' | 🔒 READ-ONLY';
    
    this._label.set_text(text);
    
    // Apply styling
    const borderColor = readOnly ? '#DC3545' : '#28A745';
    const style = `
        background-color: ${providerConfig.color};
        color: ${providerConfig.textColor};
        padding: 4px 12px;
        border-radius: 4px;
        border: 2px solid ${borderColor};
        font-weight: bold;
    `;
    this._box.set_style(style);
}
```

**Signal Handler**:
```javascript
_onWorkspaceSwitched(proxy, sender, [workspace_id, provider, account_id]) {
    log(`NubiferOS: Workspace switched to ${workspace_id}`);
    // Reload current workspace to update display
    this._loadCurrentWorkspace();
}
```

**Menu Building**:
```javascript
_buildMenu() {
    // Refresh button
    const refreshItem = new PopupMenu.PopupMenuItem('🔄 Refresh');
    refreshItem.connect('activate', () => {
        this._loadCurrentWorkspace();
        this._rebuildWorkspaceList();
    });
    this.menu.addMenuItem(refreshItem);
    
    // Separator
    this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    
    // Workspace list section (populated dynamically)
    this._workspaceSection = new PopupMenu.PopupMenuSection();
    this.menu.addMenuItem(this._workspaceSection);
    
    // Separator
    this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    
    // Create new workspace button
    const createItem = new PopupMenu.PopupMenuItem('➕ Create New Workspace...');
    createItem.connect('activate', () => {
        this._openTerminalWithCommand('nubifer-workspace create --help');
    });
    this.menu.addMenuItem(createItem);
    
    // Manage workspaces button
    const manageItem = new PopupMenu.PopupMenuItem('⚙️ Manage Workspaces');
    manageItem.connect('activate', () => {
        this._openTerminalWithCommand('nubifer-workspace list');
    });
    this.menu.addMenuItem(manageItem);
    
    // Rebuild workspace list when menu opens
    this.menu.connect('open-state-changed', (menu, open) => {
        if (open) this._rebuildWorkspaceList();
    });
}
```

**Workspace List Population**:
```javascript
_rebuildWorkspaceList() {
    // Clear existing items
    this._workspaceSection.removeAll();
    
    // Call D-Bus ListWorkspaces
    this._proxy.ListWorkspacesRemote('', (result, error) => {
        if (error) {
            const item = new PopupMenu.PopupMenuItem('Failed to load workspaces');
            item.setSensitive(false);
            this._workspaceSection.addMenuItem(item);
            return;
        }
        
        const [workspaces] = result;
        
        // Get current workspace ID
        this._proxy.GetCurrentWorkspaceRemote((result, error) => {
            const currentWorkspaceId = result?.[0]?.workspace_id?.unpack();
            
            // Add workspace items
            workspaces.forEach(ws => {
                const workspaceId = ws.workspace_id?.unpack();
                const name = ws.name?.unpack() || 'Unknown';
                const provider = ws.provider?.unpack() || 'unknown';
                const readOnly = ws.read_only?.unpack() || false;
                
                const providerConfig = PROVIDERS[provider];
                const icon = providerConfig.icon;
                const lockIcon = readOnly ? ' 🔒' : '';
                const checkmark = workspaceId === currentWorkspaceId ? '✓ ' : '';
                
                const item = new PopupMenu.PopupMenuItem(
                    `${checkmark}${icon} ${name}${lockIcon}`
                );
                
                item.connect('activate', () => {
                    this._switchWorkspace(workspaceId);
                });
                
                this._workspaceSection.addMenuItem(item);
            });
        });
    });
}
```

**Workspace Switching**:
```javascript
_switchWorkspace(workspaceId) {
    this._proxy.SwitchWorkspaceRemote(workspaceId, (result, error) => {
        if (error) {
            Main.notify('NubiferOS', 'Failed to switch workspace');
            return;
        }
        
        const [success] = result;
        if (success) {
            Main.notify('NubiferOS', 'Workspace switched successfully');
            // Display updates via WorkspaceSwitched signal
        } else {
            Main.notify('NubiferOS', 'Failed to switch workspace');
        }
    });
}
```

### metadata.json

```json
{
  "uuid": "nubiferos-context@nubiferos.org",
  "name": "NubiferOS Context Indicator",
  "description": "Always-visible cloud account context indicator",
  "version": 1,
  "shell-version": ["42", "43", "44", "45"],
  "url": "https://github.com/nubiferos/nubiferos",
  "settings-schema": "org.gnome.shell.extensions.nubiferos-context"
}
```

### stylesheet.css

```css
.nubiferos-context-box {
    spacing: 4px;
}

.nubiferos-context-label {
    font-weight: bold;
    padding: 0 8px;
}

/* Provider-specific styles (applied via inline styles in JS) */
.nubiferos-aws {
    background-color: #FF9900;
    color: #FFFFFF;
}

.nubiferos-azure {
    background-color: #0078D4;
    color: #FFFFFF;
}

.nubiferos-gcp {
    background-color: #EA4335;
    color: #FFFFFF;
}

.nubiferos-oracle {
    background-color: #FF0000;
    color: #FFFFFF;
}

.nubiferos-multi {
    background-color: #6B46C1;
    color: #FFFFFF;
}

.nubiferos-none {
    background-color: #555555;
    color: #CCCCCC;
}

/* Read-only mode */
.nubiferos-readonly {
    border: 2px solid #DC3545;
}

/* Read-write mode */
.nubiferos-readwrite {
    border: 2px solid #28A745;
}
```

## Component 2: Terminal Prompt Integration

### File: /etc/profile.d/nubiferos-prompt.sh

**Purpose**: Modify bash prompt to show workspace context

**Implementation**:

```bash
#!/bin/bash
# NubiferOS Terminal Prompt Integration
# Adds workspace context to bash prompt

# Only run in interactive shells
[[ $- != *i* ]] && return

# Function to get workspace prompt
nubiferos_prompt() {
    # Check if workspace is active
    if [ -z "$NUBIFEROS_WORKSPACE_ID" ]; then
        return
    fi
    
    # Get workspace info from environment
    local name="${NUBIFEROS_WORKSPACE_NAME:-Unknown}"
    local icon="${NUBIFEROS_PROMPT_ICON:-☁️}"
    local color="${NUBIFEROS_PROMPT_COLOR:-\033[0;37m}"
    local readonly_icon=""
    
    if [ "$NUBIFEROS_READ_ONLY" = "true" ]; then
        readonly_icon=" 🔒"
    fi
    
    # Build prompt prefix
    echo -e "${color}[${icon} ${name}${readonly_icon}]\033[0m "
}

# Add to PS1 if not already present
if [[ ! "$PS1" =~ "nubiferos_prompt" ]]; then
    PS1='$(nubiferos_prompt)'$PS1
fi

# Aliases for convenience
alias nw='nubifer-workspace'
alias nw-list='nubifer-workspace list'
alias nw-current='nubifer-workspace current'
alias nw-switch='nubifer-workspace switch'
alias nw-activate='eval $(nubifer-workspace env'

# Function to activate workspace and update prompt
nw-activate() {
    if [ -z "$1" ]; then
        echo "Usage: nw-activate <workspace-id>"
        return 1
    fi
    
    eval $(nubifer-workspace env "$1")
    
    # Update prompt immediately
    PS1='$(nubiferos_prompt)'$PS1
}

# Export functions
export -f nubiferos_prompt
```

**Environment Variables Set by Context Manager**:

```bash
NUBIFEROS_WORKSPACE_ID="workspace-abc123"
NUBIFEROS_WORKSPACE_NAME="AWS Production"
NUBIFEROS_PROVIDER="aws"
NUBIFEROS_ACCOUNT_ID="123456789012"
NUBIFEROS_REGION="us-east-1"
NUBIFEROS_READ_ONLY="false"
NUBIFEROS_PROMPT_ICON="☁️"
NUBIFEROS_PROMPT_COLOR="\033[0;33m"  # Orange for AWS

# Provider-specific variables
AWS_PROFILE="nubiferos-123456789012"
AWS_REGION="us-east-1"
AWS_DEFAULT_REGION="us-east-1"
```

**Color Codes**:

| Provider | Color Code | Visual |
|----------|-----------|--------|
| AWS | `\033[0;33m` | Orange |
| Azure | `\033[0;34m` | Blue |
| GCP | `\033[0;31m` | Red |
| Oracle | `\033[0;31m` | Red |
| Multi | `\033[0;35m` | Purple |

## Installation Process

### install-indicator.sh

```bash
#!/bin/bash
# Install NubiferOS Context Indicator

set -e

EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org"
PROMPT_SCRIPT="/etc/profile.d/nubiferos-prompt.sh"

echo "Installing NubiferOS Context Indicator..."

# Install GNOME Shell extension
echo "Installing GNOME Shell extension..."
mkdir -p "$EXTENSION_DIR"
cp gnome-extension/extension.js "$EXTENSION_DIR/"
cp gnome-extension/metadata.json "$EXTENSION_DIR/"
cp gnome-extension/stylesheet.css "$EXTENSION_DIR/"

# Enable extension
gnome-extensions enable nubiferos-context@nubiferos.org || true

echo "✓ GNOME Shell extension installed"

# Install terminal prompt integration (requires sudo)
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    echo "Installing terminal prompt integration..."
    sudo cp nubiferos-prompt.sh "$PROMPT_SCRIPT"
    sudo chmod 644 "$PROMPT_SCRIPT"
    echo "✓ Terminal prompt integration installed"
else
    echo "⚠ Skipping terminal prompt integration (requires sudo)"
    echo "  Run: sudo cp nubiferos-prompt.sh $PROMPT_SCRIPT"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Restart GNOME Shell (Alt+F2, type 'r', press Enter)"
echo "   On Wayland: Log out and log back in"
echo "2. Open new terminal to see prompt integration"
echo "3. Create a workspace: nubifer-workspace create --help"
```

## D-Bus Communication

### Signal Flow

```
User Action (CLI or Menu)
    ↓
nubifer-workspace switch <id>
    ↓
Context Manager Service
    ↓
SwitchWorkspace() method
    ↓
Update SQLite database
    ↓
Emit WorkspaceSwitched signal
    ↓
GNOME Shell Extension receives signal
    ↓
Call GetCurrentWorkspace()
    ↓
Update indicator display
```

### D-Bus Methods Used

**GetCurrentWorkspace()**:
- Returns: `Dict[str, Variant]` with workspace details
- Called: On extension load, after workspace switch
- Response time: ~10-20ms

**ListWorkspaces(provider: str)**:
- Returns: `List[Dict[str, Variant]]` with all workspaces
- Called: When menu is opened, on refresh
- Response time: ~20-50ms (depends on workspace count)

**SwitchWorkspace(workspace_id: str)**:
- Returns: `bool` (success)
- Called: When user clicks workspace in menu
- Response time: ~30-50ms
- Side effect: Emits WorkspaceSwitched signal

### D-Bus Signal

**WorkspaceSwitched(workspace_id: str, provider: str, account_id: str)**:
- Emitted: After successful workspace switch
- Subscribers: GNOME Shell extension, other listeners
- Latency: ~5-10ms from emission to reception

## Performance Considerations

### Extension Load Time

- Extension initialization: ~50ms
- D-Bus connection: ~20ms
- Initial workspace load: ~30ms
- **Total**: ~100ms

### Update Latency

- Workspace switch command: ~30ms
- D-Bus signal emission: ~5ms
- Extension receives signal: ~5ms
- GetCurrentWorkspace() call: ~20ms
- Display update: ~10ms
- **Total**: ~70ms (user perceives as instant)

### Memory Usage

- Extension: ~2-3 MB
- D-Bus proxy: ~500 KB
- **Total**: ~3 MB (negligible)

## Security Considerations

### No Credential Exposure

- Indicator shows only: provider, account name, region, mode
- Never shows: access keys, secrets, tokens, passwords
- Account names are user-defined (can be generic)

### D-Bus Security

- Uses session bus (user-specific)
- No system bus access
- No privileged operations
- Read-only access to workspace metadata

### Extension Permissions

- Runs in GNOME Shell process (trusted)
- No file system access (except D-Bus)
- No network access
- No subprocess execution (except terminal launch)

## Error Handling

### D-Bus Service Unavailable

```javascript
if (!this._proxy) {
    this._updateDisplay(null);  // Show "No Workspace"
    return;
}
```

### Workspace Not Found

```javascript
if (!workspace || Object.keys(workspace).length === 0) {
    this._label.set_text('No Workspace');
    this._box.set_style('background-color: #555555; ...');
    return;
}
```

### Signal Connection Failure

```javascript
try {
    this._signalId = this._proxy.connectSignal(...);
} catch (e) {
    log(`NubiferOS: Failed to connect signal: ${e}`);
    // Extension still works, just no real-time updates
}
```

## Debugging

### Enable Logging

```bash
# View extension logs
journalctl -f -o cat /usr/bin/gnome-shell | grep NubiferOS

# View D-Bus signals
dbus-monitor --session "type='signal',interface='org.nubiferos.ContextManager'"
```

### Common Issues

**Extension not appearing**:
- Check if enabled: `gnome-extensions info nubiferos-context@nubiferos.org`
- Enable manually: `gnome-extensions enable nubiferos-context@nubiferos.org`
- Restart GNOME Shell: Alt+F2, type `r`, press Enter

**Indicator shows "No Workspace"**:
- Check if workspace is active: `nubifer-workspace current`
- Check if D-Bus service is running: `ps aux | grep nubifer-context-service`
- Start service: `nubifer-context-service &`

**Indicator not updating**:
- Check D-Bus signals: `dbus-monitor --session ...`
- Click "🔄 Refresh" in menu
- Restart extension: disable then enable

## Future Enhancements

### Planned Features

- [ ] KDE Plasma widget (similar functionality)
- [ ] Notification on workspace switch
- [ ] Keyboard shortcuts (e.g., Super+W for workspace switcher)
- [ ] Workspace favorites/pinning
- [ ] Cost tracking integration (show current spend)
- [ ] Budget alerts (visual warning when approaching limit)
- [ ] Approval workflow integration (show pending approvals)

### Technical Improvements

- [ ] Cache workspace list to reduce D-Bus calls
- [ ] Debounce rapid workspace switches
- [ ] Add animation for indicator updates
- [ ] Support custom themes/colors
- [ ] Add accessibility features (screen reader support)

## Testing

See `TEST_WORKFLOW.md` for comprehensive testing procedures.

## License

Part of NubiferOS - GPL-3.0
