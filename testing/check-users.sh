#!/bin/bash
# Check what users exist in the live environment

echo "=========================================="
echo "User Account Check"
echo "=========================================="
echo ""

echo "1. All users with home directories:"
echo "-----------------------------------"
ls -la /home/

echo ""
echo "2. Users from /etc/passwd (non-system):"
echo "---------------------------------------"
awk -F: '$3 >= 1000 {print $1 " (UID: " $3 ")"}' /etc/passwd

echo ""
echo "3. Current user:"
echo "----------------"
whoami
id

echo ""
echo "4. Users with login shells:"
echo "---------------------------"
grep -v '/nologin\|/false' /etc/passwd | awk -F: '$3 >= 1000 {print $1 " - " $7}'

echo ""
echo "5. GDM user list (if available):"
echo "--------------------------------"
if [ -f /var/lib/AccountsService/users/* ]; then
    ls -1 /var/lib/AccountsService/users/
else
    echo "No AccountsService users found"
fi

echo ""
echo "6. Checking for live-boot/live-config:"
echo "--------------------------------------"
if dpkg -l | grep -q live-boot; then
    echo "✓ live-boot is installed"
    dpkg -l | grep live-boot
else
    echo "✗ live-boot not found"
fi

if dpkg -l | grep -q live-config; then
    echo "✓ live-config is installed"
    dpkg -l | grep live-config
else
    echo "✗ live-config not found"
fi

echo ""
echo "7. Checking live-boot configuration:"
echo "------------------------------------"
if [ -f /etc/live/config.conf ]; then
    echo "Found /etc/live/config.conf:"
    cat /etc/live/config.conf
else
    echo "No /etc/live/config.conf found"
fi

echo ""
echo "8. Checking kernel boot parameters:"
echo "-----------------------------------"
cat /proc/cmdline

echo ""
echo "=========================================="
