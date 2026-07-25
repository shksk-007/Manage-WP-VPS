#!/bin/bash

# wp-host backups-list domain.com

DOMAIN="$1"
BACKUP_DIR="/opt/wp-host/backups/$DOMAIN"

if [ -z "$DOMAIN" ]; then
    echo "Error: Missing domain."
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    # Return empty list
    exit 0
fi

# List directories sorted by modification time (newest first)
ls -1t "$BACKUP_DIR"
