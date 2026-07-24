#!/bin/bash

source /opt/wp-host/config/settings.conf

echo ""
echo "========================================="
echo "      WP HOST SECURITY CHECK"
echo "========================================="
echo ""

echo "Firewall"
ufw status | head -1

echo ""
echo "Fail2Ban"
systemctl is-active fail2ban

echo ""
echo "SSH Root Login"

grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "Default"

echo ""
echo "Password Authentication"

grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "Default"

echo ""
echo "Open Ports"

ss -tulpn | grep LISTEN

echo ""
echo "Disk Usage"

df -h /

echo ""
echo "Memory"

free -h

echo ""
echo "========================================="
echo "Security Check Complete"
echo "========================================="
