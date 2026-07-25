#!/bin/bash

set -e

DOMAIN=""
ADMIN_USER=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
FORCE=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain=*) DOMAIN="${1#*=}"; shift ;;
        --admin=*) ADMIN_USER="${1#*=}"; shift ;;
        --email=*) ADMIN_EMAIL="${1#*=}"; shift ;;
        --pass=*) ADMIN_PASSWORD="${1#*=}"; shift ;;
        --force) FORCE=1; shift ;;
        *) DOMAIN="$1"; shift ;; # Fallback for old positional arg
    esac
done

if [ -z "$DOMAIN" ]; then
    echo "Usage:"
    echo "wp-host create domain.com"
    echo "or"
    echo "wp-host create --domain=x --admin=x --email=x --pass=x --force"
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)
DB="${USER}_db"
DBUSER="${USER}_user"
DBPASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)

echo ""
echo "========================================="
echo " WordPress Host Manager"
echo "========================================="
echo ""
echo "Domain      : $DOMAIN"
echo "Linux User  : $USER"
echo "Database    : $DB"
echo "DB User     : $DBUSER"
echo ""

if [ $FORCE -eq 0 ]; then
    echo "Generated Database Password:"
    echo "$DBPASS"
    echo ""
    read -p "Continue? (y/N): " CONFIRM
    read -p "Admin Username: " ADMIN_USER
    read -p "Admin Email: " ADMIN_EMAIL
    read -s -p "Admin Password: " ADMIN_PASSWORD
    echo ""

    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled."
        exit
    fi
else
    echo "Running in non-interactive mode."
fi

echo ""
echo "Creating Linux user..."

if id "$USER" >/dev/null 2>&1; then
    echo "User already exists."
else
    adduser --disabled-password --gecos "" "$USER"
fi

echo ""
echo "Creating folders..."

mkdir -p /home/$USER/public_html
mkdir -p /home/$USER/logs
mkdir -p /home/$USER/backups
mkdir -p /home/$USER/tmp

chown -R $USER:$USER /home/$USER

chmod 755 /home/$USER
chmod 755 /home/$USER/public_html

echo ""
echo "Creating MariaDB database..."

mariadb <<EOF

CREATE DATABASE IF NOT EXISTS \`${DB}\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE OR REPLACE USER '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
CREATE OR REPLACE USER '${DBUSER}'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';

GRANT ALL PRIVILEGES ON \`${DB}\`.* TO '${DBUSER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB}\`.* TO '${DBUSER}'@'127.0.0.1';

FLUSH PRIVILEGES;

EOF

echo "Database created."
echo ""
echo "Creating PHP-FPM pool..."

sed "s/{{USER}}/$USER/g" \
/opt/wp-host/templates/php-pool.conf.tpl \
> /etc/php/8.5/fpm/pool.d/$USER.conf

systemctl reload php8.5-fpm

echo "PHP-FPM pool created."

echo ""
echo "Creating Nginx configuration..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

sed \
-e "s/{{DOMAIN}}/$DOMAIN/g" \
-e "s/{{USER}}/$USER/g" \
/opt/wp-host/templates/nginx.conf.tpl \
> /etc/nginx/sites-available/$DOMAIN.conf

ln -sf \
/etc/nginx/sites-available/$DOMAIN.conf \
/etc/nginx/sites-enabled/$DOMAIN.conf

nginx -t

systemctl reload nginx

echo "Nginx configured."
echo ""
echo "Downloading WordPress..."

# Ensure loopback requests (wp-cron, rest-api) do not timeout due to lack of hairpin NAT
if ! grep -q "$DOMAIN" /etc/hosts; then
    echo "127.0.0.1 $DOMAIN" >> /etc/hosts
fi

sudo -u "$USER" wp core download \
--path=/home/$USER/public_html \
--force

echo "WordPress downloaded."

echo ""
echo "Creating wp-config.php..."

sudo -u "$USER" wp config create \
--dbname="$DB" \
--dbuser="$DBUSER" \
--dbpass="$DBPASS" \
--dbhost="127.0.0.1" \
--dbcharset="utf8mb4" \
--path=/home/$USER/public_html \
--skip-check \
--force

echo "wp-config.php created."

echo ""
echo "Installing WordPress..."

sudo -u "$USER" wp core install \
--url="http://$DOMAIN" \
--title="$DOMAIN" \
--admin_user="$ADMIN_USER" \
--admin_password="$ADMIN_PASSWORD" \
--admin_email="$ADMIN_EMAIL" \
--path=/home/$USER/public_html

echo "WordPress installed."

echo ""
echo "Enabling Redis Object Cache..."

sudo -u "$USER" wp plugin install redis-cache --activate --path=/home/$USER/public_html
sudo -u "$USER" wp redis enable --path=/home/$USER/public_html

echo "Redis Object Cache enabled."

echo ""
echo "Checking DNS..."

DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
SERVER_IP=$(curl -4 -s https://ifconfig.me)

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo ""
    echo "Domain DNS does not point to this server."
    echo "Skipping SSL."
    exit 0
fi

echo ""
echo "Obtaining SSL certificate..."

certbot --nginx \
--non-interactive \
--agree-tos \
-m "$ADMIN_EMAIL" \
-d "$DOMAIN" \
-d "www.$DOMAIN"

# Enable HTTP/2 for the domain
# Certbot usually adds 'listen 443 ssl;' which we can append to.
if nginx -V 2>&1 | grep -q "nginx/1.25\|nginx/1.26\|nginx/1.27"; then
    sed -i '/listen 443 ssl;/a \    http2 on;' /etc/nginx/sites-available/$DOMAIN.conf
else
    sed -i 's/listen 443 ssl;/listen 443 ssl http2;/g' /etc/nginx/sites-available/$DOMAIN.conf
fi
systemctl reload nginx

echo "SSL and HTTP/2 installed."

echo ""
echo "Updating WordPress URLs..."

sudo -u "$USER" wp option update home \
"https://$DOMAIN" \
--path=/home/$USER/public_html

sudo -u "$USER" wp option update siteurl \
"https://$DOMAIN" \
--path=/home/$USER/public_html

echo "HTTPS enabled."

cat > /home/$USER/site-info.txt <<EOF
========================================
WordPress Site Information
========================================

Domain:
$DOMAIN

Linux User:
$USER

Database:
$DB

Database User:
$DBUSER

Database Password:
$DBPASS

Admin Username:
$ADMIN_USER

Admin Email:
$ADMIN_EMAIL

Created:
$(date)

========================================
EOF

chown $USER:$USER /home/$USER/site-info.txt
chmod 600 /home/$USER/site-info.txt


sudo -u "$USER" wp plugin install redis-cache \
--activate \
--path=/home/$USER/public_html

sudo -u "$USER" wp redis enable \
--path=/home/$USER/public_html


if ! grep -qxF "$DOMAIN" /opt/wp-host/sites.list 2>/dev/null; then
    echo "$DOMAIN" >> /opt/wp-host/sites.list
fi



echo ""
echo "Registering site..."

grep -qxF "$DOMAIN" /opt/wp-host/sites.list || \
echo "$DOMAIN" >> /opt/wp-host/sites.list

echo "Site registered."
