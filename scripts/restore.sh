#!/bin/bash

set -e

DOMAIN=""
TARGET_BACKUP=""
FORCE=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --backup=*) TARGET_BACKUP="${1#*=}"; shift ;;
        --force) FORCE=1; shift ;;
        *) DOMAIN="$1"; shift ;;
    esac
done

BACKUP_ROOT="/opt/wp-host/backups/$DOMAIN"
BACKUP_SCRIPT="/opt/wp-host/scripts/backup.sh"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "wp-host restore domain.com"
    echo "wp-host restore domain.com --backup=XXXX --force"
    echo ""
    exit 1
fi

if [ ! -d "$BACKUP_ROOT" ]; then
    echo ""
    echo "No backups found for $DOMAIN"
    echo ""
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

DB="${USER}_db"

SITE="/home/$USER/public_html"

echo ""
echo "========================================="
echo " WP Host Manager"
echo " Restore Wizard"
echo "========================================="
echo ""

echo "Domain : $DOMAIN"

echo ""

if [ -n "$TARGET_BACKUP" ]; then
    BACKUP="$TARGET_BACKUP"
else
    echo ""
    echo "Available Backups"
    echo ""

    BACKUPS=()
    i=1

    for DIR in $(ls -1tr "$BACKUP_ROOT")
    do
        BACKUPS+=("$DIR")
        echo "$i) $DIR"
        i=$((i+1))
    done

    echo ""
    read -p "Choose backup: " CHOICE
    INDEX=$((CHOICE-1))
    BACKUP="${BACKUPS[$INDEX]}"

    if [ -z "$BACKUP" ]; then
        echo ""
        echo "Invalid selection."
        exit 1
    fi
fi

BACKUP_PATH="$BACKUP_ROOT/$BACKUP"

echo ""

echo "Selected Backup"

echo "$BACKUP"

echo ""

echo "Verifying backup..."

[ -f "$BACKUP_PATH/database.sql.gz" ] || {

echo "Database backup missing."

exit 1

}

[ -f "$BACKUP_PATH/files.tar.gz" ] || {

echo "Files backup missing."

exit 1

}

echo "Backup verified."

echo ""

if [ $FORCE -eq 0 ]; then
    read -p "Restore this backup? (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
fi

echo ""

echo "Reload PHP-FPM..."

systemctl reload php8.5-fpm

echo "Removing current files..."

rm -rf "$SITE"

mkdir -p "$SITE"

echo "Extracting files..."

tar -xzf \
"$BACKUP_PATH/files.tar.gz" \
-C /home/$USER

echo ""

echo "Restoring database..."

# Ensure database exists (in case the site was completely deleted before restore)
mariadb -e "CREATE DATABASE IF NOT EXISTS \`${DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

gunzip -c \
"$BACKUP_PATH/database.sql.gz" \
| mariadb "$DB"

echo ""

echo "Database restored."

echo ""

echo "Restoring wp-config.php (if present)..."

if [ -f "$BACKUP_PATH/wp-config.php" ]; then

cp \
"$BACKUP_PATH/wp-config.php" \
"$SITE/wp-config.php"

fi

echo "Fixing ownership..."

chown -R "$USER:$USER" "/home/$USER"

echo "Fixing directory permissions..."

find "$SITE" \
-type d \
-exec chmod 755 {} \;

echo "Fixing file permissions..."

find "$SITE" \
-type f \
-exec chmod 644 {} \;

echo ""

echo "Resetting database and admin credentials..."

DBUSER="${USER}_usr"
NEW_DBPASS=$(openssl rand -hex 12)

# Update database user password robustly using CREATE OR REPLACE USER
mariadb -e "CREATE OR REPLACE USER '$DBUSER'@'127.0.0.1' IDENTIFIED BY '$NEW_DBPASS';"
mariadb -e "CREATE OR REPLACE USER '$DBUSER'@'localhost' IDENTIFIED BY '$NEW_DBPASS';"
mariadb -e "GRANT ALL PRIVILEGES ON \`${DB}\`.* TO '$DBUSER'@'127.0.0.1';"
mariadb -e "GRANT ALL PRIVILEGES ON \`${DB}\`.* TO '$DBUSER'@'localhost';"
mariadb -e "FLUSH PRIVILEGES;"

if [ -f "$SITE/wp-config.php" ]; then
    sudo -u "$USER" wp config set DB_PASSWORD "$NEW_DBPASS" --path="$SITE" || \
    sed -i "s/define( *'DB_PASSWORD'.*/define( 'DB_PASSWORD', '$NEW_DBPASS' );/" "$SITE/wp-config.php"
fi

ADMIN_USER=$(sudo -u "$USER" wp user list --role=administrator --field=user_login --path="$SITE" | head -n 1)
NEW_ADMINPASS=""
if [ -n "$ADMIN_USER" ]; then
    NEW_ADMINPASS=$(openssl rand -hex 12)
    sudo -u "$USER" wp user update "$ADMIN_USER" --user_pass="$NEW_ADMINPASS" --path="$SITE" >/dev/null
fi

echo "Credentials reset."

echo ""

echo "Starting PHP-FPM..."

systemctl start php8.5-fpm

echo "Reloading Nginx..."

systemctl reload nginx

echo ""

if systemctl is-active --quiet redis-server; then

    echo "Clearing Redis..."

    redis-cli FLUSHALL >/dev/null 2>&1 || true

fi

echo ""

echo "Testing website..."

HTTP_CODE=$(curl -k -L -o /dev/null -s -w "%{http_code}" "https://$DOMAIN")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then

    echo "✓ Website is responding (HTTP $HTTP_CODE)"

else

    echo ""
    echo "WARNING: Website returned HTTP $HTTP_CODE"
    echo "Please check the site manually."
fi

echo ""

echo "========================================="
echo " Restore Completed Successfully"
echo "========================================="
echo ""
echo "Domain      : $DOMAIN"
echo "Backup      : $BACKUP"
echo "Database    : Restored"
echo "Files       : Restored"

if [ -f "$SITE/wp-config.php" ]; then
    echo "wp-config   : Restored"
else
    echo "wp-config   : Existing"
fi

echo "Permissions : Fixed"
echo "PHP-FPM     : Running"
echo "Nginx       : Reloaded"
echo "========================================="
echo " NEW SECURITY CREDENTIALS"
echo "========================================="
echo "Database User: $DBUSER"
echo "Database Pass: $NEW_DBPASS"
if [ -n "$NEW_ADMINPASS" ]; then
    echo "WP Admin User: $ADMIN_USER"
    echo "WP Admin Pass: $NEW_ADMINPASS"
fi
echo ""

exit 0
