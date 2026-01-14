#!/usr/bin/env python3
"""
D-Bus Interface for NubiferOS Context Manager
Provides system-wide workspace management service.
"""

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import logging
import json

from workspace_service import WorkspaceService, WorkspaceServiceError

logger = logging.getLogger(__name__)


class ContextManagerDBus(dbus.service.Object):
    """
    D-Bus service for context/workspace management.
    Interface: org.nubiferos.ContextManager
    """
    
    DBUS_NAME = "org.nubiferos.ContextManager"
    DBUS_PATH = "/org/nubiferos/ContextManager"
    DBUS_INTERFACE = "org.nubiferos.ContextManager"
    
    def __init__(self):
        """Initialize D-Bus service"""
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        
        bus = dbus.SessionBus()
        bus_name = dbus.service.BusName(self.DBUS_NAME, bus)
        super().__init__(bus_name, self.DBUS_PATH)
        
        self.service = WorkspaceService()
        logger.info("D-Bus service initialized")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='sssssb',
        out_signature='s'
    )
    def CreateWorkspace(self, name, provider, account_id, region, credential_id, read_only):
        """
        Create a new workspace.
        
        Args:
            name: Workspace name
            provider: Cloud provider (aws, azure, gcp, oracle, multi)
            account_id: Account identifier
            region: Default region (empty string for default)
            credential_id: Credential ID from credential manager (empty string for none)
            read_only: Read-only mode flag
        
        Returns:
            workspace_id: Unique workspace identifier
        """
        try:
            # Convert empty strings to None
            region = region if region else None
            credential_id = credential_id if credential_id else None
            
            workspace_id = self.service.create_workspace(
                name=name,
                provider=provider,
                account_id=account_id,
                region=region,
                credential_id=credential_id,
                read_only=read_only
            )
            
            logger.info(f"Created workspace via D-Bus: {workspace_id} ({name})")
            return workspace_id
            
        except WorkspaceServiceError as e:
            logger.error(f"Failed to create workspace: {e}")
            raise dbus.DBusException(str(e))
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise dbus.DBusException(f"Internal error: {e}")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='s',
        out_signature='b'
    )
    def SwitchWorkspace(self, workspace_id):
        """
        Switch to a different workspace.
        
        Args:
            workspace_id: Workspace identifier
        
        Returns:
            success: True if switched successfully
        """
        try:
            success = self.service.set_current_workspace(workspace_id)
            
            if success:
                workspace = self.service.get_workspace(workspace_id)
                logger.info(f"Switched workspace via D-Bus: {workspace_id}")
                
                # Emit signal
                self.WorkspaceSwitched(
                    workspace_id,
                    workspace['provider'],
                    workspace['account_id']
                )
            
            return success
            
        except Exception as e:
            logger.error(f"Failed to switch workspace: {e}")
            return False
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='',
        out_signature='a{sv}'
    )
    def GetCurrentWorkspace(self):
        """
        Get currently active workspace.
        
        Returns:
            workspace: Dict with workspace details (empty if none active)
        """
        try:
            workspace = self.service.get_current_workspace()
            
            if not workspace:
                return {}
            
            # Convert to D-Bus compatible format
            return {
                'workspace_id': workspace['workspace_id'],
                'name': workspace['name'],
                'provider': workspace['provider'],
                'account_id': workspace['account_id'],
                'account_name': workspace.get('account_name', ''),
                'region': workspace.get('region', ''),
                'credential_id': workspace.get('credential_id', ''),
                'read_only': workspace['read_only'],
                'created_at': workspace['created_at'],
                'last_used': workspace.get('last_used', ''),
            }
            
        except Exception as e:
            logger.error(f"Failed to get current workspace: {e}")
            return {}
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='s',
        out_signature='aa{sv}'
    )
    def ListWorkspaces(self, provider):
        """
        List all workspaces, optionally filtered by provider.
        
        Args:
            provider: Cloud provider filter (empty string for all)
        
        Returns:
            workspaces: List of workspace dicts
        """
        try:
            provider_filter = provider if provider else None
            workspaces = self.service.list_workspaces(provider_filter)
            
            # Convert to D-Bus compatible format
            result = []
            for ws in workspaces:
                result.append({
                    'workspace_id': ws['workspace_id'],
                    'name': ws['name'],
                    'provider': ws['provider'],
                    'account_id': ws['account_id'],
                    'account_name': ws.get('account_name', ''),
                    'region': ws.get('region', ''),
                    'credential_id': ws.get('credential_id', ''),
                    'read_only': ws['read_only'],
                    'created_at': ws['created_at'],
                    'last_used': ws.get('last_used', ''),
                })
            
            logger.info(f"Listed workspaces via D-Bus: {provider or 'all'}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to list workspaces: {e}")
            return []
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='s',
        out_signature='b'
    )
    def DeleteWorkspace(self, workspace_id):
        """
        Delete a workspace.
        
        Args:
            workspace_id: Workspace identifier
        
        Returns:
            success: True if deleted successfully
        """
        try:
            # Check if it's the current workspace
            current = self.service.get_current_workspace()
            if current and current['workspace_id'] == workspace_id:
                logger.warning(f"Cannot delete active workspace: {workspace_id}")
                return False
            
            deleted = self.service.delete_workspace(workspace_id)
            
            if deleted:
                logger.info(f"Deleted workspace via D-Bus: {workspace_id}")
            
            return deleted
            
        except Exception as e:
            logger.error(f"Failed to delete workspace: {e}")
            return False
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='sb',
        out_signature='b'
    )
    def SetReadOnly(self, workspace_id, read_only):
        """
        Set read-only mode for a workspace.
        
        Args:
            workspace_id: Workspace identifier
            read_only: Read-only mode flag
        
        Returns:
            success: True if updated successfully
        """
        try:
            updated = self.service.set_read_only(workspace_id, read_only)
            
            if updated:
                logger.info(f"Set read_only={read_only} via D-Bus: {workspace_id}")
            
            return updated
            
        except Exception as e:
            logger.error(f"Failed to set read-only mode: {e}")
            return False
    
    @dbus.service.signal(
        DBUS_INTERFACE,
        signature='sss'
    )
    def WorkspaceSwitched(self, workspace_id, provider, account_id):
        """
        Signal emitted when workspace is switched.
        
        Args:
            workspace_id: New workspace ID
            provider: Cloud provider
            account_id: Account ID
        """
        logger.info(f"Emitted WorkspaceSwitched signal: {workspace_id}")


def run_dbus_service():
    """Run the D-Bus service"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    try:
        service = ContextManagerDBus()
        logger.info("Starting NubiferOS Context Manager D-Bus service")
        
        mainloop = GLib.MainLoop()
        mainloop.run()
        
    except KeyboardInterrupt:
        logger.info("Service stopped by user")
    except Exception as e:
        logger.error(f"Service error: {e}")
        raise


if __name__ == '__main__':
    run_dbus_service()
