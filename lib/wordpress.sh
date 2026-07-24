#!/bin/bash

source /opt/wp-host/lib/logger.sh

install_wordpress() {

    log "Downloading WordPress..."

    sudo -u "$USER" wp core download \
        --path=/home/$USER/public_html

    log "Creating wp-config..."

    sudo -u "$USER" wp config create \
        --dbname="$DB" \
        --dbuser="$DBUSER" \
        --dbpass="$DBPASS" \
        --dbhost=localhost \
        --dbcharset=utf8mb4 \
        --path=/home/$USER/public_html \
        --skip-check

    log "Installing WordPress..."

    sudo -u "$USER" wp core install \
        --url="http://$DOMAIN" \
        --title="$DOMAIN" \
        --admin_user="$ADMIN_USER" \
        --admin_password="$ADMIN_PASSWORD" \
        --admin_email="$ADMIN_EMAIL" \
        --path=/home/$USER/public_html

    log "WordPress installed."

}
