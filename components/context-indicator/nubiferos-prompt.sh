#!/bin/bash
# NubiferOS Terminal Prompt Integration
# Adds visual workspace context to terminal prompts

# Only modify prompt if workspace is active
if [ -n "$NUBIFEROS_WORKSPACE_ID" ]; then
    # Get workspace info from environment
    WORKSPACE_NAME="${NUBIFEROS_WORKSPACE_NAME:-Unknown}"
    WORKSPACE_PROVIDER="${NUBIFEROS_PROVIDER:-unknown}"
    WORKSPACE_READ_ONLY="${NUBIFEROS_WORKSPACE_READ_ONLY:-false}"
    PROMPT_ICON="${NUBIFEROS_PROMPT_ICON:-☁️}"
    PROMPT_COLOR="${NUBIFEROS_PROMPT_COLOR:-15}"  # Default white
    
    # Determine read-only indicator
    if [ "$WORKSPACE_READ_ONLY" = "true" ]; then
        READONLY_ICON=" 🔒"
    else
        READONLY_ICON=""
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
            READONLY_ICON=" 🔒"
        else
            READONLY_ICON=""
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
