#!/bin/bash
# NubiferOS Shell Integration
# Provides visual workspace context in terminal prompts
# Source this file in ~/.bashrc or /etc/bash.bashrc

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
    readonly = '🔒' if ws['read_only'] else ''
    print(f'{icon}|{color}|{account}|{readonly}')
" 2>/dev/null)
            
            if [ -n "$workspace_info" ]; then
                IFS='|' read -r icon color account readonly <<< "$workspace_info"
                
                # Build colored prompt
                # Format: [☁️ account-name 🔒] user@host:path$
                PS1="[\[\e[38;5;${color}m\]${icon} ${account}${readonly:+ $readonly}\[\e[0m\]] \u@\h:\w\$ "
                
                # Export workspace variables for scripts
                export NUBIFER_WORKSPACE_ID="$workspace_id"
                export NUBIFER_WORKSPACE_ACTIVE="true"
                
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

# Update prompt on shell start
nubifer_update_prompt

# Update prompt after each command (optional, can be disabled for performance)
# PROMPT_COMMAND="nubifer_update_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

echo "NubiferOS Workspace Integration loaded"
echo "Commands: nw (workspace manager), nw-switch (quick switch), nw-context (show current)"
