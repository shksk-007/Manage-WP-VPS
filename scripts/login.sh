#!/bin/bash

# wp-host login domain.com

set -e

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo "Error: Missing domain."
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)
SITE_DIR="/home/$USER/public_html"

if [ ! -d "$SITE_DIR" ]; then
    echo "Error: Site directory not found."
    exit 1
fi

# Get the first admin user
ADMIN_USER=$(sudo -u "$USER" wp user list --role=administrator --field=user_login --path="$SITE_DIR" | head -n 1)

if [ -z "$ADMIN_USER" ]; then
    echo "Error: No administrator found."
    exit 1
fi

# Clean up any orphaned login scripts from previous unused attempts
sudo -u "$USER" rm -f "$SITE_DIR"/login_*.php

# Generate a secure random token for the filename
TOKEN=$(head -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24)
TEMP_FILE="$SITE_DIR/login_${TOKEN}.php"

# Create a self-destructing PHP login script
cat << 'EOF' | sudo -u "$USER" tee "$TEMP_FILE" >/dev/null
<?php
require 'wp-load.php';
$admin_username = 'YOUR_ADMIN_USER';
$user = get_user_by('login', $admin_username);

if ($user) {
    wp_set_current_user($user->ID, $user->user_login);
    wp_set_auth_cookie($user->ID);
    do_action('wp_login', $user->user_login, $user);
}

// Self-destruct for security
unlink(__FILE__);

// Redirect to dashboard
wp_redirect(admin_url());
exit;
EOF

# Inject the actual username into the script
sudo -u "$USER" sed -i "s/YOUR_ADMIN_USER/$ADMIN_USER/" "$TEMP_FILE"

# Output the magic link
echo "https://$DOMAIN/login_${TOKEN}.php"
