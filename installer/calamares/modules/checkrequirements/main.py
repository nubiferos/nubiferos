#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# NubiferOS - Check that encryption is enabled before installation proceeds

import libcalamares
from libcalamares.utils import debug
import os

# Override file - if this exists, skip encryption check (for "that one person")
OVERRIDE_FILE = "/tmp/nubiferos-skip-encryption-i-know-what-im-doing"

def run():
    """
    Check that disk encryption is enabled.
    This runs at the start of the exec phase - if encryption isn't enabled,
    the installation fails immediately with a clear message.

    Override: Create /tmp/nubiferos-skip-encryption-i-know-what-im-doing
    to bypass this check (you'll get a persistent nag notification forever).
    """

    gs = libcalamares.globalstorage

    # Check if encryption is enabled in partition settings
    # The partition module stores this in GlobalStorage
    encrypt = gs.value("encryptedRootPartition")

    # Also check the partition layout for encryption flag
    partitions = gs.value("partitions")
    has_encrypted_root = False

    if partitions:
        for part in partitions:
            if part.get("mountPoint") == "/" and part.get("luksMapperName"):
                has_encrypted_root = True
                break

    debug(f"encryptedRootPartition: {encrypt}")
    debug(f"has_encrypted_root from partitions: {has_encrypted_root}")

    encryption_enabled = encrypt or has_encrypted_root

    if not encryption_enabled:
        # Check for override file
        if os.path.exists(OVERRIDE_FILE):
            debug("WARNING: Encryption override detected! Proceeding without encryption.")
            debug("User will be nagged FOREVER about this decision.")

            # Set flag in GlobalStorage so we can create the nag notification
            gs.insert("nubiferos_no_encryption_override", True)

            # Log this shameful decision
            try:
                with open("/tmp/nubiferos-install-no-encryption.log", "w") as f:
                    f.write("User chose to install without encryption.\n")
                    f.write("They were warned. They did it anyway.\n")
                    f.write("Eternal nagging enabled.\n")
            except:
                pass

            return None  # Allow installation to proceed (with shame)

        return (
            "Disk encryption is required",
            "NubiferOS requires full disk encryption to protect your cloud credentials. "
            "Please go back to the partition step and enable 'Encrypt system' before continuing. "
            "\n\n"
            "Why is this required?\n"
            "• Your cloud provider credentials (AWS, Azure, GCP) will be stored on this system\n"
            "• Without encryption, anyone with physical access could steal your credentials\n"
            "• Encryption protects your data even if your laptop is lost or stolen\n"
            "\n"
            "Click 'Back' to return to partitioning and enable encryption.\n"
            "\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "For that one person who REALLY knows what they're doing:\n"
            "Open a terminal and run:\n"
            "  touch /tmp/nubiferos-skip-encryption-i-know-what-im-doing\n"
            "\n"
            "Then click Install again. You'll get a permanent reminder\n"
            "in your system tray about your questionable life choices.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

    # Encryption is enabled, all is well
    gs.insert("nubiferos_no_encryption_override", False)
    debug("Encryption check passed")
    return None
