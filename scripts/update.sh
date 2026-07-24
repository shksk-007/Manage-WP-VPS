#!/bin/bash

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "wp-host update domain.com"
    echo "wp-host update --all"
    echo ""
    exit 1
fi

update_site() {

    DOMAIN="$1"
    USER=$(echo "$DOMAIN" | cut -d'.' -f1)
    SITE="/home/$USER/public_html"

    echo ""
    echo "========================================="
    echo "Updating $DOMAIN"
    echo "========================================="

    if [ ! -d "$SITE" ]; then
        echo "Site not found."
        return
    fi

    sudo -u "$USER" wp core update --path="$SITE"
    sudo -u "$USER" wp core update-db --path="$SITE"
    sudo -u "$USER" wp plugin update --all --path="$SITE"
    sudo -u "$USER" wp theme update --all --path="$SITE"

    if systemctl is-active --quiet redis-server; then
        sudo -u "$USER" wp cache flush --path="$SITE" 2>/dev/null || true
    fi

    echo "✓ Update completed."
}

if [ "$DOMAIN" = "--all" ]; then

    while read -r SITE
    do
        [ -z "$SITE" ] && continue
        update_site "$SITE"
    done < /opt/wp-host/sites.list

else

    update_site "$DOMAIN"

fi
