#!/bin/bash
# NubiferOS Terminal Prompt Integration
# Adds visual workspace context to terminal prompts

# Track workspace JSON mtime for detecting RO toggle changes
_NUBIFEROS_LAST_WS_MTIME=""

# Auto-source current workspace environment on each prompt
# This allows GNOME UI workspace switches to update existing terminals
_nubiferos_check_workspace() {
    local env_file="$HOME/.config/nubifer/current-env"
    local current_file="$HOME/.config/nubifer/current-workspace"

    # Check if current workspace changed (via GNOME UI or another terminal)
    if [ -f "$current_file" ]; then
        local new_workspace_id
        new_workspace_id=$(cat "$current_file" 2>/dev/null)

        local needs_reload=false

        # Check if workspace ID changed
        if [ -n "$new_workspace_id" ] && [ "$new_workspace_id" != "$NUBIFEROS_WORKSPACE_ID" ]; then
            needs_reload=true
        fi

        # Check if workspace JSON was modified (e.g. RO toggle)
        if [ -n "$new_workspace_id" ] && [ "$needs_reload" = "false" ]; then
            local ws_file="$HOME/.config/nubifer/workspaces/${new_workspace_id}.json"
            if [ -f "$ws_file" ]; then
                local current_mtime
                current_mtime=$(stat -c %Y "$ws_file" 2>/dev/null)
                if [ -n "$current_mtime" ] && [ "$current_mtime" != "$_NUBIFEROS_LAST_WS_MTIME" ]; then
                    needs_reload=true
                fi
            fi
        fi

        if [ "$needs_reload" = "true" ]; then
            # Update mtime tracker
            if [ -n "$new_workspace_id" ]; then
                local ws_file="$HOME/.config/nubifer/workspaces/${new_workspace_id}.json"
                if [ -f "$ws_file" ]; then
                    _NUBIFEROS_LAST_WS_MTIME=$(stat -c %Y "$ws_file" 2>/dev/null)
                fi
            fi

            if [ -f "$env_file" ]; then
                eval "$(cat "$env_file")"
                nubiferos_update_prompt 2>/dev/null
            fi
        fi
    fi
}

# Add to PROMPT_COMMAND to check on each prompt
if [[ ! "$PROMPT_COMMAND" =~ "_nubiferos_check_workspace" ]]; then
    PROMPT_COMMAND="_nubiferos_check_workspace${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Only modify prompt if workspace is active
if [ -n "$NUBIFEROS_WORKSPACE_ID" ]; then
    # Get workspace info from environment
    WORKSPACE_NAME="${NUBIFEROS_WORKSPACE_NAME:-Unknown}"
    WORKSPACE_PROVIDER="${NUBIFEROS_PROVIDER:-unknown}"
    WORKSPACE_READ_ONLY="${NUBIFEROS_WORKSPACE_READ_ONLY:-false}"
    PROMPT_ICON="${NUBIFEROS_PROMPT_ICON:-☁️}"
    PROMPT_COLOR="${NUBIFEROS_PROMPT_COLOR:-15}"  # Default white
    
    # Determine read-only indicator — always show mode
    if [ "$WORKSPACE_READ_ONLY" = "true" ]; then
        READONLY_ICON=" 🔒 Read-Only"
    else
        READONLY_ICON=" 🔓 Read-Write"
    fi
    
    # Build colored prompt
    # Format: [☁️ WorkspaceName 🔒] user@host:path$
    NUBIFEROS_PS1_PREFIX="[\[\e[38;5;${PROMPT_COLOR}m\]${PROMPT_ICON} ${WORKSPACE_NAME}${READONLY_ICON}\[\e[0m\]] "
    
    # Check if PS1 already has NubiferOS prefix
    if [[ ! "$PS1" =~ "NUBIFEROS" ]]; then
        # Add NubiferOS prefix to existing PS1
        export PS1="${NUBIFEROS_PS1_PREFIX}${PS1}"
    fi
fi

# Function to update prompt when workspace changes
nubiferos_update_prompt() {
    if [ -n "$NUBIFEROS_WORKSPACE_ID" ]; then
        WORKSPACE_NAME="${NUBIFEROS_WORKSPACE_NAME:-Unknown}"
        PROMPT_ICON="${NUBIFEROS_PROMPT_ICON:-☁️}"
        PROMPT_COLOR="${NUBIFEROS_PROMPT_COLOR:-15}"
        WORKSPACE_READ_ONLY="${NUBIFEROS_WORKSPACE_READ_ONLY:-false}"
        
        if [ "$WORKSPACE_READ_ONLY" = "true" ]; then
            READONLY_ICON=" 🔒 Read-Only"
        else
            READONLY_ICON=" 🔓 Read-Write"
        fi
        
        NUBIFEROS_PS1_PREFIX="[\[\e[38;5;${PROMPT_COLOR}m\]${PROMPT_ICON} ${WORKSPACE_NAME}${READONLY_ICON}\[\e[0m\]] "
        
        # Remove old NubiferOS prefix if exists
        PS1_WITHOUT_PREFIX="${PS1#*\] }"
        
        # Add new prefix
        export PS1="${NUBIFEROS_PS1_PREFIX}${PS1_WITHOUT_PREFIX}"
    else
        # No workspace active, remove NubiferOS prefix
        if [[ "$PS1" =~ "☁️" ]] || [[ "$PS1" =~ "⛅" ]] || [[ "$PS1" =~ "🔵" ]]; then
            PS1_WITHOUT_PREFIX="${PS1#*\] }"
            export PS1="${PS1_WITHOUT_PREFIX}"
        fi
    fi
}

# Export function for use in shell
export -f nubiferos_update_prompt 2>/dev/null || true
