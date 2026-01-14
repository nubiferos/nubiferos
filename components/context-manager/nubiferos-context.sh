#!/bin/bash
# NubiferOS Context Manager - Shell Integration
# This file is sourced by /etc/profile.d/ to provide workspace context in shells

# Check if nubifer-workspace command exists
if ! command -v nubifer-workspace &> /dev/null; then
    return
fi

# Function to activate workspace environment
nubifer_activate() {
    if [ -z "$1" ]; then
        echo "Usage: nubifer_activate <workspace-id>" >&2
        return 1
    fi
    
    # Export environment variables
    eval "$(nubifer-workspace env "$1" 2>/dev/null)"
    
    if [ $? -eq 0 ]; then
        echo "✓ Activated workspace: $NUBIFEROS_WORKSPACE_NAME"
    else
        echo "✗ Failed to activate workspace" >&2
        return 1
    fi
}

# Function to show current workspace context
nubifer_context() {
    if [ -n "$NUBIFEROS_WORKSPACE_ID" ]; then
        echo "Current workspace: $NUBIFEROS_PROMPT_ICON $NUBIFEROS_WORKSPACE_NAME"
        echo "Provider: $NUBIFEROS_PROVIDER"
        echo "Account: $NUBIFEROS_ACCOUNT"
        if [ "$NUBIFEROS_WORKSPACE_READ_ONLY" = "true" ]; then
            echo "Mode: 🔒 Read-Only"
        else
            echo "Mode: 🔓 Read-Write"
        fi
    else
        echo "No active workspace"
    fi
}

# Aliases for convenience
alias nw='nubifer-workspace'
alias nw-activate='nubifer_activate'
alias nw-context='nubifer_context'
alias nw-switch='nubifer-workspace switch'
alias nw-list='nubifer-workspace list'
alias nw-current='nubifer-workspace current'

# Auto-load workspace if current workspace file exists
NUBIFEROS_CURRENT_FILE="$HOME/.config/nubiferos/current-workspace"
if [ -f "$NUBIFEROS_CURRENT_FILE" ] && [ -z "$NUBIFEROS_WORKSPACE_ID" ]; then
    WORKSPACE_ID=$(cat "$NUBIFEROS_CURRENT_FILE" 2>/dev/null)
    if [ -n "$WORKSPACE_ID" ]; then
        # Silently load workspace environment
        eval "$(nubifer-workspace env "$WORKSPACE_ID" 2>/dev/null)" 2>/dev/null
    fi
fi

# Export functions
export -f nubifer_activate
export -f nubifer_context
