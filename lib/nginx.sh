#!/bin/bash

source /opt/wp-host/lib/logger.sh
source /opt/wp-host/config/settings.conf

create_nginx() {

    log "Creating Nginx configuration..."

    sed \
    -e "s/{{DOMAIN}}/$DOMAIN/g" \
    -e "s/{{USER}}/$USER/g" \
    /opt/wp-host/templates/nginx.conf.tpl \
    > "$NGINX_AVAILABLE/$DOMAIN.conf"

    ln -sf \
        "$NGINX_AVAILABLE/$DOMAIN.conf" \
        "$NGINX_ENABLED/$DOMAIN.conf"

    nginx -t

    systemctl reload nginx

    log "Nginx configured."

}
