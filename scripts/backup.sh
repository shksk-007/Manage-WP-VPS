#!/bin/bash

set -e

BACKUP_DIR="/opt/wp-host/backups"
LOG_FILE="/opt/wp-host/logs/backup.log"

mkdir -p "$BACKUP_DIR"
mkdir -p /opt/wp-host/logs

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

backup_site() {

    DOMAIN="$1"
    MODE="${2:-manual}"
    USER=$(echo "$DOMAIN" | cut -d'.' -f1)

    if [ "$MODE" = "cron" ]; then
        DATE=$(date +%d_%m_%Y)
    elif [ "$MODE" = "manual" ]; then
        DATE=$(date +%d_%m_%Y_Manual)
    else
        DATE="$MODE"
    fi

    SITE_DIR="$BACKUP_DIR/$DOMAIN/$DATE"

    mkdir -p "$SITE_DIR"

    log "======================================="
    log "Backing up $DOMAIN"

    log "Creating database dump..."

    mysqldump "${USER}_db" | gzip > "$SITE_DIR/database.sql.gz"

    log "Backing up files..."

tar -czf "$SITE_DIR/files.tar.gz" \
        -C /home/$USER public_html
    log "Copying credentials..."

    if [ -f "/root/wp-host/sites/$DOMAIN.txt" ]; then
        cp "/root/wp-host/sites/$DOMAIN.txt" "$SITE_DIR/"
    fi

    log "Verifying backup..."

    gzip -t "$SITE_DIR/database.sql.gz"
    tar -tf "$SITE_DIR/files.tar.gz" >/dev/null

    log "Backup verification successful."

    log "Applying retention policy..."

    COUNT=$(find "$BACKUP_DIR/$DOMAIN" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d | wc -l)

    if [ "$COUNT" -gt 15 ]; then

        REMOVE=$((COUNT-15))

        find "$BACKUP_DIR/$DOMAIN" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf "%T@ %p\n" \
            | sort -n \
            | cut -d' ' -f2- \
            | head -n "$REMOVE" \
            | xargs -r rm -rf

        log "Removed $REMOVE old backup(s)."

    fi

    log "Backup completed for $DOMAIN"
    log "======================================="
    echo
}

if [ "$1" = "--all" ]; then

    while IFS= read -r DOMAIN
    do
        [ -z "$DOMAIN" ] && continue
        backup_site "$DOMAIN" "cron"
    done < /opt/wp-host/sites.list

    exit 0

fi
if [ -n "$1" ]; then

    backup_site "$1" "manual"

    exit 0

fi
