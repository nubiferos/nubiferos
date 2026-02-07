#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# NubiferOS - Bridge between packagechooser selection and install-selected-tools.sh
#
# Reads the packagechooser_nubiferai value from GlobalStorage and creates
# a marker file so install-selected-tools.sh knows to install NubiferAI.

import libcalamares
from libcalamares.utils import debug
import os

MARKER_DIR = "/tmp/nubiferos-install-markers"
MARKER_FILE = os.path.join(MARKER_DIR, "install-nubiferai")


def run():
    """
    Check if the user selected NubiferAI in the packagechooser page.
    If so, create a marker file for install-selected-tools.sh to pick up.
    """

    gs = libcalamares.globalstorage
    selection = gs.value("packagechooser_nubiferai")

    debug(f"NubiferAI packagechooser selection: {selection!r}")

    os.makedirs(MARKER_DIR, exist_ok=True)

    if selection and selection == "nubiferai":
        debug("NubiferAI selected — creating install marker")
        with open(MARKER_FILE, "w") as f:
            f.write("selected\n")
        gs.insert("nubiferos_install_nubiferai", True)
    else:
        debug("NubiferAI not selected — skipping")
        # Remove marker if it exists (in case user went back and changed their mind)
        if os.path.exists(MARKER_FILE):
            os.remove(MARKER_FILE)
        gs.insert("nubiferos_install_nubiferai", False)

    return None
