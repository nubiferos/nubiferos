#!/usr/bin/env python3
"""
NubiferOS Credential Manager CLI
Command-line interface for managing cloud credentials.
"""

import click
import sys
import json
import getpass
from pathlib import Path
from typing import Optional

from credential_service import CredentialService, CredentialServiceError
from pass_backend import PassBackendError, PassNotInitializedError

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
@click.version_option(version='1.0.0')
def cli():
    """
    NubiferOS Credential Manager
    
    Securely manage cloud credentials using pass (password-store).
    """
    pass


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True,
              help='Cloud provider')
@click.option('--account-id', required=True, help='Account identifier (e.g., AWS account ID)')
@click.option('--account-name', required=True, help='Human-readable account name')
def add(provider, account_id, account_name):
    """Add credentials for a cloud account"""
    
    try:
        service = CredentialService()
        
        # Check prerequisites
        success_check, issues = service.check_prerequisites()
        if not success_check:
            error("Prerequisites not met:")
            for issue in issues:
                click.echo(f"  {issue}")
            sys.exit(1)
        
        # Prompt for credentials based on provider
        credentials = {}
        
        if provider == 'aws':
            click.echo(f"\n{Colors.BOLD}Enter AWS credentials:{Colors.END}")
            credentials['access_key_id'] = click.prompt('AWS Access Key ID', hide_input=False)
            credentials['secret_access_key'] = click.prompt('AWS Secret Access Key', hide_input=True)
        
        elif provider == 'azure':
            click.echo(f"\n{Colors.BOLD}Enter Azure service principal credentials:{Colors.END}")
            credentials['client_id'] = click.prompt('Azure Client ID', hide_input=False)
            credentials['client_secret'] = click.prompt('Azure Client Secret', hide_input=True)
            credentials['tenant_id'] = click.prompt('Azure Tenant ID', hide_input=False)
        
        elif provider == 'gcp':
            click.echo(f"\n{Colors.BOLD}Enter GCP service account key:{Colors.END}")
            key_file = click.prompt('Path to service account JSON key file', type=click.Path(exists=True))
            with open(key_file, 'r') as f:
                credentials['service_account_key'] = f.read()
        
        # Add credentials
        service.add_credential(provider, account_id, account_name, credentials)
        
        success(f"Added credentials for {provider}/{account_id} ({account_name})")
        info(f"Credentials stored in pass at: nubiferos/credentials/{provider}/{account_id}/")
        
    except CredentialServiceError as e:
        error(f"Failed to add credentials: {e}")
        sys.exit(1)
    except PassBackendError as e:
        error(f"Pass backend error: {e}")
        sys.exit(1)
    except Exception as e:
        error(f"Unexpected error: {e}")
        sys.exit(1)


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), 
              help='Filter by cloud provider')
@click.option('--format', type=click.Choice(['table', 'json']), default='table',
              help='Output format')
def list(provider, format):
    """List all stored credentials"""
    
    try:
        service = CredentialService()
        accounts = service.list_accounts(provider)
        
        if not accounts:
            if provider:
                warning(f"No credentials found for {provider}")
            else:
                warning("No credentials found")
            return
        
        if format == 'json':
            click.echo(json.dumps(accounts, indent=2))
        else:
            # Table format
            click.echo(f"\n{Colors.BOLD}Stored Credentials:{Colors.END}\n")
            
            # Header
            click.echo(f"{'Provider':<10} {'Account ID':<20} {'Account Name':<25} {'Auth Type':<20} {'Created':<20}")
            click.echo("-" * 95)
            
            # Rows
            for acc in accounts:
                created = acc['created_at'][:19]  # Trim to datetime
                click.echo(
                    f"{acc['provider']:<10} "
                    f"{acc['account_id']:<20} "
                    f"{acc['account_name']:<25} "
                    f"{acc['auth_type']:<20} "
                    f"{created:<20}"
                )
            
            click.echo(f"\n{Colors.BOLD}Total:{Colors.END} {len(accounts)} credential(s)\n")
        
    except Exception as e:
        error(f"Failed to list credentials: {e}")
        sys.exit(1)


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True,
              help='Cloud provider')
@click.option('--account-id', required=True, help='Account identifier')
def show(provider, account_id):
    """Show credential details (without revealing secrets)"""
    
    try:
        service = CredentialService()
        
        # Get metadata
        accounts = service.list_accounts(provider)
        account = next((a for a in accounts if a['account_id'] == account_id), None)
        
        if not account:
            error(f"Credential not found: {provider}/{account_id}")
            sys.exit(1)
        
        # Display metadata
        click.echo(f"\n{Colors.BOLD}Credential Details:{Colors.END}\n")
        click.echo(f"Provider:     {account['provider']}")
        click.echo(f"Account ID:   {account['account_id']}")
        click.echo(f"Account Name: {account['account_name']}")
        click.echo(f"Auth Type:    {account['auth_type']}")
        click.echo(f"Created:      {account['created_at']}")
        click.echo(f"Updated:      {account['updated_at']}")
        
        # Show pass paths (not actual values)
        click.echo(f"\n{Colors.BOLD}Pass Store Paths:{Colors.END}")
        base_path = f"nubiferos/credentials/{provider}/{account_id}"
        
        if provider == 'aws':
            click.echo(f"  - {base_path}/access_key_id")
            click.echo(f"  - {base_path}/secret_access_key")
        elif provider == 'azure':
            click.echo(f"  - {base_path}/client_id")
            click.echo(f"  - {base_path}/client_secret")
            click.echo(f"  - {base_path}/tenant_id")
        elif provider == 'gcp':
            click.echo(f"  - {base_path}/service_account_key")
        
        click.echo(f"\n{Colors.BLUE}Tip:{Colors.END} Use 'pass show <path>' to view actual credential values\n")
        
    except Exception as e:
        error(f"Failed to show credential: {e}")
        sys.exit(1)


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True,
              help='Cloud provider')
@click.option('--account-id', required=True, help='Account identifier')
@click.confirmation_option(prompt='Are you sure you want to delete this credential?')
def delete(provider, account_id):
    """Delete credentials for an account"""
    
    try:
        service = CredentialService()
        deleted = service.delete_credential(provider, account_id)
        
        if deleted:
            success(f"Deleted credentials for {provider}/{account_id}")
        else:
            warning(f"Credential not found: {provider}/{account_id}")
        
    except Exception as e:
        error(f"Failed to delete credential: {e}")
        sys.exit(1)


@cli.command()
@click.option('--provider', type=click.Choice(['aws', 'azure', 'gcp']), required=True,
              help='Cloud provider')
@click.option('--account-id', required=True, help='Account identifier')
def test(provider, account_id):
    """Test if credentials can be retrieved"""
    
    try:
        service = CredentialService()
        success_test, message = service.test_credential(provider, account_id)
        
        if success_test:
            success(f"Credentials OK: {message}")
        else:
            error(f"Credentials failed: {message}")
            sys.exit(1)
        
    except Exception as e:
        error(f"Failed to test credential: {e}")
        sys.exit(1)


@cli.command()
def init():
    """Initialize pass store for credential management"""
    
    try:
        from pass_backend import PassBackend
        
        backend = PassBackend()
        
        if backend.is_initialized():
            info("Pass store is already initialized")
            gpg_key = backend.get_gpg_key_id()
            click.echo(f"GPG Key ID: {gpg_key}")
            return
        
        # List available GPG keys
        gpg_keys = backend.list_gpg_keys()
        
        if not gpg_keys:
            error("No GPG keys found")
            click.echo("\nCreate a GPG key with:")
            click.echo("  gpg --gen-key")
            click.echo("\nThen run this command again.")
            sys.exit(1)
        
        # Display available keys
        click.echo(f"\n{Colors.BOLD}Available GPG Keys:{Colors.END}\n")
        for i, key in enumerate(gpg_keys, 1):
            click.echo(f"{i}. {key['keyid']}: {key['uid']}")
        
        # Prompt for key selection
        choice = click.prompt('\nSelect GPG key number', type=int)
        
        if choice < 1 or choice > len(gpg_keys):
            error("Invalid selection")
            sys.exit(1)
        
        selected_key = gpg_keys[choice - 1]['keyid']
        
        # Initialize pass
        click.echo(f"\nInitializing pass with GPG key: {selected_key}")
        backend.initialize(selected_key)
        
        success("Pass store initialized successfully")
        info("You can now add credentials with: nubifer-creds add")
        
    except Exception as e:
        error(f"Failed to initialize: {e}")
        sys.exit(1)


@cli.command()
def status():
    """Check credential manager status"""
    
    try:
        service = CredentialService()
        
        click.echo(f"\n{Colors.BOLD}NubiferOS Credential Manager Status{Colors.END}\n")
        
        # Check prerequisites
        success_check, issues = service.check_prerequisites()
        
        if success_check:
            success("All prerequisites met")
            
            # Show pass store info
            gpg_key = service.pass_backend.get_gpg_key_id()
            click.echo(f"GPG Key ID: {gpg_key}")
            
            # Show database location
            click.echo(f"Database:   {service.db_path}")
            
            # Count credentials
            accounts = service.list_accounts()
            click.echo(f"Credentials: {len(accounts)} stored")
            
        else:
            warning("Prerequisites not met:")
            for issue in issues:
                click.echo(f"  {issue}")
        
        click.echo()
        
    except Exception as e:
        error(f"Failed to check status: {e}")
        sys.exit(1)


if __name__ == '__main__':
    cli()
