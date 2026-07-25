#!/bin/bash

DOMAIN="$2"

case "$1" in

list)

echo ""
echo "Current Cron Jobs"
echo "=============================="

crontab -l

;;

add)

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

(crontab -l 2>/dev/null

echo "*/5 * * * * php /home/$USER/public_html/wp-cron.php >/dev/null 2>&1"

) | crontab -

echo "Cron Added."

;;

remove)

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

crontab -l | grep -v "/home/$USER/public_html/wp-cron.php" | crontab -

echo "Cron Removed."

;;

*)

echo ""

echo "Usage:"

echo "wp-host cron list"

echo "wp-host cron add domain.com"

echo "wp-host cron remove domain.com"

;;

esac
