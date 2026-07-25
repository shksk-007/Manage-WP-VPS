#!/bin/bash

LOG_FILE="/opt/wp-host/logs/activity.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "No activity logs found."
    exit 0
fi

echo "========================================="
echo " WP Host Manager - Activity Logs"
echo "========================================="
echo ""
tail -n 100 "$LOG_FILE"
