#!/bin/bash

# Get CPU usage
CPU=$(top -bn1 | awk -F',' '/Cpu/ {print 100-$4}')

# Get Memory usage in MB
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

if [ -z "$CPU" ]; then
    CPU="0"
fi

echo "{\"cpu\": \"$CPU\", \"mem_total\": \"$MEM_TOTAL\", \"mem_used\": \"$MEM_USED\"}"
