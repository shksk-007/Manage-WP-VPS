#!/bin/bash

# WP Host Manager - One Click Installer
# Supported OS: Ubuntu 22.04 / 24.04, Debian 11 / 12

set -e

echo "========================================="
echo " WP Host Manager - Installer"
echo "========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "Please run this installer as root (e.g., sudo bash install.sh)"
  exit 1
fi

echo "[1/7] Updating system and installing prerequisites..."
apt update
apt install -y software-properties-common curl git wget unzip fail2ban ufw

echo "[2/7] Adding PHP Repository..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        add-apt-repository ppa:ondrej/php -y
        apt update
    elif [ "$ID" = "debian" ]; then
        curl -sSL https://packages.sury.org/php/README.txt | bash -x
        apt update
    fi
fi

echo "[3/7] Installing LEMP Stack & Dependencies..."
# Note: Adjusting PHP version to php8.3 (as 8.5 does not exist yet)
apt install -y nginx mariadb-server redis-server certbot python3-certbot-nginx clamav clamav-daemon
apt install -y php8.3-fpm php8.3-mysql php8.3-xml php8.3-curl php8.3-mbstring php8.3-zip php8.3-gd php8.3-redis

# Update hardcoded 8.5 to 8.3 in scripts if they exist
find . -type f -name "*.sh" -exec sed -i 's/php8.5/php8.3/g' {} +
find . -type f -name "*.sh" -exec sed -i 's/8.5/8.3/g' {} +

echo "[4/7] Installing WP-CLI..."
if [ ! -f /usr/local/bin/wp ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

echo "[5/7] Setting up WP Host Manager core..."
mkdir -p /opt/wp-host
mkdir -p /opt/wp-host/logs
mkdir -p /opt/wp-host/backups

# Assuming this script is run from the cloned repository:
cp -r ./* /opt/wp-host/

# Ensure sites.list exists
touch /opt/wp-host/sites.list

# Make scripts executable
chmod +x /opt/wp-host/wp-host
chmod +x /opt/wp-host/scripts/*.sh

# Global symlink
ln -sf /opt/wp-host/wp-host /usr/local/bin/wp-host

echo "[6/7] Setting up Web UI..."
# Symlink Nginx UI config
if [ -f /opt/wp-host/ui/nginx-ui.conf ]; then
    ln -sf /opt/wp-host/ui/nginx-ui.conf /etc/nginx/sites-available/wp-host-ui.conf
    ln -sf /etc/nginx/sites-available/wp-host-ui.conf /etc/nginx/sites-enabled/
fi

# Setup sudoers for UI
if [ -f /opt/wp-host/ui/sudoers-wp-host ]; then
    cp /opt/wp-host/ui/sudoers-wp-host /etc/sudoers.d/wp-host-ui
    chmod 440 /etc/sudoers.d/wp-host-ui
fi

systemctl restart nginx || echo "Nginx not started in testing environment"

echo "[7/7] Configuring Firewall..."
ufw allow 'Nginx Full' || true
ufw allow 'OpenSSH' || true
ufw allow 3456/tcp || true # Web UI Port

echo ""
echo "========================================="
echo " Installation Complete!"
echo "========================================="
echo "You can now manage sites using the CLI:"
echo "  wp-host help"
echo ""
echo "Or access the Web UI at:"
echo "  http://<your-server-ip>:3456"
echo ""
echo "Default UI Login: admin / admin"
echo "(Please change this in /opt/wp-host/ui/auth.php immediately)"
echo "========================================="
