#!/bin/bash

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "  wp-host logs domain.com"
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

echo ""
echo "========================================="
echo " Last 50 PHP Errors"
echo "========================================="
echo ""

tail -50 /home/$USER/logs/error.log

echo ""
echo "========================================="
echo " Last 50 Nginx Errors"
echo "========================================="
echo ""

tail -50 /var/log/nginx/error.log
