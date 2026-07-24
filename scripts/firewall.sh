#!/bin/bash

echo ""
echo "========================================="
echo " WP Host Firewall"
echo "========================================="
echo ""

ufw status

echo ""

echo "Fail2Ban"

systemctl is-active fail2ban

echo ""

echo "SSH"

ss -tulpn | grep :22

echo ""

echo "HTTP"

ss -tulpn | grep :80

echo ""

echo "HTTPS"

ss -tulpn | grep :443
