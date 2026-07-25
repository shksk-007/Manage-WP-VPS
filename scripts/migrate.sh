#!/bin/bash

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Usage:"
    echo "wp-host migrate domain.com"
    echo ""
    exit 1
fi

echo ""
echo "========================================="
echo " WP Host Manager"
echo " Site Migration"
echo "========================================="
echo ""

read -p "Source Server IP: " SOURCE_IP
read -p "SSH Port [22]: " SSH_PORT

SSH_PORT=${SSH_PORT:-22}

read -p "SSH Username: " SSH_USER
read -p "WordPress Path: " SOURCE_PATH

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

DB="${USER}_db"
DBUSER="${USER}_user"

echo ""
echo "Migration Summary"
echo "-------------------------"
echo "Domain      : $DOMAIN"
echo "Source IP   : $SOURCE_IP"
echo "SSH User    : $SSH_USER"
echo "WP Path     : $SOURCE_PATH"
echo ""

read -p "Continue? (y/N): " CONFIRM

[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit

echo ""
echo "Creating destination site..."

wp-host create "$DOMAIN"

if [ $? -ne 0 ]; then
    echo "Migration aborted."
    exit 1
fi

echo ""
echo "Destination site created."

echo ""
echo "Copying WordPress files..."

rsync -az -e "ssh -p $SSH_PORT" \
"$SSH_USER@$SOURCE_IP:$SOURCE_PATH/" \
"/home/$USER/public_html/"

chown -R "$USER:$USER" "/home/$USER/public_html"

echo "Files copied."


echo ""
echo "Exporting database from source..."

ssh -p "$SSH_PORT" "$SSH_USER@$SOURCE_IP" \
"wp db export - --path=$SOURCE_PATH --allow-root" \
> /tmp/${DOMAIN}.sql

echo "Importing database..."

wp db import /tmp/${DOMAIN}.sql \
--path=/home/$USER/public_html \
--allow-root

rm -f /tmp/${DOMAIN}.sql

echo "Database imported."


echo ""
echo "Updating wp-config.php..."

REMOTE_DB=$(ssh -p "$SSH_PORT" "$SSH_USER@$SOURCE_IP" \
"wp config get DB_NAME --path=$SOURCE_PATH --allow-root")

REMOTE_USER=$(ssh -p "$SSH_PORT" "$SSH_USER@$SOURCE_IP" \
"wp config get DB_USER --path=$SOURCE_PATH --allow-root")

REMOTE_PASS=$(ssh -p "$SSH_PORT" "$SSH_USER@$SOURCE_IP" \
"wp config get DB_PASSWORD --path=$SOURCE_PATH --allow-root")

wp config set DB_NAME "$DB" \
--path=/home/$USER/public_html \
--allow-root

wp config set DB_USER "$DBUSER" \
--path=/home/$USER/public_html \
--allow-root

wp config set DB_PASSWORD "$(openssl rand -base64 24)" \
--path=/home/$USER/public_html \
--allow-root

echo "Updating WordPress URLs..."

wp option update home "https://$DOMAIN" \
--path=/home/$USER/public_html \
--allow-root

wp option update siteurl "https://$DOMAIN" \
--path=/home/$USER/public_html \
--allow-root

echo "Configuration updated."

echo ""
echo "Installing SSL..."

certbot --nginx \
-d "$DOMAIN" \
-d "www.$DOMAIN" \
--non-interactive \
--agree-tos \
--redirect \
-m admin@"$DOMAIN" || true

echo ""
echo "Creating first backup..."

wp-host backup "$DOMAIN"

echo ""
echo "Migration completed successfully."

echo ""
echo "========================================="
echo " Migration Complete"
echo "========================================="
echo "Domain : https://$DOMAIN"
echo ""
