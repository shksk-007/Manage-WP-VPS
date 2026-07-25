#!/bin/bash

SITE_LIST="/opt/wp-host/sites.list"

echo ""
echo "========================================="
echo " Installed WordPress Sites"
echo "========================================="
echo ""

if [ ! -f "$SITE_LIST" ]; then
    echo "No sites registered."
    exit 0
fi

COUNT=1

while IFS= read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue

    printf "%2d. %s\n" "$COUNT" "$DOMAIN"

    COUNT=$((COUNT+1))

done < "$SITE_LIST"

echo ""
echo "Total Sites: $((COUNT-1))"
echo ""
