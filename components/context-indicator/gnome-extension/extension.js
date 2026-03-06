/* extension.js
 *
 * NubiferOS Context Indicator
 * Always-visible cloud account context for secure multi-cloud management
 */

const { GObject, St, Gio, GLib, Clutter } = imports.gi;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

// Provider configurations
const PROVIDERS = {
    'aws': {
        name: 'AWS',
        icon: '☁️',
        color: '#FF9900',
        textColor: '#FFFFFF'
    },
    'azure': {
        name: 'Azure',
        icon: '⛅',
        color: '#0078D4',
        textColor: '#FFFFFF'
    },
    'gcp': {
        name: 'GCP',
        icon: '🔵',
        color: '#EA4335',
        textColor: '#FFFFFF'
    },
    'oracle': {
        name: 'Oracle',
        icon: '🔴',
        color: '#FF0000',
        textColor: '#FFFFFF'
    },
    'multi': {
        name: 'Multi',
        icon: '🌐',
        color: '#6B46C1',
        textColor: '#FFFFFF'
    }
};

const ContextIndicator = GObject.registerClass(
class ContextIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'NubiferOS Context Indicator');
        
        // Create main container
        this._box = new St.BoxLayout({
            style_class: 'nubiferos-context-box'
        });
        
        // Create label
        this._label = new St.Label({
            text: 'No Workspace',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'nubiferos-context-label'
        });
        
        this._box.add_child(this._label);
        this.add_child(this._box);
        
        // Initialize D-Bus connection
        this._initDBus();
        
        // Load current workspace
        this._loadCurrentWorkspace();
        
        // Build menu
        this._buildMenu();
    }
    
    _initDBus() {
        try {
            // D-Bus interface definition
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
            
        } catch (e) {
            log(`NubiferOS: Failed to initialize D-Bus: ${e}`);
        }
    }
    
    _loadCurrentWorkspace() {
        if (!this._proxy) {
            // D-Bus unavailable — fall back to JSON
            this._loadWorkspaceFromJson();
            this._startJsonPolling();
            return;
        }

        try {
            this._proxy.GetCurrentWorkspaceRemote((result, error) => {
                if (error) {
                    log(`NubiferOS: D-Bus failed, falling back to JSON: ${error}`);
                    this._loadWorkspaceFromJson();
                    this._startJsonPolling();
                    return;
                }

                this._stopJsonPolling();
                const [workspace] = result;
                this._updateDisplay(workspace);
            });
        } catch (e) {
            log(`NubiferOS: Error loading workspace, falling back to JSON: ${e}`);
            this._loadWorkspaceFromJson();
            this._startJsonPolling();
        }
    }

    _loadWorkspaceFromJson() {
        try {
            const homeDir = GLib.get_home_dir();
            const currentFile = `${homeDir}/.config/nubifer/current-workspace`;

            const [ok, contents] = GLib.file_get_contents(currentFile);
            if (!ok) {
                this._updateDisplayFromJson(null);
                return;
            }

            const wsId = imports.byteArray.toString(contents).trim();
            const wsFile = `${homeDir}/.config/nubifer/workspaces/${wsId}.json`;

            const [wok, wcontents] = GLib.file_get_contents(wsFile);
            if (!wok) {
                this._updateDisplayFromJson(null);
                return;
            }

            const ws = JSON.parse(imports.byteArray.toString(wcontents));
            this._updateDisplayFromJson(ws);
        } catch (e) {
            log(`NubiferOS: Error reading workspace JSON: ${e}`);
            this._updateDisplayFromJson(null);
        }
    }

    _updateDisplayFromJson(ws) {
        if (!ws) {
            this._label.set_text('No Workspace');
            this._box.set_style('background-color: #555555; padding: 4px 12px; border-radius: 4px;');
            return;
        }

        const provider = ws.provider || 'unknown';
        const accountName = ws.account_name || ws.account_id || 'Unknown';
        const region = ws.region || '';
        const readOnly = ws.read_only || false;

        const providerConfig = PROVIDERS[provider] || {
            name: provider.toUpperCase(),
            icon: '☁️',
            color: '#555555',
            textColor: '#FFFFFF'
        };

        let text = `${providerConfig.icon} ${providerConfig.name} | ${accountName}`;
        if (region) {
            text += ` | ${region}`;
        }
        text += readOnly ? ' | 🔒 Read-Only' : ' | 🔓 Read-Write';

        this._label.set_text(text);

        // Green=RO (safe), Red=RW (danger)
        const borderColor = readOnly ? '#28A745' : '#DC3545';
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

    _startJsonPolling() {
        if (this._jsonPollTimerId) return;  // Already polling

        this._jsonPollTimerId = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT,
            5,
            () => {
                this._loadWorkspaceFromJson();
                return GLib.SOURCE_CONTINUE;
            }
        );
    }

    _stopJsonPolling() {
        if (this._jsonPollTimerId) {
            GLib.source_remove(this._jsonPollTimerId);
            this._jsonPollTimerId = null;
        }
    }
    
    _onWorkspaceSwitched(proxy, sender, [workspace_id, provider, account_id]) {
        log(`NubiferOS: Workspace switched to ${workspace_id}`);
        this._loadCurrentWorkspace();
    }
    
    _updateDisplay(workspace) {
        if (!workspace || Object.keys(workspace).length === 0) {
            this._label.set_text('No Workspace');
            this._box.set_style('background-color: #555555; padding: 4px 12px; border-radius: 4px;');
            return;
        }
        
        // Extract workspace info
        const provider = workspace.provider?.unpack() || 'unknown';
        const accountName = workspace.account_name?.unpack() || workspace.account_id?.unpack() || 'Unknown';
        const region = workspace.region?.unpack() || '';
        const readOnly = workspace.read_only?.unpack() || false;
        
        // Get provider config
        const providerConfig = PROVIDERS[provider] || {
            name: provider.toUpperCase(),
            icon: '☁️',
            color: '#555555',
            textColor: '#FFFFFF'
        };
        
        // Build display text — always show mode
        let text = `${providerConfig.icon} ${providerConfig.name} | ${accountName}`;
        if (region) {
            text += ` | ${region}`;
        }
        text += readOnly ? ' | 🔒 Read-Only' : ' | 🔓 Read-Write';

        this._label.set_text(text);

        // Apply styling — green=RO (safe), red=RW (danger)
        const borderColor = readOnly ? '#28A745' : '#DC3545';
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
    
    _buildMenu() {
        // Add refresh button
        const refreshItem = new PopupMenu.PopupMenuItem('🔄 Refresh');
        refreshItem.connect('activate', () => {
            this._loadCurrentWorkspace();
            this._rebuildWorkspaceList();
        });
        this.menu.addMenuItem(refreshItem);
        
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        
        // Workspace list section
        this._workspaceSection = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._workspaceSection);
        
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        
        // Add "Create New Workspace" button
        const createItem = new PopupMenu.PopupMenuItem('➕ Create New Workspace...');
        createItem.connect('activate', () => {
            this._openTerminalWithCommand('nubifer-workspace create --help');
        });
        this.menu.addMenuItem(createItem);
        
        // Add "Manage Workspaces" button
        const manageItem = new PopupMenu.PopupMenuItem('⚙️ Manage Workspaces');
        manageItem.connect('activate', () => {
            this._openTerminalWithCommand('nubifer-workspace list');
        });
        this.menu.addMenuItem(manageItem);

        // Add "Toggle Read-Only Mode" button
        const toggleRoItem = new PopupMenu.PopupMenuItem('🔒 Toggle Read-Only Mode');
        toggleRoItem.connect('activate', () => {
            // Determine current mode and run the appropriate command
            const homeDir = GLib.get_home_dir();
            const currentFile = `${homeDir}/.config/nubifer/current-workspace`;
            try {
                const [ok, contents] = GLib.file_get_contents(currentFile);
                if (ok) {
                    const wsId = imports.byteArray.toString(contents).trim();
                    const wsFile = `${homeDir}/.config/nubifer/workspaces/${wsId}.json`;
                    const [wok, wcontents] = GLib.file_get_contents(wsFile);
                    if (wok) {
                        const ws = JSON.parse(imports.byteArray.toString(wcontents));
                        if (ws.read_only) {
                            // Currently RO → switch to RW (requires sudo)
                            this._openTerminalWithCommand(`sudo nubifer-workspace rw ${wsId}`);
                        } else {
                            // Currently RW → switch to RO
                            this._openTerminalWithCommand(`nubifer-workspace ro ${wsId}`);
                        }
                    }
                }
            } catch (e) {
                log(`NubiferOS: Error toggling read-only: ${e}`);
                this._openTerminalWithCommand('nubifer-workspace ro');
            }
        });
        this.menu.addMenuItem(toggleRoItem);
        
        // Load workspace list when menu is opened
        this.menu.connect('open-state-changed', (menu, open) => {
            if (open) {
                this._rebuildWorkspaceList();
            }
        });
    }
    
    _rebuildWorkspaceList() {
        // Clear existing items
        this._workspaceSection.removeAll();

        if (!this._proxy) {
            // D-Bus unavailable — fall back to JSON
            this._rebuildWorkspaceListFromJson();
            return;
        }
        
        try {
            this._proxy.ListWorkspacesRemote('', (result, error) => {
                if (error) {
                    log(`NubiferOS: Failed to list workspaces: ${error}`);
                    const item = new PopupMenu.PopupMenuItem('Failed to load workspaces');
                    item.setSensitive(false);
                    this._workspaceSection.addMenuItem(item);
                    return;
                }
                
                const [workspaces] = result;
                
                if (!workspaces || workspaces.length === 0) {
                    const item = new PopupMenu.PopupMenuItem('No workspaces found');
                    item.setSensitive(false);
                    this._workspaceSection.addMenuItem(item);
                    return;
                }
                
                // Get current workspace ID
                let currentWorkspaceId = null;
                this._proxy.GetCurrentWorkspaceRemote((result, error) => {
                    if (!error && result && result[0]) {
                        const workspace = result[0];
                        currentWorkspaceId = workspace.workspace_id?.unpack();
                    }
                    
                    // Add workspace items
                    workspaces.forEach(ws => {
                        const workspaceId = ws.workspace_id?.unpack();
                        const name = ws.name?.unpack() || 'Unknown';
                        const provider = ws.provider?.unpack() || 'unknown';
                        const readOnly = ws.read_only?.unpack() || false;
                        
                        const providerConfig = PROVIDERS[provider] || PROVIDERS['aws'];
                        const icon = providerConfig.icon;
                        const modeLabel = readOnly ? ' 🔒 Read-Only' : ' 🔓 Read-Write';
                        const checkmark = workspaceId === currentWorkspaceId ? '✓ ' : '';

                        const item = new PopupMenu.PopupMenuItem(
                            `${checkmark}${icon} ${name}${modeLabel}`
                        );
                        
                        item.connect('activate', () => {
                            this._switchWorkspace(workspaceId);
                        });
                        
                        this._workspaceSection.addMenuItem(item);
                    });
                });
            });
        } catch (e) {
            log(`NubiferOS: Error loading workspaces: ${e}`);
        }
    }
    
    _rebuildWorkspaceListFromJson() {
        try {
            const homeDir = GLib.get_home_dir();
            const wsDir = `${homeDir}/.config/nubifer/workspaces`;
            const currentFile = `${homeDir}/.config/nubifer/current-workspace`;

            let currentWorkspaceId = null;
            try {
                const [ok, contents] = GLib.file_get_contents(currentFile);
                if (ok) currentWorkspaceId = imports.byteArray.toString(contents).trim();
            } catch (e) { /* ignore */ }

            const dir = Gio.File.new_for_path(wsDir);
            if (!dir.query_exists(null)) {
                const item = new PopupMenu.PopupMenuItem('No workspaces found');
                item.setSensitive(false);
                this._workspaceSection.addMenuItem(item);
                return;
            }

            const enumerator = dir.enumerate_children(
                'standard::name',
                Gio.FileQueryInfoFlags.NONE,
                null
            );

            let fileInfo;
            let found = false;
            while ((fileInfo = enumerator.next_file(null)) !== null) {
                const fileName = fileInfo.get_name();
                if (!fileName.endsWith('.json')) continue;

                try {
                    const filePath = `${wsDir}/${fileName}`;
                    const [ok, contents] = GLib.file_get_contents(filePath);
                    if (!ok) continue;

                    const ws = JSON.parse(imports.byteArray.toString(contents));
                    const providerConfig = PROVIDERS[ws.provider] || PROVIDERS['aws'];
                    const modeLabel = ws.read_only ? ' 🔒 Read-Only' : ' 🔓 Read-Write';
                    const checkmark = ws.workspace_id === currentWorkspaceId ? '✓ ' : '';

                    const item = new PopupMenu.PopupMenuItem(
                        `${checkmark}${providerConfig.icon} ${ws.name}${modeLabel}`
                    );

                    const wsId = ws.workspace_id;
                    item.connect('activate', () => {
                        this._openTerminalWithCommand(
                            `nubifer-workspace switch "${wsId}" && eval $(nubifer-workspace env "${wsId}")`
                        );
                    });

                    this._workspaceSection.addMenuItem(item);
                    found = true;
                } catch (e) {
                    log(`NubiferOS: Error parsing workspace JSON ${fileName}: ${e}`);
                }
            }

            if (!found) {
                const item = new PopupMenu.PopupMenuItem('No workspaces found');
                item.setSensitive(false);
                this._workspaceSection.addMenuItem(item);
            }
        } catch (e) {
            log(`NubiferOS: Error listing workspaces from JSON: ${e}`);
            const item = new PopupMenu.PopupMenuItem('Failed to load workspaces');
            item.setSensitive(false);
            this._workspaceSection.addMenuItem(item);
        }
    }

    _switchWorkspace(workspaceId) {
        if (!this._proxy) {
            return;
        }
        
        try {
            this._proxy.SwitchWorkspaceRemote(workspaceId, (result, error) => {
                if (error) {
                    log(`NubiferOS: Failed to switch workspace: ${error}`);
                    Main.notify('NubiferOS', 'Failed to switch workspace');
                    return;
                }
                
                const [success] = result;
                if (success) {
                    // Also run CLI to update shell environment file
                    this._updateShellEnvironment(workspaceId);
                    Main.notify('NubiferOS', 'Workspace switched - new terminals will use this workspace');
                    // Display will update via WorkspaceSwitched signal
                } else {
                    Main.notify('NubiferOS', 'Failed to switch workspace');
                }
            });
        } catch (e) {
            log(`NubiferOS: Error switching workspace: ${e}`);
        }
    }
    
    _updateShellEnvironment(workspaceId) {
        // Run CLI command to export environment to shared file
        // This file is sourced by shell integration on each prompt
        try {
            const homeDir = GLib.get_home_dir();
            const envFile = `${homeDir}/.config/nubifer/current-env`;
            
            // Run nubifer-workspace env command and save to file
            const argv = [
                '/bin/bash', '-c',
                `nubifer-workspace env "${workspaceId}" > "${envFile}" 2>/dev/null`
            ];
            
            GLib.spawn_async(
                null,
                argv,
                null,
                GLib.SpawnFlags.SEARCH_PATH,
                null
            );
            
            log(`NubiferOS: Updated shell environment file for workspace ${workspaceId}`);
        } catch (e) {
            log(`NubiferOS: Error updating shell environment: ${e}`);
        }
    }
    
    _openTerminalWithCommand(command) {
        try {
            const terminal = 'gnome-terminal';
            const argv = [terminal, '--', 'bash', '-c', `${command}; exec bash`];
            
            const [success, pid] = GLib.spawn_async(
                null,
                argv,
                null,
                GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                null
            );
            
            if (!success) {
                log('NubiferOS: Failed to open terminal');
            }
        } catch (e) {
            log(`NubiferOS: Error opening terminal: ${e}`);
        }
    }
    
    destroy() {
        this._stopJsonPolling();
        if (this._signalId && this._proxy) {
            this._proxy.disconnectSignal(this._signalId);
        }
        super.destroy();
    }
});

class Extension {
    constructor() {
        this._indicator = null;
    }
    
    enable() {
        log('NubiferOS Context Indicator: Enabling');
        this._indicator = new ContextIndicator();
        Main.panel.addToStatusArea('nubiferos-context-indicator', this._indicator);
    }
    
    disable() {
        log('NubiferOS Context Indicator: Disabling');
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}

function init() {
    return new Extension();
}
