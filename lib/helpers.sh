#!/bin/bash

source /opt/wp-host/config/settings.conf

get_user() {

    echo "$1" | cut -d'.' -f1

}

get_db() {

    echo "$(get_user "$1")_db"

}

get_db_user() {

    echo "$(get_user "$1")_user"

}
