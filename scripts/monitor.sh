#!/bin/bash

printf "\n%-35s %-8s %-10s %-10s\n" "DOMAIN" "STATUS" "SSL" "BACKUP"
printf "%-35s %-8s %-10s %-10s\n" "-----------------------------------" "------" "--------" "----------"

while read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue

    USER=$(echo "$DOMAIN" | cut -d'.' -f1)

    HTTP=$(curl -k -L -o /dev/null -s -w "%{http_code}" "https://$DOMAIN")

    if [ "$HTTP" = "200" ] || [ "$HTTP" = "301" ] || [ "$HTTP" = "302" ]; then
        STATUS="ONLINE"
    else
        STATUS="OFFLINE"
    fi

    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        SSL=$(openssl x509 -enddate -noout \
        -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
        | cut -d= -f2)
    else
        SSL="Missing"
    fi

    LAST=$(find /opt/wp-host/backups/$DOMAIN \
    -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort | tail -1 | xargs basename 2>/dev/null)

    [ -z "$LAST" ] && LAST="None"

    printf "%-35s %-8s %-10s %-10s\n" "$DOMAIN" "$STATUS" "$SSL" "$LAST"

done < /opt/wp-host/sites.list

echo ""
