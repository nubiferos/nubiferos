#!/bin/bash
# NubiferOS Shell Integration
# Provides visual workspace context in terminal prompts
# Source this file in ~/.bashrc or /etc/bash.bashrc

# Track last known workspace and JSON mtime to detect changes
_NUBIFER_LAST_WORKSPACE=""
_NUBIFER_LAST_WS_MTIME=""

# Function to check if workspace changed (via GNOME UI or another terminal)
_nubifer_check_workspace_change() {
    local current_file="$HOME/.config/nubifer/current-workspace"
    local env_file="$HOME/.config/nubifer/current-env"

    if [ -f "$current_file" ]; then
        local new_workspace_id
        new_workspace_id=$(cat "$current_file" 2>/dev/null)

        local needs_reload=false

        # Check if workspace ID changed
        if [ -n "$new_workspace_id" ] && [ "$new_workspace_id" != "$_NUBIFER_LAST_WORKSPACE" ]; then
            needs_reload=true
        fi

        # Check if workspace JSON was modified (e.g. RO toggle in another terminal)
        if [ -n "$new_workspace_id" ] && [ "$needs_reload" = "false" ]; then
            local ws_file="$HOME/.config/nubifer/workspaces/${new_workspace_id}.json"
            if [ -f "$ws_file" ]; then
                local current_mtime
                current_mtime=$(stat -c %Y "$ws_file" 2>/dev/null)
                if [ -n "$current_mtime" ] && [ "$current_mtime" != "$_NUBIFER_LAST_WS_MTIME" ]; then
                    needs_reload=true
                fi
            fi
        fi

        if [ "$needs_reload" = "true" ]; then
            _NUBIFER_LAST_WORKSPACE="$new_workspace_id"

            # Track mtime of workspace JSON
            local ws_file="$HOME/.config/nubifer/workspaces/${new_workspace_id}.json"
            if [ -f "$ws_file" ]; then
                _NUBIFER_LAST_WS_MTIME=$(stat -c %Y "$ws_file" 2>/dev/null)
            fi

            # Source the environment file if it exists (written by GNOME extension)
            if [ -f "$env_file" ]; then
                eval "$(cat "$env_file")"
            else
                # Fall back to running the CLI
                eval "$(nubifer-workspace env "$new_workspace_id" 2>/dev/null)"
            fi

            nubifer_update_prompt
        fi
    fi
}

# Function to update prompt with workspace context
nubifer_update_prompt() {
    # Check if workspace is active
    if [ -f "$HOME/.config/nubifer/current-workspace" ]; then
        local workspace_id=$(cat "$HOME/.config/nubifer/current-workspace")
        local workspace_file="$HOME/.config/nubifer/workspaces/${workspace_id}.json"
        
        if [ -f "$workspace_file" ]; then
            # Parse workspace info using Python (more reliable than jq)
            local workspace_info=$(python3 -c "
import json
with open('$workspace_file') as f:
    ws = json.load(f)
    theme = ws['theme']
    icon = theme['icon']
    color = theme['terminal_color']
    account = ws['account_name']
    readonly = '🔒 Read-Only' if ws['read_only'] else '🔓 Read-Write'
    ro_flag = 'true' if ws['read_only'] else 'false'
    print(f'{icon}|{color}|{account}|{readonly}|{ro_flag}')
" 2>/dev/null)

            if [ -n "$workspace_info" ]; then
                IFS='|' read -r icon color account readonly ro_flag <<< "$workspace_info"

                # Build colored prompt
                # Format: [☁️ account-name 🔒 Read-Only] user@host:path$
                PS1="[\[\e[38;5;${color}m\]${icon} ${account} ${readonly}\[\e[0m\]] \u@\h:\w\$ "

                # Export workspace variables for scripts
                export NUBIFER_WORKSPACE_ID="$workspace_id"
                export NUBIFER_WORKSPACE_ACTIVE="true"
                export NUBIFER_WORKSPACE_READ_ONLY="$ro_flag"

                return
            fi
        fi
    fi
    
    # No active workspace - use default prompt
    PS1="\u@\h:\w\$ "
    export NUBIFER_WORKSPACE_ACTIVE="false"
}

# Function to activate workspace in current shell
nubifer_activate() {
    if [ -z "$1" ]; then
        echo "Usage: nubifer_activate <workspace-id>"
        return 1
    fi
    
    # Switch workspace and load environment
    eval $(nubifer-workspace env "$1" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        nubifer_update_prompt
        echo "✓ Workspace activated"
    else
        echo "✗ Failed to activate workspace: $1"
        return 1
    fi
}

# Function to show current workspace context
nubifer_context() {
    if [ "$NUBIFER_WORKSPACE_ACTIVE" = "true" ]; then
        nubifer-workspace current
    else
        echo "No active workspace"
        echo "Create one with: nubifer-workspace create --name <name> --provider <aws|azure|gcp> --account-id <id>"
    fi
}

# Function to quickly switch workspaces
nubifer_switch() {
    if [ -z "$1" ]; then
        # Show list if no argument
        nubifer-workspace list
        return
    fi
    
    # Switch and activate
    nubifer-workspace switch "$1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        nubifer_activate "$1"
    else
        echo "✗ Failed to switch workspace"
        return 1
    fi
}

# Function to enforce read-only mode
nubifer_check_readonly() {
    if [ "$NUBIFER_WORKSPACE_READ_ONLY" = "true" ]; then
        echo "✗ Operation blocked: Workspace is in read-only mode 🔒"
        echo "  Disable with: nubifer-workspace readonly $NUBIFER_WORKSPACE_ID --disable"
        return 1
    fi
    return 0
}

# Wrapper functions for cloud CLIs that respect read-only mode
# These will be used by CLI wrapper scripts

nubifer_aws_wrapper() {
    # Check for write operations
    local write_commands="create|delete|update|put|modify|terminate|stop|start|reboot|attach|detach"
    
    if [ "$NUBIFER_WORKSPACE_READ_ONLY" = "true" ]; then
        # Check if command is a write operation
        if echo "$@" | grep -qE "$write_commands"; then
            echo "✗ AWS write operation blocked: Workspace is in read-only mode 🔒" >&2
            return 1
        fi
    fi
    
    # Execute actual AWS CLI
    command aws "$@"
}

nubifer_az_wrapper() {
    # Check for write operations
    local write_commands="create|delete|update|set"
    
    if [ "$NUBIFER_WORKSPACE_READ_ONLY" = "true" ]; then
        if echo "$@" | grep -qE "$write_commands"; then
            echo "✗ Azure write operation blocked: Workspace is in read-only mode 🔒" >&2
            return 1
        fi
    fi
    
    # Execute actual Azure CLI
    command az "$@"
}

nubifer_gcloud_wrapper() {
    # Check for write operations
    local write_commands="create|delete|update|set|add|remove"
    
    if [ "$NUBIFER_WORKSPACE_READ_ONLY" = "true" ]; then
        if echo "$@" | grep -qE "$write_commands"; then
            echo "✗ GCP write operation blocked: Workspace is in read-only mode 🔒" >&2
            return 1
        fi
    fi
    
    # Execute actual gcloud CLI
    command gcloud "$@"
}

# Aliases for convenience
alias nw='nubifer-workspace'
alias nw-switch='nubifer_switch'
alias nw-context='nubifer_context'
alias nw-activate='nubifer_activate'
alias nc='nubifer-creds'

# Initialize last workspace tracker
_NUBIFER_LAST_WORKSPACE="$NUBIFER_WORKSPACE_ID"
if [ -n "$NUBIFER_WORKSPACE_ID" ]; then
    local_ws_file="$HOME/.config/nubifer/workspaces/${NUBIFER_WORKSPACE_ID}.json"
    if [ -f "$local_ws_file" ]; then
        _NUBIFER_LAST_WS_MTIME=$(stat -c %Y "$local_ws_file" 2>/dev/null)
    fi
    unset local_ws_file
fi

# Update prompt on shell start
nubifer_update_prompt

# Check for workspace changes on each prompt (enables GNOME UI switching)
PROMPT_COMMAND="_nubifer_check_workspace_change${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Show welcome message only for interactive shells (not installer/kiosk)
if [ -n "$PS1" ] && [ "$(whoami)" != "installer" ] && [ ! -f /tmp/.nubifer-shell-init-done ]; then
    echo "NubiferOS Workspace Integration loaded"
    echo "Commands: nw (workspace), nc (credentials), nw-switch, nw-context"
    touch /tmp/.nubifer-shell-init-done
fi
