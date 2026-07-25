#!/bin/bash

SITE_LIST="/opt/wp-host/sites.list"
LOG_FILE="/opt/wp-host/logs/security-scan.log"

mkdir -p /opt/wp-host/logs

log(){
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}


scan_site(){

DOMAIN="$1"
USER=$(echo "$DOMAIN" | cut -d'.' -f1)

SITE_PATH="/home/$USER/public_html"


log "================================="
log "Scanning: $DOMAIN"


if [ ! -d "$SITE_PATH" ]; then
    log "ERROR: Missing path $SITE_PATH"
    return
fi


log "Running Maldet..."

maldet -a "$SITE_PATH" >> "$LOG_FILE" 2>&1


log "Running ClamAV..."

clamscan \
-r "$SITE_PATH" \
--infected \
--log="$LOG_FILE"


log "Scan finished: $DOMAIN"

}


if [ "$1" = "--all" ]; then

    while IFS= read -r DOMAIN
    do
        [ -z "$DOMAIN" ] && continue
        scan_site "$DOMAIN"
    done < "$SITE_LIST"

else

    scan_site "$1"

fi
