#!/bin/bash
# Safe Calamares launcher - works around segfault issues

# Disable QML slideshow to avoid threading issues
export QT_QPA_PLATFORM=xcb
export QT_LOGGING_RULES="*.debug=false"

# Launch without debug to avoid thread priority warnings
sudo calamares

# Alternative: Launch with minimal features
# sudo calamares --config /etc/calamares/settings-minimal.conf
