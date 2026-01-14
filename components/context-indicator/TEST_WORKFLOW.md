# Context Indicator Test Workflow

This document provides step-by-step testing procedures for the NubiferOS Context Indicator.

## Prerequisites

Before testing, ensure:
- ✅ Context Manager service is installed and running
- ✅ Credential Manager service is installed and running
- ✅ At least one workspace has been created
- ✅ GNOME Shell is running (version 42+)

## Test 1: Extension Installation

### Steps

1. Install the extension:
   ```bash
   cd components/context-indicator
   ./install-indicator.sh
   ```

2. Verify installation:
   ```bash
   gnome-extensions list | grep nubiferos
   ```
   
   **Expected**: `nubiferos-context@nubiferos.org`

3. Check if enabled:
   ```bash
   gnome-extensions info nubiferos-context@nubiferos.org
   ```
   
   **Expected**: State: ENABLED

4. Restart GNOME Shell:
   - Press Alt+F2
   - Type `r`
   - Press Enter
   - (On Wayland: log out and log back in)

5. Check top bar:
   
   **Expected**: Indicator appears in top bar showing "No Workspace" (gray background)

### Troubleshooting

If extension doesn't appear:
```bash
# Enable manually
gnome-extensions enable nubiferos-context@nubiferos.org

# Check logs
journalctl -f -o cat /usr/bin/gnome-shell | grep NubiferOS
```

## Test 2: Display Current Workspace

### Steps

1. Create a test workspace:
   ```bash
   nubifer-workspace create \
     --name "AWS Production" \
     --provider aws \
     --account-id 123456789012 \
     --region us-east-1
   ```

2. Switch to the workspace:
   ```bash
   nubifer-workspace switch <workspace-id>
   ```

3. Check indicator display:
   
   **Expected**:
   - Text: `☁️ AWS | AWS Production | us-east-1`
   - Background: Orange (#FF9900)
   - Border: Green (read-write mode)
   - Font: White, bold

### Verification

```bash
# Verify workspace is active
nubifer-workspace current
```

## Test 3: Provider Color Coding

### Steps

Test each provider's visual appearance:

#### AWS (Orange)
```bash
nubifer-workspace create --name "AWS Test" --provider aws --account-id 111111111111
nubifer-workspace switch <workspace-id>
```
**Expected**: Orange background (#FF9900), ☁️ icon

#### Azure (Blue)
```bash
nubifer-workspace create --name "Azure Test" --provider azure --account-id sub-12345
nubifer-workspace switch <workspace-id>
```
**Expected**: Blue background (#0078D4), ⛅ icon

#### GCP (Red)
```bash
nubifer-workspace create --name "GCP Test" --provider gcp --account-id project-123
nubifer-workspace switch <workspace-id>
```
**Expected**: Red background (#EA4335), 🔵 icon

#### Oracle (Red)
```bash
nubifer-workspace create --name "Oracle Test" --provider oracle --account-id tenancy-123
nubifer-workspace switch <workspace-id>
```
**Expected**: Red background (#FF0000), 🔴 icon

#### Multi-cloud (Purple)
```bash
nubifer-workspace create --name "Multi Test" --provider multi --account-id multi-123
nubifer-workspace switch <workspace-id>
```
**Expected**: Purple background (#6B46C1), 🌐 icon

## Test 4: Read-Only Mode Indicator

### Steps

1. Create workspace in read-only mode:
   ```bash
   nubifer-workspace create \
     --name "AWS Prod ReadOnly" \
     --provider aws \
     --account-id 123456789012 \
     --read-only
   ```

2. Switch to it:
   ```bash
   nubifer-workspace switch <workspace-id>
   ```

3. Check indicator:
   
   **Expected**:
   - Text includes: `🔒 READ-ONLY`
   - Border: Red (#DC3545)
   - Background: Orange (AWS)

4. Disable read-only mode:
   ```bash
   nubifer-workspace set-readonly <workspace-id> false
   ```

5. Check indicator updates:
   
   **Expected**:
   - 🔒 icon removed
   - Border: Green (#28A745)

## Test 5: Real-Time Updates via D-Bus

### Steps

1. Open two terminals side-by-side

2. In Terminal 1, monitor D-Bus signals:
   ```bash
   dbus-monitor --session "type='signal',interface='org.nubiferos.ContextManager'"
   ```

3. In Terminal 2, switch workspaces:
   ```bash
   nubifer-workspace switch <workspace-id-1>
   nubifer-workspace switch <workspace-id-2>
   ```

4. Watch indicator in top bar:
   
   **Expected**:
   - Indicator updates immediately (within 100ms)
   - No need to refresh manually
   - Terminal 1 shows WorkspaceSwitched signals

### Verification

```bash
# Check signal emission
signal sender=:1.XXX -> destination=(null destination) serial=XX path=/org/nubiferos/ContextManager; interface=org.nubiferos.ContextManager; member=WorkspaceSwitched
   string "workspace-id"
   string "aws"
   string "123456789012"
```

## Test 6: Workspace Switcher Menu

### Steps

1. Click the indicator in top bar

2. Verify menu contents:
   
   **Expected**:
   - 🔄 Refresh button at top
   - Separator line
   - List of all workspaces with icons
   - Active workspace has ✓ checkmark
   - Read-only workspaces show 🔒
   - Separator line
   - ➕ Create New Workspace...
   - ⚙️ Manage Workspaces

3. Click a different workspace in the list:
   
   **Expected**:
   - Workspace switches immediately
   - Indicator updates
   - Menu closes

4. Click "🔄 Refresh":
   
   **Expected**:
   - Workspace list reloads
   - Current workspace checkmark updates

5. Click "➕ Create New Workspace...":
   
   **Expected**:
   - Terminal opens
   - Shows: `nubifer-workspace create --help`

6. Click "⚙️ Manage Workspaces":
   
   **Expected**:
   - Terminal opens
   - Shows: `nubifer-workspace list`

## Test 7: Terminal Prompt Integration

### Steps

1. Verify script is installed:
   ```bash
   ls -la /etc/profile.d/nubiferos-prompt.sh
   ```
   
   **Expected**: File exists with 644 permissions

2. Open new terminal (important: must be new shell)

3. Activate a workspace:
   ```bash
   eval $(nubifer-workspace env <workspace-id>)
   ```

4. Check prompt:
   
   **Expected**: Prompt shows workspace context
   ```bash
   [☁️ AWS-Production] user@host:~$
   ```

5. Check environment variables:
   ```bash
   echo $NUBIFEROS_WORKSPACE_ID
   echo $NUBIFEROS_WORKSPACE_NAME
   echo $NUBIFEROS_PROMPT_ICON
   echo $NUBIFEROS_PROMPT_COLOR
   ```
   
   **Expected**: All variables are set

6. Switch workspace:
   ```bash
   nubifer-workspace switch <different-workspace-id>
   eval $(nubifer-workspace env <different-workspace-id>)
   ```

7. Check prompt updates:
   
   **Expected**: Prompt reflects new workspace

### Color Verification

- AWS: Orange text
- Azure: Blue text
- GCP: Red text
- Oracle: Red text
- Multi: Purple text

## Test 8: No Workspace State

### Steps

1. Deactivate current workspace:
   ```bash
   unset NUBIFEROS_WORKSPACE_ID
   ```

2. Check indicator:
   
   **Expected**:
   - Text: "No Workspace"
   - Background: Gray (#555555)
   - No border

3. Open menu:
   
   **Expected**:
   - Workspace list still shows all workspaces
   - No checkmark on any workspace

## Test 9: Multiple Workspace Switching

### Steps

1. Create 5 workspaces (different providers)

2. Rapidly switch between them:
   ```bash
   for id in workspace-1 workspace-2 workspace-3 workspace-4 workspace-5; do
     nubifer-workspace switch $id
     sleep 2
   done
   ```

3. Watch indicator:
   
   **Expected**:
   - Updates smoothly for each switch
   - No lag or flickering
   - Colors change correctly
   - No crashes

## Test 10: D-Bus Service Unavailable

### Steps

1. Stop Context Manager service:
   ```bash
   # Find and kill the service process
   pkill -f nubifer-context-service
   ```

2. Check indicator:
   
   **Expected**:
   - Shows "No Workspace" (gray)
   - No crash

3. Open menu:
   
   **Expected**:
   - Shows "D-Bus service not available"
   - Menu items are disabled

4. Restart service:
   ```bash
   nubifer-context-service &
   ```

5. Click "🔄 Refresh" in menu:
   
   **Expected**:
   - Workspace list loads
   - Indicator updates

## Test 11: Extension Logs

### Steps

1. Open logs in real-time:
   ```bash
   journalctl -f -o cat /usr/bin/gnome-shell | grep NubiferOS
   ```

2. Perform various actions:
   - Switch workspaces
   - Open menu
   - Click workspace in menu

3. Verify log messages:
   
   **Expected**:
   ```
   NubiferOS Context Indicator: Enabling
   NubiferOS: Workspace switched to workspace-123
   NubiferOS: Failed to get current workspace: [error details]
   ```

## Test 12: Extension Disable/Enable

### Steps

1. Disable extension:
   ```bash
   gnome-extensions disable nubiferos-context@nubiferos.org
   ```

2. Check top bar:
   
   **Expected**: Indicator disappears

3. Enable extension:
   ```bash
   gnome-extensions enable nubiferos-context@nubiferos.org
   ```

4. Check top bar:
   
   **Expected**: Indicator reappears with current workspace

## Test 13: Uninstall

### Steps

1. Remove extension:
   ```bash
   rm -rf ~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org
   ```

2. Remove prompt integration:
   ```bash
   sudo rm /etc/profile.d/nubiferos-prompt.sh
   ```

3. Restart GNOME Shell

4. Verify removal:
   ```bash
   gnome-extensions list | grep nubiferos
   ```
   
   **Expected**: No output

## Performance Tests

### Test 14: Indicator Responsiveness

**Metric**: Time from workspace switch to indicator update

**Steps**:
1. Switch workspace
2. Measure time until indicator updates

**Expected**: < 100ms

### Test 15: Menu Open Speed

**Metric**: Time from click to menu display

**Steps**:
1. Click indicator
2. Measure time until menu appears

**Expected**: < 50ms

### Test 16: Workspace List Load Time

**Metric**: Time to load workspace list in menu

**Steps**:
1. Create 20 workspaces
2. Open menu
3. Measure time until list populates

**Expected**: < 200ms

## Integration Tests

### Test 17: Full Workflow

**Scenario**: New user setup to active workspace

**Steps**:
1. Install extension
2. Create credential
3. Create workspace
4. Switch to workspace
5. Verify indicator shows workspace
6. Open terminal, verify prompt
7. Run cloud CLI command (with wrapper)

**Expected**: All components work together seamlessly

### Test 18: Multi-User

**Scenario**: Multiple users on same system

**Steps**:
1. Install extension for User A
2. Create workspace for User A
3. Switch to User B
4. Install extension for User B
5. Create workspace for User B

**Expected**: Each user has independent workspaces and indicators

## Security Tests

### Test 19: Credential Exposure

**Verification**: Indicator never shows credentials

**Steps**:
1. Create workspace with credentials
2. Inspect indicator text
3. Inspect menu items
4. Check logs

**Expected**: No access keys, secrets, or tokens visible anywhere

### Test 20: D-Bus Security

**Verification**: Only session bus access

**Steps**:
1. Check D-Bus service registration:
   ```bash
   dbus-send --session --print-reply \
     --dest=org.freedesktop.DBus \
     /org/freedesktop/DBus \
     org.freedesktop.DBus.ListNames | grep nubiferos
   ```

**Expected**: Service only on session bus, not system bus

## Regression Tests

Run all tests after:
- GNOME Shell updates
- Extension modifications
- Context Manager updates
- System updates

## Test Results Template

```
Test Date: YYYY-MM-DD
GNOME Shell Version: X.Y
NubiferOS Version: X.Y.Z
Tester: [Name]

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Extension Installation | ✅ PASS | |
| 2 | Display Current Workspace | ✅ PASS | |
| 3 | Provider Color Coding | ✅ PASS | |
| ... | ... | ... | ... |

Overall Result: PASS / FAIL
```

## Known Issues

None currently.

## Future Test Coverage

- [ ] KDE Plasma widget (when implemented)
- [ ] Wayland-specific tests
- [ ] Multi-monitor setups
- [ ] High DPI displays
- [ ] Accessibility (screen readers)
