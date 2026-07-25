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

REQUIRED_PKGS="nginx php8.5-fpm ufw fail2ban redis-server mariadb-server clamav certbot"
NEEDS_INSTALL=0
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        NEEDS_INSTALL=1
        break
    fi
done

if [ "$NEEDS_INSTALL" -eq 1 ]; then

echo "[1/7] Updating system and installing prerequisites..."
apt update
apt install -y software-properties-common curl git wget unzip fail2ban ufw

echo "[2/7] Adding Repositories (PHP & Nginx)..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        add-apt-repository ppa:ondrej/php -y
        apt update
    elif [ "$ID" = "debian" ]; then
        curl -sSL https://packages.sury.org/php/README.txt | bash -x
        apt update
    fi
    # Add official Nginx repository
    apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/$ID `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx
    apt update
fi

echo "[3/7] Installing LEMP Stack & Dependencies..."
# Note: Purging other PHP versions to ensure only PHP 8.5 is installed
apt-get purge -y '^php.*'
apt autoremove -y

# Note: Installing PHP 8.5, Nginx, and ClamAV
apt install -y nginx mariadb-server redis-server certbot python3-certbot-nginx clamav clamav-daemon
apt install -y php8.5-fpm php8.5-cli php8.5-mysql php8.5-xml php8.5-curl php8.5-mbstring php8.5-zip php8.5-gd php8.5-redis

# Ensure ClamAV databases are up to date
systemctl stop clamav-freshclam || true
freshclam || true
systemctl start clamav-freshclam || true

# Optimize MariaDB to prevent connection timeouts caused by reverse DNS lookups
mkdir -p /etc/mysql/mariadb.conf.d/
echo -e "[mysqld]\nskip-name-resolve" > /etc/mysql/mariadb.conf.d/99-skip-name-resolve.cnf
systemctl restart mariadb || true
# Ensure MariaDB is enabled and running
systemctl enable mariadb || true
systemctl start mariadb || true
echo "[3.5/7] Configuring Automated Cron Jobs..."
# Setup Cron for Backups (Daily at 2 AM)
echo "0 2 * * * root /usr/local/bin/wp-host backup --all" > /etc/cron.d/wp-host-backups
chmod 644 /etc/cron.d/wp-host-backups

# Setup Cron for Security Scans (Twice a day at 6 AM and 6 PM)
echo "0 6,18 * * * root /usr/local/bin/wp-host scan --all" > /etc/cron.d/wp-host-scan
chmod 644 /etc/cron.d/wp-host-scan

# Update hardcoded 8.3 to 8.5 in scripts if they exist
find . -type f -name "*.sh" -exec sed -i 's/php8.3/php8.5/g' {} +
find . -type f -name "*.sh" -exec sed -i 's/8.3/8.5/g' {} +

echo "[4/7] Installing WP-CLI..."
if [ ! -f /usr/local/bin/wp ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

else
    echo "Dependencies already installed. Skipping to core setup..."
fi

echo "[5/7] Setting up WP Host Manager core..."
mkdir -p /opt/wp-host
mkdir -p /opt/wp-host/logs
mkdir -p /opt/wp-host/backups

# Assuming this script is run from the cloned repository:
if [ "$PWD" != "/opt/wp-host" ]; then
    cp -r ./* /opt/wp-host/
fi

# Ensure sites.list exists
touch /opt/wp-host/sites.list

# Make scripts executable
chmod +x /opt/wp-host/wp-host
chmod +x /opt/wp-host/scripts/*.sh

# Global symlink
ln -sf /opt/wp-host/wp-host /usr/local/bin/wp-host

echo "[6/7] Setting up Web UI..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

if ! grep -q "sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
    sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf || true
fi

# Set up FastCGI Cache zone
mkdir -p /var/run/nginx-cache
chown -R www-data:www-data /var/run/nginx-cache
cat > /etc/nginx/conf.d/fastcgi_cache.conf <<'EOF'
fastcgi_cache_path /var/run/nginx-cache levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
EOF

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

# Ensure Nginx user can read PHP-FPM default socket
usermod -aG www-data nginx || true
systemctl restart nginx || echo "Nginx not started in testing environment"

echo "[7/7] Configuring Firewall..."
ufw allow 80/tcp || true
ufw allow 443/tcp || true
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
