#!/usr/bin/env python3
"""
NubiferOS Kubectl Wrapper
Securely injects credentials and enforces read-only mode
"""

import sys
from wrapper_base import CLIWrapperBase


class KubectlWrapper(CLIWrapperBase):
    """Kubectl wrapper with credential injection and read-only enforcement"""
    
    # Write operations to block in read-only mode
    WRITE_OPERATIONS = {
        'create', 'delete', 'apply', 'patch', 'replace', 'scale', 'autoscale',
        'expose', 'run', 'set', 'label', 'annotate', 'taint', 'drain', 'cordon',
        'uncordon', 'rollout', 'edit', 'attach', 'exec', 'port-forward', 'proxy',
        'cp', 'auth'
    }
    
    # Read-only operations that are always allowed
    READ_OPERATIONS = {
        'get', 'describe', 'logs', 'top', 'explain', 'api-resources', 'api-versions',
        'cluster-info', 'version', 'config'
    }
    
    def __init__(self):
        super().__init__('kubectl', '/usr/bin/kubectl')
    
    def is_write_operation(self, args: list) -> bool:
        """Check if kubectl command is a write operation"""
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
        """Inject credentials into environment"""
        # Kubectl typically uses kubeconfig files, not environment variables
        # The credentials would be configured in the kubeconfig
        # For now, we just pass through the environment
        
        # If we have cloud provider credentials, they might be used for
        # cloud-specific kubectl authentication (e.g., AWS EKS, Azure AKS, GKE)
        
        # AWS EKS
        if 'access_key_id' in credentials:
            env['AWS_ACCESS_KEY_ID'] = credentials['access_key_id']
            env['AWS_SECRET_ACCESS_KEY'] = credentials.get('secret_access_key', '')
        
        # Azure AKS
        if 'client_id' in credentials:
            env['AZURE_CLIENT_ID'] = credentials['client_id']
            env['AZURE_CLIENT_SECRET'] = credentials.get('client_secret', '')
            env['AZURE_TENANT_ID'] = credentials.get('tenant_id', '')
        
        return env


def main():
    """Main entry point"""
    wrapper = KubectlWrapper()
    wrapper.execute(sys.argv[1:])


if __name__ == '__main__':
    main()
