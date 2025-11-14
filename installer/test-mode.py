#!/usr/bin/env python3
# Calamares module for enabling post-installation tests

import subprocess
import libcalamares

def run():
    """
    Enable post-installation tests if user selected test mode
    """
    
    # Get configuration
    config = libcalamares.job.configuration
    test_mode_enabled = config.get("testModeEnabled", False)
    
    if not test_mode_enabled:
        libcalamares.utils.debug("Test mode not enabled, skipping")
        return None
    
    libcalamares.utils.debug("Test mode enabled, configuring post-installation tests")
    
    # Get root mount point
    root_mount_point = libcalamares.globalstorage.value("rootMountPoint")
    
    if not root_mount_point:
        libcalamares.utils.warning("No root mount point found")
        return ("No root mount point found", "Cannot enable test mode")
    
    try:
        # Create flag file
        flag_dir = f"{root_mount_point}/etc/nubifer"
        subprocess.run(["mkdir", "-p", flag_dir], check=True)
        subprocess.run(["touch", f"{flag_dir}/run-post-install-tests"], check=True)
        
        # Copy test script
        subprocess.run([
            "cp",
            "/usr/share/nubifer/tests/post-install-tests.sh",
            f"{root_mount_point}/usr/local/bin/nubifer-post-install-tests"
        ], check=True)
        
        subprocess.run([
            "chmod", "+x",
            f"{root_mount_point}/usr/local/bin/nubifer-post-install-tests"
        ], check=True)
        
        # Copy systemd service
        subprocess.run([
            "cp",
            "/usr/share/nubifer/installer/post-install-test.service",
            f"{root_mount_point}/etc/systemd/system/"
        ], check=True)
        
        # Enable service (will run on first boot)
        subprocess.run([
            "chroot", root_mount_point,
            "systemctl", "enable", "post-install-test.service"
        ], check=True)
        
        libcalamares.utils.debug("Post-installation tests configured successfully")
        
        # Show message to user
        libcalamares.globalstorage.insert("testModeMessage",
            "Post-installation tests enabled. Results will be available at /var/log/nubifer-test-report.txt after first boot.")
        
        return None
        
    except subprocess.CalledProcessError as e:
        error_msg = f"Failed to enable test mode: {str(e)}"
        libcalamares.utils.warning(error_msg)
        return (error_msg, "Test mode configuration failed")
    except Exception as e:
        error_msg = f"Unexpected error enabling test mode: {str(e)}"
        libcalamares.utils.warning(error_msg)
        return (error_msg, "Test mode configuration failed")
