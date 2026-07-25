#!/bin/bash

VERSION="2.0"

COMMAND="$1"

case "$COMMAND" in

create)
    /opt/wp-host/scripts/create-v1.sh "$2"
    ;;

delete)
    /opt/wp-host/scripts/delete.sh "$2"
    ;;

backup)
    /opt/wp-host/scripts/backup.sh "$2"
    ;;

restore)
    /opt/wp-host/scripts/restore.sh "$2"
    ;;

recover)
    /opt/wp-host/scripts/recover.sh "$2"
    ;;

update)
    /opt/wp-host/scripts/update.sh "$2"
    ;;

monitor)
    /opt/wp-host/scripts/monitor.sh
    ;;

list)
    /opt/wp-host/scripts/list.sh
    ;;

info)
    /opt/wp-host/scripts/info.sh "$2"
    ;;

status)
    /opt/wp-host/scripts/status.sh
    ;;

doctor)
    /opt/wp-host/scripts/doctor.sh
    ;;

version)
    echo "WP Host Manager v$VERSION"
    ;;

help|"")
    echo ""
    echo "========================================="
    echo " WP Host Manager v$VERSION"
    echo "========================================="
    echo ""
    echo "Commands:"
    echo ""
    echo "  wp-host create domain.com"
    echo "  wp-host delete domain.com"
    echo "  wp-host backup domain.com"
    echo "  wp-host restore domain.com"
    echo "  wp-host recover domain.com"
    echo "  wp-host recover --all"
    echo "  wp-host update domain.com"
    echo "  wp-host update --all"
    echo "  wp-host monitor"
    echo "  wp-host list"
    echo "  wp-host info domain.com"
    echo "  wp-host status"
    echo "  wp-host doctor"
    echo "  wp-host version"
    echo ""
    ;;

*)
    echo "Unknown command: $COMMAND"
    echo "Run: wp-host help"
    exit 1
    ;;

esac
