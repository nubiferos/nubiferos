#!/usr/bin/env python3
"""
D-Bus Interface for NubiferOS Credential Manager
Provides system-wide credential management service.
"""

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import logging
import json

from credential_service import CredentialService, CredentialServiceError

logger = logging.getLogger(__name__)


class CredentialManagerDBus(dbus.service.Object):
    """
    D-Bus service for credential management.
    Interface: org.nubiferos.CredentialManager
    """
    
    DBUS_NAME = "org.nubiferos.CredentialManager"
    DBUS_PATH = "/org/nubiferos/CredentialManager"
    DBUS_INTERFACE = "org.nubiferos.CredentialManager"
    
    def __init__(self):
        """Initialize D-Bus service"""
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        
        bus = dbus.SessionBus()
        bus_name = dbus.service.BusName(self.DBUS_NAME, bus)
        super().__init__(bus_name, self.DBUS_PATH)
        
        self.service = CredentialService()
        logger.info("D-Bus service initialized")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='sssa{ss}',
        out_signature='bs'
    )
    def AddCredential(self, provider, account_id, account_name, credentials):
        """
        Add or update credentials for an account.
        
        Args:
            provider: Cloud provider (aws, azure, gcp)
            account_id: Account identifier
            account_name: Human-readable account name
            credentials: Dict of credential key-value pairs
        
        Returns:
            (success: bool, message: str)
        """
        try:
            # Convert dbus.Dictionary to regular dict
            creds_dict = dict(credentials)
            
            self.service.add_credential(provider, account_id, account_name, creds_dict)
            logger.info(f"Added credential via D-Bus: {provider}/{account_id}")
            return (True, "Credential added successfully")
            
        except CredentialServiceError as e:
            logger.error(f"Failed to add credential: {e}")
            return (False, str(e))
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return (False, f"Internal error: {e}")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='ss',
        out_signature='a{ss}'
    )
    def GetCredential(self, provider, account_id):
        """
        Retrieve credentials for an account.
        
        Args:
            provider: Cloud provider
            account_id: Account identifier
        
        Returns:
            Dict with credential keys (empty if not found)
        """
        try:
            creds = self.service.get_credential(provider, account_id)
            
            if creds is None:
                logger.warning(f"Credential not found: {provider}/{account_id}")
                return {}
            
            # Never log actual credential values
            logger.info(f"Retrieved credential via D-Bus: {provider}/{account_id}")
            return creds
            
        except Exception as e:
            logger.error(f"Failed to retrieve credential: {e}")
            return {}
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='s',
        out_signature='aa{ss}'
    )
    def ListAccounts(self, provider):
        """
        List all accounts for a provider (or all if provider is empty).
        
        Args:
            provider: Cloud provider (or empty string for all)
        
        Returns:
            List of dicts with account metadata
        """
        try:
            provider_filter = provider if provider else None
            accounts = self.service.list_accounts(provider_filter)
            
            logger.info(f"Listed accounts via D-Bus: {provider or 'all'}")
            return accounts
            
        except Exception as e:
            logger.error(f"Failed to list accounts: {e}")
            return []
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='ss',
        out_signature='bs'
    )
    def DeleteCredential(self, provider, account_id):
        """
        Delete credentials for an account.
        
        Args:
            provider: Cloud provider
            account_id: Account identifier
        
        Returns:
            (success: bool, message: str)
        """
        try:
            deleted = self.service.delete_credential(provider, account_id)
            
            if deleted:
                logger.info(f"Deleted credential via D-Bus: {provider}/{account_id}")
                return (True, "Credential deleted successfully")
            else:
                return (False, "Credential not found")
                
        except Exception as e:
            logger.error(f"Failed to delete credential: {e}")
            return (False, f"Internal error: {e}")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='ss',
        out_signature='bs'
    )
    def TestCredential(self, provider, account_id):
        """
        Test if credentials can be retrieved.
        
        Args:
            provider: Cloud provider
            account_id: Account identifier
        
        Returns:
            (success: bool, message: str)
        """
        try:
            success, message = self.service.test_credential(provider, account_id)
            logger.info(f"Tested credential via D-Bus: {provider}/{account_id} - {message}")
            return (success, message)
            
        except Exception as e:
            logger.error(f"Failed to test credential: {e}")
            return (False, f"Internal error: {e}")
    
    @dbus.service.method(
        DBUS_INTERFACE,
        in_signature='',
        out_signature='bas'
    )
    def CheckPrerequisites(self):
        """
        Check if all prerequisites are met.
        
        Returns:
            (success: bool, issues: list of strings)
        """
        try:
            success, issues = self.service.check_prerequisites()
            return (success, issues)
        except Exception as e:
            logger.error(f"Failed to check prerequisites: {e}")
            return (False, [str(e)])


def run_dbus_service():
    """Run the D-Bus service"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    try:
        service = CredentialManagerDBus()
        logger.info("Starting NubiferOS Credential Manager D-Bus service")
        
        mainloop = GLib.MainLoop()
        mainloop.run()
        
    except KeyboardInterrupt:
        logger.info("Service stopped by user")
    except Exception as e:
        logger.error(f"Service error: {e}")
        raise


if __name__ == '__main__':
    run_dbus_service()
