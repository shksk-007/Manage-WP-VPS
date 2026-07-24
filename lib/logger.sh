#!/bin/bash

LOG_FILE="/opt/wp-host/logs/wp-host.log"

mkdir -p /opt/wp-host/logs

log() {

    echo "[$(date '+%F %T')] $1"

    echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"

}
