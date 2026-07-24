#!/bin/bash

echo "========================================="
echo " WP Host Manager - Server Optimizer"
echo "========================================="

# Get system specs
TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
CORES=$(nproc)

# Baseline defaults for small servers
DEFAULT_MEM="256M"
DEFAULT_UPLOAD="128M"
DEFAULT_TIME="120"
DEFAULT_VARS="3000"

# Scale intelligently based on total RAM
if [ "$TOTAL_MEM" -gt 8000 ]; then
    # Huge server (>8GB RAM)
    DEFAULT_MEM="1024M"
    DEFAULT_UPLOAD="512M"
    DEFAULT_TIME="300"
    DEFAULT_VARS="10000"
elif [ "$TOTAL_MEM" -gt 3000 ]; then
    # Medium server (>3GB RAM)
    DEFAULT_MEM="512M"
    DEFAULT_UPLOAD="256M"
    DEFAULT_TIME="180"
    DEFAULT_VARS="5000"
fi

echo "System Detected: $CORES Cores, ${TOTAL_MEM}MB RAM"
echo ""
echo "Optimal PHP Settings computed for this server:"
echo " - Memory Limit:        $DEFAULT_MEM"
echo " - Upload Max Filesize: $DEFAULT_UPLOAD"
echo " - Post Max Size:       $DEFAULT_UPLOAD"
echo " - Max Execution Time:  $DEFAULT_TIME"
echo " - Max Input Vars:      $DEFAULT_VARS"
echo ""

read -p "Apply these optimal defaults? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo ""
    echo "--- Custom Configuration ---"
    read -p "Enter Memory Limit [$DEFAULT_MEM]: " custom_mem
    DEFAULT_MEM=${custom_mem:-$DEFAULT_MEM}
    
    read -p "Enter Upload Max Filesize [$DEFAULT_UPLOAD]: " custom_up
    DEFAULT_UPLOAD=${custom_up:-$DEFAULT_UPLOAD}
    
    read -p "Enter Max Execution Time [$DEFAULT_TIME]: " custom_time
    DEFAULT_TIME=${custom_time:-$DEFAULT_TIME}
    
    read -p "Enter Max Input Vars [$DEFAULT_VARS]: " custom_vars
    DEFAULT_VARS=${custom_vars:-$DEFAULT_VARS}
    
    echo "Proceeding with custom values..."
    echo ""
fi

echo "Installing PHP Imagick Extension..."
apt-get update >/dev/null 2>&1
apt-get install -y php8.5-imagick >/dev/null 2>&1

PHP_INI="/etc/php/8.5/fpm/php.ini"

if [ -f "$PHP_INI" ]; then
    echo "Tuning PHP configuration ($PHP_INI)..."
    
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $DEFAULT_UPLOAD/" "$PHP_INI"
    sed -i "s/^post_max_size = .*/post_max_size = $DEFAULT_UPLOAD/" "$PHP_INI"
    sed -i "s/^memory_limit = .*/memory_limit = $DEFAULT_MEM/" "$PHP_INI"
    sed -i "s/^max_execution_time = .*/max_execution_time = $DEFAULT_TIME/" "$PHP_INI"
    sed -i "s/^max_input_vars = .*/max_input_vars = $DEFAULT_VARS/" "$PHP_INI"
    
    # Tune OPcache
    sed -i 's/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=32/' "$PHP_INI"
    sed -i 's/^opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=32/' "$PHP_INI"
    sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=256/' "$PHP_INI"
    sed -i 's/^opcache.memory_consumption=.*/opcache.memory_consumption=256/' "$PHP_INI"
    
    echo "Restarting PHP 8.5 FPM service..."
    systemctl restart php8.5-fpm
    echo "✅ Optimization complete! Your WordPress site is now configured for maximum performance."
else
    echo "❌ Error: PHP configuration file ($PHP_INI) not found. Are you running PHP 8.5?"
fi
