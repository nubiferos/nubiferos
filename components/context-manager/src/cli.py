#!/usr/bin/env python3
"""
NubiferOS Context Manager CLI
Command-line interface for workspace management
"""

import click
import sys
import json
from pathlib import Path

from workspace_service import WorkspaceService, WorkspaceServiceError
from environment import export_workspace_environment

# Color output
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


def success(msg):
    """Print success message"""
    click.echo(f"{Colors.GREEN}✓{Colors.END} {msg}")


def error(msg):
    """Print error message"""
    click.echo(f"{Colors.RED}✗{Colors.END} {msg}", err=True)


def warning(msg):
    """Print warning message"""
    click.echo(f"{Colors.YELLOW}⚠{Colors.END} {msg}")


def info(msg):
    """Print info message"""
    click.echo(f"{Colors.BLUE}ℹ{Colors.END} {msg}")


@click.group()
@click.version_option(version='0.1.0')
def cli():
    """
    NubiferOS Context Manager
    
    Manage cloud workspaces with visual context and isolation.
    """
    pass


@cli.command()
@click.option('--name', required=True, help='Workspace name')
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp', 'oracle', 'multi']), 
              required=True, help='Cloud provider')
@click.option('--account-id', required=True, help='Account identifier')
@click.option('--account-name', help='Human-readable account name')
@click.option('--region', help='Default region')
@click.option('--credential-id', help='Credential ID from nubifer-creds')
@click.option('--read-only', is_flag=True, help='Create in read-only mode')
def create(name, provider, account_id, account_name, region, credential_id, read_only):
    """Create a new workspace"""
    
    try:
        service = WorkspaceService()
        
        # Validate credential if provided
        if credential_id:
            # TODO: Integrate with credential manager to validate
            pass
        
        workspace_id = service.create_workspace(
            name=name,
            provider=provider,
            account_id=account_id,
            account_name=account_name,
            region=region,
            credential_id=credential_id,
            read_only=read_only
        )
        
        workspace = service.get_workspace(workspace_id)
        theme = workspace['theme']
        
        success(f"Workspace created: {name}")
        click.echo(f"  ID: {workspace_id}")
        click.echo(f"  Provider: {theme['icon']} {theme['name']}")
        click.echo(f"  Account: {workspace['account_name']}")
        if region:
            click.echo(f"  Region: {region}")
        mode_icon = '🔒' if read_only else '🔓'
        mode_text = 'Read-Only' if read_only else 'Read-Write'
        click.echo(f"  Mode: {mode_icon} {mode_text}")
        
        info(f"Switch to this workspace: nubifer-workspace switch {workspace_id}")
        
    except WorkspaceServiceError as e:
        error(f"Failed to create workspace: {e}")
        sys.exit(1)
    except Exception as e:
        error(f"Unexpected error: {e}")
        sys.exit(1)


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp', 'oracle', 'multi']),
              help='Filter by cloud provider')
@click.option('--format', type=click.Choice(['table', 'json']), default='table',
              help='Output format')
def list(provider, format):
    """List all workspaces"""
    
    try:
        service = WorkspaceService()
        workspaces = service.list_workspaces(provider)
        
        if not workspaces:
            if provider:
                warning(f"No workspaces found for {provider}")
            else:
                warning("No workspaces found")
            info("Create one with: nubifer-workspace create")
            return
        
        if format == 'json':
            # Convert to JSON-serializable format
            output = []
            for ws in workspaces:
                ws_copy = ws.copy()
                ws_copy.pop('theme', None)
                ws_copy.pop('environment', None)
                output.append(ws_copy)
            click.echo(json.dumps(output, indent=2))
        else:
            # Table format
            current = service.get_current_workspace()
            current_id = current['workspace_id'] if current else None
            
            click.echo(f"\n{Colors.BOLD}Workspaces:{Colors.END}\n")
            
            for ws in workspaces:
                theme = ws['theme']
                mode_icon = '🔒' if ws['read_only'] else '🔓'
                current_marker = '→' if ws['workspace_id'] == current_id else ' '
                
                click.echo(f"{current_marker} {theme['icon']} {Colors.BOLD}{ws['name']}{Colors.END}")
                click.echo(f"   ID: {ws['workspace_id']}")
                click.echo(f"   Provider: {theme['name']} | Account: {ws['account_name']}", nl=False)
                if ws.get('region'):
                    click.echo(f" | Region: {ws['region']}", nl=False)
                click.echo(f" | {mode_icon}")
                click.echo()
            
            click.echo(f"{Colors.BOLD}Total:{Colors.END} {len(workspaces)} workspace(s)\n")
        
    except Exception as e:
        error(f"Failed to list workspaces: {e}")
        sys.exit(1)


@cli.command()
@click.argument('workspace_id')
def switch(workspace_id):
    """Switch to a workspace"""
    
    try:
        service = WorkspaceService()
        
        # Try to find workspace by ID or name
        workspace = service.get_workspace(workspace_id)
        
        if not workspace:
            # Try to find by name
            workspaces = service.list_workspaces()
            for ws in workspaces:
                if ws['name'].lower() == workspace_id.lower():
                    workspace_id = ws['workspace_id']
                    workspace = ws
                    break
        
        if not workspace:
            error(f"Workspace not found: {workspace_id}")
            sys.exit(1)
        
        # Set as current workspace
        success_switch = service.set_current_workspace(workspace_id)
        
        if not success_switch:
            error("Failed to switch workspace")
            sys.exit(1)
        
        # Display workspace context
        theme = workspace['theme']
        mode_icon = '🔒' if workspace['read_only'] else '🔓'
        mode_text = 'Read-Only' if workspace['read_only'] else 'Read-Write'
        
        click.echo("\n" + "="*60)
        click.echo(f"{theme['icon']} Workspace: {Colors.BOLD}{workspace['name']}{Colors.END}")
        click.echo("="*60)
        click.echo(f"Provider:  {theme['name']}")
        click.echo(f"Account:   {workspace['account_name']}")
        if workspace.get('region'):
            click.echo(f"Region:    {workspace['region']}")
        click.echo(f"Mode:      {mode_icon} {mode_text}")
        click.echo("="*60)
        
        click.echo(f"\n{Colors.BLUE}# Run this command to activate workspace:{Colors.END}")
        click.echo(f"eval $(nubifer-workspace env {workspace_id})")
        
    except Exception as e:
        error(f"Failed to switch workspace: {e}")
        sys.exit(1)


@cli.command()
def current():
    """Show current workspace"""
    
    try:
        service = WorkspaceService()
        workspace = service.get_current_workspace()
        
        if not workspace:
            warning("No active workspace")
            info("Create one with: nubifer-workspace create")
            info("Switch to one with: nubifer-workspace switch <id>")
            return
        
        theme = workspace['theme']
        mode_icon = '🔒' if workspace['read_only'] else '🔓'
        mode_text = 'Read-Only' if workspace['read_only'] else 'Read-Write'
        
        click.echo(f"\n{Colors.BOLD}Current Workspace:{Colors.END}\n")
        click.echo(f"{theme['icon']} {Colors.BOLD}{workspace['name']}{Colors.END}")
        click.echo(f"ID:        {workspace['workspace_id']}")
        click.echo(f"Provider:  {theme['name']}")
        click.echo(f"Account:   {workspace['account_name']}")
        if workspace.get('region'):
            click.echo(f"Region:    {workspace['region']}")
        click.echo(f"Mode:      {mode_icon} {mode_text}")
        click.echo()
        
    except Exception as e:
        error(f"Failed to get current workspace: {e}")
        sys.exit(1)


@cli.command()
@click.argument('workspace_id')
@click.confirmation_option(prompt='Are you sure you want to delete this workspace?')
def delete(workspace_id):
    """Delete a workspace"""
    
    try:
        service = WorkspaceService()
        
        # Check if it's the current workspace
        current = service.get_current_workspace()
        if current and current['workspace_id'] == workspace_id:
            error("Cannot delete active workspace")
            info("Switch to another workspace first")
            sys.exit(1)
        
        # Get workspace name before deleting
        workspace = service.get_workspace(workspace_id)
        if not workspace:
            error(f"Workspace not found: {workspace_id}")
            sys.exit(1)
        
        deleted = service.delete_workspace(workspace_id)
        
        if deleted:
            success(f"Deleted workspace: {workspace['name']}")
        else:
            error("Failed to delete workspace")
            sys.exit(1)
        
    except Exception as e:
        error(f"Failed to delete workspace: {e}")
        sys.exit(1)


@cli.command('set-readonly')
@click.argument('workspace_id')
@click.argument('enabled', type=click.Choice(['true', 'false']))
def set_readonly(workspace_id, enabled):
    """Set read-only mode for a workspace"""
    
    try:
        service = WorkspaceService()
        
        read_only = enabled == 'true'
        updated = service.set_read_only(workspace_id, read_only)
        
        if not updated:
            error(f"Workspace not found: {workspace_id}")
            sys.exit(1)
        
        workspace = service.get_workspace(workspace_id)
        mode_icon = '🔒' if read_only else '🔓'
        mode_text = 'enabled' if read_only else 'disabled'
        
        success(f"Read-only mode {mode_text}: {workspace['name']} {mode_icon}")
        
    except Exception as e:
        error(f"Failed to set read-only mode: {e}")
        sys.exit(1)


@cli.command()
@click.argument('workspace_id')
def env(workspace_id):
    """Export environment variables for a workspace"""
    
    try:
        export_workspace_environment(workspace_id)
    except Exception as e:
        click.echo(f"# Error: {e}", err=True)
        sys.exit(1)


@cli.command()
def status():
    """Show context manager status"""
    
    try:
        service = WorkspaceService()
        
        click.echo(f"\n{Colors.BOLD}NubiferOS Context Manager Status{Colors.END}\n")
        
        # Show database location
        click.echo(f"Database:   {service.db_path}")
        
        # Count workspaces
        workspaces = service.list_workspaces()
        click.echo(f"Workspaces: {len(workspaces)} total")
        
        # Show current workspace
        current = service.get_current_workspace()
        if current:
            click.echo(f"Current:    {current['name']} ({current['workspace_id']})")
        else:
            click.echo(f"Current:    None")
        
        click.echo()
        
    except Exception as e:
        error(f"Failed to check status: {e}")
        sys.exit(1)


if __name__ == '__main__':
    cli()
