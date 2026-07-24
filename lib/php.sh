#!/bin/bash

source /opt/wp-host/lib/logger.sh
source /opt/wp-host/config/settings.conf

create_php_pool() {

    log "Creating PHP-FPM pool..."

    sed \
        "s/{{USER}}/$USER/g" \
        /opt/wp-host/templates/php-pool.conf.tpl \
        > "$PHP_POOL_DIR/$USER.conf"

    systemctl reload php8.5-fpm

    log "PHP-FPM pool created."

}
