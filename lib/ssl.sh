#!/bin/bash

source /opt/wp-host/lib/logger.sh

install_ssl() {

    log "Obtaining SSL..."

    certbot --nginx \
        --non-interactive \
        --agree-tos \
        -m "$ADMIN_EMAIL" \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"

    sudo -u "$USER" wp option update home \
        "https://$DOMAIN" \
        --path=/home/$USER/public_html

    sudo -u "$USER" wp option update siteurl \
        "https://$DOMAIN" \
        --path=/home/$USER/public_html

    log "SSL installed."

}
