#!/bin/bash

echo ""
echo "========================================="
echo " WP Host Manager"
echo " Server Status"
echo "========================================="
echo ""

CPU=$(top -bn1 | awk -F',' '/Cpu/ {print 100-$4"%"}')

MEM=$(free -h | awk '/Mem:/ {print $3 " / " $2}')

DISK=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')

printf "%-18s %s\n" "CPU Usage:" "$CPU"
printf "%-18s %s\n" "Memory Usage:" "$MEM"
printf "%-18s %s\n" "Disk Usage:" "$DISK"

echo ""

services=(
nginx
php8.5-fpm
mariadb
redis-server
fail2ban
)

for svc in "${services[@]}"
do

if systemctl is-active --quiet "$svc"
then
printf "%-18s %s\n" "$svc:" "Running"
else
printf "%-18s %s\n" "$svc:" "Stopped"
fi

done

echo ""

SITES=$(grep -vc '^$' /opt/wp-host/sites.list 2>/dev/null)

BACKUPS=$(find /opt/wp-host/backups \
-mindepth 2 \
-maxdepth 2 \
-type d | wc -l)

printf "%-18s %s\n" "Installed Sites:" "$SITES"

printf "%-18s %s\n" "Backups:" "$BACKUPS"

echo ""
