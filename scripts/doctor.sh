#!/bin/bash
source /opt/wp-host/config/settings.conf
echo ""
echo "========================================="
echo " WP Host Manager"
echo " System Doctor"
echo "========================================="
echo ""

PASS=0
FAIL=0

check_service() {

SERVICE="$1"

if systemctl is-active --quiet "$SERVICE"; then
    printf "✅ %-20s Running\n" "$SERVICE"
    PASS=$((PASS+1))
else
    printf "❌ %-20s Stopped\n" "$SERVICE"
    FAIL=$((FAIL+1))
fi

}

check_service nginx
check_service php8.5-fpm
check_service mariadb
check_service redis-server
check_service fail2ban

echo ""

for DOMAIN in $(cat /opt/wp-host/sites.list)
do

    USER=$(echo "$DOMAIN" | cut -d'.' -f1)

    echo "Checking $DOMAIN"

    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        echo "  ✅ SSL"
    else
        echo "  ❌ SSL"
        FAIL=$((FAIL+1))
    fi

    if [ -f "/etc/nginx/sites-enabled/$DOMAIN.conf" ]; then
        echo "  ✅ Nginx"
    else
        echo "  ❌ Nginx"
        FAIL=$((FAIL+1))
    fi

    if [ -S "/run/php/php8.5-$USER.sock" ]; then
        echo "  ✅ PHP Pool"
    else
        echo "  ❌ PHP Pool"
        FAIL=$((FAIL+1))
    fi

    if [ -d "/home/$USER/public_html" ]; then
        echo "  ✅ Files"
    else
        echo "  ❌ Files"
        FAIL=$((FAIL+1))
    fi

    echo ""

done

echo "========================================="

echo "Passed : $PASS"

echo "Failed : $FAIL"

echo "========================================="


echo ""
echo "Checking Backups"
echo "-----------------------------------------"

while read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue

    BACKUP_DIR="/opt/wp-host/backups/$DOMAIN"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ $DOMAIN - No backups"
        continue
    fi

    LAST=$(find "$BACKUP_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    | sort \
    | tail -1)

    if [ -f "$LAST/files.tar.gz" ] && [ -f "$LAST/database.sql.gz" ]; then
        echo "✅ $DOMAIN - Backup OK"
    else
        echo "❌ $DOMAIN - Backup incomplete"
    fi

done < "$SITE_LIST"
