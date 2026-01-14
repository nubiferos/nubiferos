#!/usr/bin/env python3
"""
NubiferOS GCloud CLI Wrapper
Securely injects credentials and enforces read-only mode
"""

import sys
import os
import tempfile
from wrapper_base import CLIWrapperBase


class GCloudWrapper(CLIWrapperBase):
    """GCloud CLI wrapper with credential injection and read-only enforcement"""
    
    # Write operations to block in read-only mode
    WRITE_OPERATIONS = {
        'create', 'delete', 'update', 'insert', 'patch', 'add', 'remove',
        'start', 'stop', 'reset', 'restart', 'set', 'unset', 'enable', 'disable',
        'attach', 'detach', 'move', 'restore', 'import', 'export', 'deploy',
        'cancel', 'revoke', 'grant'
    }
    
    def __init__(self):
        super().__init__('gcloud', '/usr/bin/gcloud')
        self.temp_key_file = None
    
    def is_write_operation(self, args: list) -> bool:
        """Check if GCloud command is a write operation"""
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
        """Inject GCP credentials into environment"""
        if 'service_account_key' in credentials:
            # GCP uses a JSON key file, so we need to write it to a temp file
            # and set GOOGLE_APPLICATION_CREDENTIALS
            try:
                # Create temporary file for service account key
                fd, self.temp_key_file = tempfile.mkstemp(suffix='.json', prefix='gcp-key-')
                
                with os.fdopen(fd, 'w') as f:
                    f.write(credentials['service_account_key'])
                
                # Set permissions to 600
                os.chmod(self.temp_key_file, 0o600)
                
                # Set environment variable
                env['GOOGLE_APPLICATION_CREDENTIALS'] = self.temp_key_file
                
            except Exception as e:
                if self.temp_key_file and os.path.exists(self.temp_key_file):
                    os.unlink(self.temp_key_file)
                raise
        
        return env
    
    def cleanup(self):
        """Clean up temporary key file"""
        if self.temp_key_file and os.path.exists(self.temp_key_file):
            try:
                os.unlink(self.temp_key_file)
            except:
                pass
    
    def execute(self, args: list):
        """Execute with cleanup"""
        try:
            super().execute(args)
        finally:
            self.cleanup()


def main():
    """Main entry point"""
    wrapper = GCloudWrapper()
    wrapper.execute(sys.argv[1:])


if __name__ == '__main__':
    main()
