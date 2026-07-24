#!/bin/bash

source /opt/wp-host/config/settings.conf

echo ""
echo "========================================="
echo "        WP HOST HEALTH CHECK"
echo "========================================="
echo ""

check_service() {
    if systemctl is-active --quiet "$1"; then
        printf "✅ %-20s Running\n" "$1"
    else
        printf "❌ %-20s Stopped\n" "$1"
    fi
}

echo "Services"
echo "-----------------------------------------"

check_service "$NGINX_SERVICE"
check_service "$PHP_SERVICE"
check_service "$DB_SERVICE"
check_service "redis-server"
check_service "fail2ban"

echo ""
echo "System"
echo "-----------------------------------------"

echo "CPU Load : $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory   : $(free -h | awk '/Mem:/ {print $3 \" / \" $2}')"
echo "Disk     : $(df -h / | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}')"

echo ""
echo "SSL Certificates"
echo "-----------------------------------------"

while read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue

    if [ -f "$SSL_DIR/$DOMAIN/fullchain.pem" ]; then

        EXPIRY=$(openssl x509 \
        -enddate \
        -noout \
        -in "$SSL_DIR/$DOMAIN/fullchain.pem" \
        | cut -d= -f2)

        printf "✅ %-35s %s\n" "$DOMAIN" "$EXPIRY"

    else

        printf "❌ %-35s Missing\n" "$DOMAIN"

    fi

done < "$SITE_LIST"

echo ""
echo "Backups"
echo "-----------------------------------------"

while read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue

    if [ -d "$BACKUP_DIR/$DOMAIN" ]; then

        LAST=$(find "$BACKUP_DIR/$DOMAIN" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | sort \
        | tail -1)

        LAST=$(basename "$LAST")

        printf "✅ %-35s %s\n" "$DOMAIN" "$LAST"

    else

        printf "❌ %-35s None\n" "$DOMAIN"

    fi

done < "$SITE_LIST"

echo ""
echo "========================================="
echo "Overall Health"
echo "========================================="

FAILED=0

systemctl is-active --quiet "$NGINX_SERVICE" || FAILED=$((FAILED+1))
systemctl is-active --quiet "$PHP_SERVICE" || FAILED=$((FAILED+1))
systemctl is-active --quiet "$DB_SERVICE" || FAILED=$((FAILED+1))
systemctl is-active --quiet redis-server || FAILED=$((FAILED+1))
systemctl is-active --quiet fail2ban || FAILED=$((FAILED+1))

if [ "$FAILED" -eq 0 ]; then
    echo "🟢 Server Healthy"
elif [ "$FAILED" -le 2 ]; then
    echo "🟡 Warning"
else
    echo "🔴 Critical"
fi

echo ""
echo "Health Check Completed."
echo ""
