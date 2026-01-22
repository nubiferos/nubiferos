#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# NubiferOS - Check that encryption is enabled before installation proceeds

import libcalamares
from libcalamares.utils import debug

def run():
    """
    Check that disk encryption is enabled.
    This runs at the start of the exec phase - if encryption isn't enabled,
    the installation fails immediately with a clear message.
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

    if not encrypt and not has_encrypted_root:
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
            "Click 'Back' to return to partitioning and enable encryption."
        )

    # Encryption is enabled, proceed
    debug("Encryption check passed")
    return None
