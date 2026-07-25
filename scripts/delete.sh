#!/bin/bash

DOMAIN="$1"
FORCE=0

if [ "$2" == "--force" ]; then
    FORCE=1
fi

SITE_LIST="/opt/wp-host/sites.list"
BACKUP_SCRIPT="/opt/wp-host/scripts/backup.sh"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "  wp-host delete domain.com [--force]"
    echo ""
    exit 1
fi

if [ "$FORCE" -eq 0 ]; then
    if [ ! -f "$SITE_LIST" ]; then
        echo "ERROR: Site registry not found."
        exit 1
    fi

    if ! grep -qxF "$DOMAIN" "$SITE_LIST"; then
        echo ""
        echo "ERROR: '$DOMAIN' is not managed by WP Host."
        echo "Use 'wp-host delete $DOMAIN --force' to force deletion anyway."
        echo ""
        exit 1
    fi
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)
DB="${USER}_db"
DBUSER="${USER}_user"

echo ""
echo "========================================="
echo " WP Host Manager"
echo " Delete WordPress Site"
echo "========================================="
echo ""
echo "Domain      : $DOMAIN"
echo "Linux User  : $USER"
echo "Database    : $DB"
echo ""
echo "This will permanently remove:"
echo ""
echo " ✓ Linux User"
echo " ✓ WordPress Files"
echo " ✓ MariaDB Database"
echo " ✓ Database User"
echo " ✓ PHP-FPM Pool"
echo " ✓ Nginx Configuration"
echo " ✓ SSL Certificate"
echo " ✓ All Backups"
echo " ✓ Site Registry"
echo ""

read -p "Continue? (y/N): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo ""
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Creating final backup..."

if [ -x "$BACKUP_SCRIPT" ]; then
    "$BACKUP_SCRIPT" "$DOMAIN"
fi

echo ""
echo "Removing PHP-FPM Pool..."
rm -f /etc/php/8.5/fpm/pool.d/$USER.conf

echo "Checking PHP-FPM pools..."

POOL_COUNT=$(ls /etc/php/8.5/fpm/pool.d/*.conf 2>/dev/null | wc -l)

if [ "$POOL_COUNT" -eq 0 ]; then

    echo "No PHP pools found. Restoring default pool..."

    if [ -f /etc/php/8.5/fpm/pool.d/www.conf.disabled ]; then
        cp /etc/php/8.5/fpm/pool.d/www.conf.disabled \
        /etc/php/8.5/fpm/pool.d/www.conf
    fi

fi

systemctl restart php8.5-fpm
echo "Removing Nginx..."
rm -f /etc/nginx/sites-enabled/$DOMAIN.conf
rm -f /etc/nginx/sites-available/$DOMAIN.conf

nginx -t >/dev/null 2>&1

if [ $? -eq 0 ]; then
    systemctl reload nginx
fi

echo "Removing SSL Certificate..."
certbot delete \
    --cert-name "$DOMAIN" \
    --non-interactive \
    >/dev/null 2>&1 || true

echo "Removing Database..."

mariadb <<EOF
DROP DATABASE IF EXISTS \`$DB\`;
DROP USER IF EXISTS '$DBUSER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Removing Linux User..."

userdel -f -r "$USER" 2>/dev/null || true

echo "Removing Backups..."

rm -rf "/opt/wp-host/backups/$DOMAIN"

echo "Removing Site Registry..."

sed -i "\|^$DOMAIN$|d" "$SITE_LIST"

echo ""
echo "========================================="
echo " Site Deleted Successfully"
echo "========================================="
echo ""
echo "Domain: $DOMAIN"
echo ""
