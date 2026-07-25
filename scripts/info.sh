#!/bin/bash

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "wp-host info domain.com"
    echo ""
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)
DB="${USER}_db"
DBUSER="${USER}_user"

echo ""
echo "========================================="
echo " WP Host Manager"
echo " Site Information"
echo "========================================="
echo ""

printf "%-18s %s\n" "Domain:" "$DOMAIN"
printf "%-18s %s\n" "Linux User:" "$USER"
printf "%-18s %s\n" "Database:" "$DB"
printf "%-18s %s\n" "DB User:" "$DBUSER"

echo ""

# WordPress

if [ -f "/home/$USER/public_html/wp-config.php" ]; then

VERSION=$(sudo -u "$USER" wp core version \
--path=/home/$USER/public_html 2>/dev/null)

printf "%-18s %s\n" "WordPress:" "$VERSION"

else

printf "%-18s %s\n" "WordPress:" "Not Installed"

fi

# PHP Pool

if [ -S "/run/php/php8.5-$USER.sock" ]; then

printf "%-18s %s\n" "PHP-FPM:" "Running"

else

printf "%-18s %s\n" "PHP-FPM:" "Missing"

fi

# Nginx

if [ -f "/etc/nginx/sites-enabled/$DOMAIN.conf" ]; then

printf "%-18s %s\n" "Nginx:" "Enabled"

else

printf "%-18s %s\n" "Nginx:" "Missing"

fi

# SSL

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then

EXPIRY=$(openssl x509 \
-enddate \
-noout \
-in /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
| cut -d= -f2)

printf "%-18s %s\n" "SSL:" "Installed"

printf "%-18s %s\n" "SSL Expiry:" "$EXPIRY"

else

printf "%-18s %s\n" "SSL:" "Not Installed"

fi

# Disk

if [ -d "/home/$USER/public_html" ]; then

SIZE=$(du -sh /home/$USER/public_html | cut -f1)

printf "%-18s %s\n" "Disk Usage:" "$SIZE"

fi

# Backups

BACKUP_DIR="/opt/wp-host/backups/$DOMAIN"

if [ -d "$BACKUP_DIR" ]; then

COUNT=$(find "$BACKUP_DIR" \
-mindepth 1 \
-maxdepth 1 \
-type d | wc -l)

LAST=$(find "$BACKUP_DIR" \
-mindepth 1 \
-maxdepth 1 \
-type d | sort | tail -1 | xargs basename)

printf "%-18s %s\n" "Backups:" "$COUNT"

printf "%-18s %s\n" "Last Backup:" "$LAST"

else

printf "%-18s %s\n" "Backups:" "0"

fi

echo ""
