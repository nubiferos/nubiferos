#!/usr/bin/env python3
"""
NubiferOS Context Manager - Environment Integration
Exports environment variables for active workspace
"""

import sys
from pathlib import Path
from workspace_service import WorkspaceService


def export_workspace_environment(workspace_id: str):
    """Export environment variables for a workspace"""
    service = WorkspaceService()
    workspace = service.get_workspace(workspace_id)
    
    if not workspace:
        print(f"# Error: Workspace not found: {workspace_id}", file=sys.stderr)
        return
    
    # Export workspace metadata
    print(f"export NUBIFEROS_WORKSPACE_ID='{workspace_id}'")
    print(f"export NUBIFEROS_WORKSPACE_NAME='{workspace['name']}'")
    print(f"export NUBIFEROS_WORKSPACE_READ_ONLY='{str(workspace['read_only']).lower()}'")
    
    # Export provider-specific environment variables
    for key, value in workspace['environment'].items():
        print(f"export {key}='{value}'")
    
    # Export theme information for prompt customization
    theme = workspace['theme']
    print(f"export NUBIFEROS_PROMPT_COLOR='{theme['terminal_color']}'")
    print(f"export NUBIFEROS_PROMPT_ICON='{theme['icon']}'")
    print(f"export NUBIFEROS_PROMPT_NAME='{workspace['account_name']}'")
    
    # Update PS1 for visual context
    mode_icon = '🔒' if workspace['read_only'] else ''
    ps1 = f"'[\\[\\e[38;5;{theme['terminal_color']}m\\]"
    ps1 += f"{theme['icon']} {workspace['account_name']}"
    if mode_icon:
        ps1 += f" {mode_icon}"
    ps1 += "\\[\\e[0m\\]] \\u@\\h:\\w\\$ '"
    print(f"export PS1={ps1}")


def export_current_workspace_environment():
    """Export environment variables for current workspace"""
    service = WorkspaceService()
    workspace = service.get_current_workspace()
    
    if not workspace:
        print("# No active workspace", file=sys.stderr)
        return
    
    export_workspace_environment(workspace['workspace_id'])


if __name__ == '__main__':
    if len(sys.argv) > 1:
        export_workspace_environment(sys.argv[1])
    else:
        export_current_workspace_environment()
