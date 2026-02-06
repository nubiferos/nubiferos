#!/usr/bin/env python3
"""
NubiferOS AWS CLI Wrapper
Securely injects credentials and enforces read-only mode
"""

import sys
from wrapper_base import CLIWrapperBase


class AWSWrapper(CLIWrapperBase):
    """AWS CLI wrapper with credential injection and read-only enforcement"""
    
    # Write operations to block in read-only mode
    WRITE_OPERATIONS = {
        'create', 'delete', 'put', 'update', 'terminate', 'stop', 'modify',
        'attach', 'detach', 'start', 'reboot', 'run', 'launch', 'associate',
        'disassociate', 'enable', 'disable', 'register', 'deregister',
        'allocate', 'release', 'revoke', 'authorize', 'import', 'export',
        'copy', 'restore', 'reset', 'cancel', 'purchase', 'accept', 'reject'
    }
    
    def __init__(self):
        super().__init__('aws', '/usr/bin/aws')
    
    def is_write_operation(self, args: list) -> bool:
        """Check if AWS command is a write operation"""
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
        """Inject AWS credentials into environment"""
        if 'access_key_id' in credentials:
            env['AWS_ACCESS_KEY_ID'] = credentials['access_key_id']
        
        if 'secret_access_key' in credentials:
            env['AWS_SECRET_ACCESS_KEY'] = credentials['secret_access_key']
        
        # Session token if present (for temporary credentials)
        if 'session_token' in credentials:
            env['AWS_SESSION_TOKEN'] = credentials['session_token']
        
        return env


def main():
    """Main entry point"""
    wrapper = AWSWrapper()
    wrapper.execute(sys.argv[1:])


if __name__ == '__main__':
    main()
