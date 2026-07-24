#!/bin/bash

source /opt/wp-host/config/settings.conf

LOG_FILE="/opt/wp-host/logs/rollback.log"

mkdir -p /opt/wp-host/logs

log(){
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "  wp-host rollback domain.com"
    echo ""
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

BACKUP_PATH="$BACKUP_DIR/$DOMAIN"

if [ ! -d "$BACKUP_PATH" ]; then
    echo "No backups found."
    exit 1
fi
echo ""
echo "========================================="
echo " Available Backups"
echo "========================================="
echo ""

BACKUPS=()

COUNT=1

for DIR in $(find "$BACKUP_PATH" -mindepth 1 -maxdepth 1 -type d | sort -r)
do
    NAME=$(basename "$DIR")

    BACKUPS+=("$NAME")

    echo "[$COUNT] $NAME"

    COUNT=$((COUNT+1))
done

echo ""

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "No backups available."
    exit 1
fi

read -p "Select backup number: " CHOICE

BACKUP="${BACKUPS[$((CHOICE-1))]}"

if [ -z "$BACKUP" ]; then
    echo "Invalid selection."
    exit 1
fi

echo ""
echo "Selected:"
echo "$BACKUP"
echo ""

echo "WARNING:"
echo "This will replace the current live website files and database."
echo ""
read -p "Continue rollback? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Rollback cancelled."
    exit 0
fi

echo ""
echo "Starting rollback..."
log "Rollback started: $DOMAIN backup=$BACKUP"
echo ""
echo "Creating emergency backup..."

mkdir -p /opt/wp-host/quarantine/$DOMAIN

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p /opt/wp-host/quarantine/$DOMAIN/$TIMESTAMP

tar -czf \
/opt/wp-host/quarantine/$DOMAIN/$TIMESTAMP/files.tar.gz \
-C /home/$USER public_html

mysqldump ${USER}_db \
| gzip \
> /opt/wp-host/quarantine/$DOMAIN/$TIMESTAMP/database.sql.gz

echo "Emergency backup completed."

echo ""
echo "Enabling maintenance mode..."

sudo -u "$USER" wp maintenance-mode activate \
--path=/home/$USER/public_html \
2>/dev/null || true

echo ""
echo "Removing website files..."

rm -rf /home/$USER/public_html

mkdir -p /home/$USER/public_html

chown -R $USER:$USER /home/$USER/public_html

echo ""
echo "Restoring website files..."

tar -xzf \
"$BACKUP_DIR/$DOMAIN/$BACKUP/files.tar.gz" \
-C /home/$USER

chown -R $USER:$USER /home/$USER/public_html

find /home/$USER/public_html -type d -exec chmod 755 {} \;
find /home/$USER/public_html -type f -exec chmod 644 {} \;

echo "Files restored."

echo ""
echo "Restoring database..."

gunzip -c \
"$BACKUP_DIR/$DOMAIN/$BACKUP/database.sql.gz" \
| mariadb ${USER}_db

echo "Database restored."

echo ""
echo "Clearing caches..."

sudo -u "$USER" wp cache flush \
--path=/home/$USER/public_html \
--allow-root 2>/dev/null || true

systemctl reload php8.5-fpm
systemctl reload nginx

echo ""
echo "Disabling maintenance mode..."

sudo -u "$USER" wp maintenance-mode deactivate \
--path=/home/$USER/public_html \
--allow-root 2>/dev/null || true

echo ""
echo "========================================="
echo " Rollback Completed Successfully"
log "Rollback completed successfully: $DOMAIN"
echo "========================================="
echo ""
echo "Domain : $DOMAIN"
echo "Backup : $BACKUP"
echo ""


echo ""
echo "Verifying website..."

HTTP=$(curl -L -o /dev/null -s \
    --connect-timeout 10 \
    -w "%{http_code}" \
    "https://$DOMAIN")

if [ "$HTTP" = "000" ]; then
    HTTP=$(curl -L -o /dev/null -s \
        --connect-timeout 10 \
        -w "%{http_code}" \
        "http://$DOMAIN")
fi

case "$HTTP" in
    200|301|302)
        echo "✅ Website is ONLINE (HTTP $HTTP)"
log "Rollback verification failed: $DOMAIN HTTP=$HTTP"
        ;;
    *)
        echo "❌ Website is OFFLINE (HTTP $HTTP)"
log "Rollback verification failed: $DOMAIN HTTP=$HTTP"
        ;;
esac

echo ""
echo "========================================="
echo " Rollback Completed"
echo "========================================="
echo "Domain : $DOMAIN"
echo "Backup : $BACKUP"
echo "Status : HTTP $HTTP"
echo ""
