#!/bin/bash
# Apply patched Calamares configs and boot
echo "=== Applying Calamares patches ==="
cp /mnt/patch/settings.conf /etc/calamares/settings.conf
cp /mnt/patch/netinstall-packages.yaml /etc/calamares/modules/netinstall-packages.yaml
echo "Patched settings.conf and netinstall-packages.yaml"

# Disable reboot-on-exit so we can see errors
sed -i 's/reboot/true/g' /home/installer/.xinitrc /home/installer/.bash_logout /home/installer/.bash_profile 2>/dev/null
echo "Disabled auto-reboot"

echo "=== Starting system ==="
exec /sbin/init
