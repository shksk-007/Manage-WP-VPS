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

# Ensure wp-cli login command is installed for this user
# It needs to be installed via WP-CLI package manager
# We run it as the site user
if ! sudo -u "$USER" wp package list --fields=name 2>/dev/null | grep -q "wp-cli-login-command"; then
    echo "Installing wp-cli login command for user $USER..." >&2
    sudo -u "$USER" wp package install aaemnnosttv/wp-cli-login-command --path="$SITE_DIR" >&2
fi

# Get the first admin user
ADMIN_USER=$(sudo -u "$USER" wp user list --role=administrator --field=user_login --path="$SITE_DIR" | head -n 1)

if [ -z "$ADMIN_USER" ]; then
    echo "Error: No administrator found."
    exit 1
fi

# Generate magic login link
LOGIN_URL=$(sudo -u "$USER" wp login create "$ADMIN_USER" --url-only --path="$SITE_DIR")

echo "$LOGIN_URL"
