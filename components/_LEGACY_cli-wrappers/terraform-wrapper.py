#!/usr/bin/env python3
"""
NubiferOS Terraform Wrapper
Securely injects credentials and enforces read-only mode
"""

import sys
from wrapper_base import CLIWrapperBase


class TerraformWrapper(CLIWrapperBase):
    """Terraform wrapper with credential injection and read-only enforcement"""
    
    # Write operations to block in read-only mode
    WRITE_OPERATIONS = {
        'apply', 'destroy', 'import', 'taint', 'untaint', 'state'
    }
    
    # Read-only operations that are always allowed
    READ_OPERATIONS = {
        'plan', 'show', 'validate', 'fmt', 'version', 'output', 'graph',
        'providers', 'console', 'refresh'
    }
    
    def __init__(self):
        super().__init__('terraform', '/usr/bin/terraform')
    
    def is_write_operation(self, args: list) -> bool:
        """Check if Terraform command is a write operation"""
        if not args:
            return False
        
        # First argument is usually the command
        command = args[0].lower() if args else ''
        
        # Check if it's a write operation
        if command in self.WRITE_OPERATIONS:
            return True
        
        # Check if it's explicitly a read operation
        if command in self.READ_OPERATIONS:
            return False
        
        # Default to safe (treat as write if unknown)
        return True
    
    def inject_credentials(self, credentials: dict, env: dict) -> dict:
        """Inject credentials into environment based on provider"""
        # Terraform uses the same environment variables as the cloud CLIs
        
        # AWS credentials
        if 'access_key_id' in credentials:
            env['AWS_ACCESS_KEY_ID'] = credentials['access_key_id']
            env['AWS_SECRET_ACCESS_KEY'] = credentials.get('secret_access_key', '')
        
        # Azure credentials
        if 'client_id' in credentials:
            env['ARM_CLIENT_ID'] = credentials['client_id']
            env['ARM_CLIENT_SECRET'] = credentials.get('client_secret', '')
            env['ARM_TENANT_ID'] = credentials.get('tenant_id', '')
            env['ARM_SUBSCRIPTION_ID'] = credentials.get('subscription_id', '')
        
        # GCP credentials
        if 'service_account_key' in credentials:
            # For Terraform, we'd need to write the key to a file
            # For now, just set the variable (full implementation would be similar to gcloud)
            env['GOOGLE_CREDENTIALS'] = credentials['service_account_key']
        
        return env


def main():
    """Main entry point"""
    wrapper = TerraformWrapper()
    wrapper.execute(sys.argv[1:])


if __name__ == '__main__':
    main()
