#!/bin/bash

source /opt/wp-host/lib/logger.sh
source /opt/wp-host/lib/helpers.sh

create_database() {

    log "Creating MariaDB database..."

    mariadb <<EOF

CREATE DATABASE IF NOT EXISTS \`${DB}\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DBUSER}'@'localhost'
IDENTIFIED BY '${DBPASS}';

GRANT ALL PRIVILEGES
ON \`${DB}\`.*
TO '${DBUSER}'@'localhost';

FLUSH PRIVILEGES;

EOF

    log "Database created."

}
