#!/usr/bin/env python3
"""
NubiferOS Azure CLI Wrapper
Securely injects credentials and enforces read-only mode
"""

import sys
from wrapper_base import CLIWrapperBase


class AzureWrapper(CLIWrapperBase):
    """Azure CLI wrapper with credential injection and read-only enforcement"""
    
    # Write operations to block in read-only mode
    WRITE_OPERATIONS = {
        'create', 'delete', 'update', 'set', 'add', 'remove', 'start', 'stop',
        'restart', 'deallocate', 'apply', 'attach', 'detach', 'enable', 'disable',
        'register', 'unregister', 'lock', 'unlock', 'move', 'restore', 'reset',
        'revoke', 'grant', 'assign', 'cancel', 'accept', 'reject'
    }
    
    def __init__(self):
        super().__init__('az', '/usr/bin/az')
    
    def is_write_operation(self, args: list) -> bool:
        """Check if Azure command is a write operation"""
        if not args:
            return False
        
        # Check all arguments for write operation keywords
        args_lower = [arg.lower() for arg in args]
        
        for arg in args_lower:
            for write_op in self.WRITE_OPERATIONS:
                if write_op in arg:
                    return True
        
        return False
    
    def inject_credentials(self, credentials: dict, env: dict) -> dict:
        """Inject Azure credentials into environment"""
        if 'client_id' in credentials:
            env['AZURE_CLIENT_ID'] = credentials['client_id']
        
        if 'client_secret' in credentials:
            env['AZURE_CLIENT_SECRET'] = credentials['client_secret']
        
        if 'tenant_id' in credentials:
            env['AZURE_TENANT_ID'] = credentials['tenant_id']
        
        return env


def main():
    """Main entry point"""
    wrapper = AzureWrapper()
    wrapper.execute(sys.argv[1:])


if __name__ == '__main__':
    main()
