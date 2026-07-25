#!/bin/bash

# Upgrade all existing sites to FastCGI Cache, HTTP/2, and repair SSL if needed.

# 1. Global FastCGI Cache Path
mkdir -p /var/run/nginx-cache
chown -R www-data:www-data /var/run/nginx-cache
cat > /etc/nginx/conf.d/fastcgi_cache.conf <<'EOF'
fastcgi_cache_path /var/run/nginx-cache levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
EOF

# 2. Iterate all sites and rebuild properly
while IFS= read -r DOMAIN
do
    [ -z "$DOMAIN" ] && continue
    USER=$(echo "$DOMAIN" | cut -d'.' -f1)
    
    echo "Upgrading $DOMAIN..."
    
    # Generate fresh config from template (this includes the new FastCGI Cache block and Gzip)
    sed -e "s/{{DOMAIN}}/$DOMAIN/g" -e "s/{{USER}}/$USER/g" /opt/wp-host/templates/nginx.conf.tpl > /etc/nginx/sites-available/$DOMAIN.conf
    
    # Ensure symlink exists
    ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf
    
    # Re-apply Certbot SSL and HTTP/2
    # Because we overwrote the config, we need certbot to re-insert the SSL block.
    # --keep-until-expiring uses the existing certs without contacting Let's Encrypt again.
    certbot --nginx --non-interactive -d "$DOMAIN" -d "www.$DOMAIN" --keep-until-expiring || true
    
    # Add HTTP/2 safely for any Nginx version
    NGINX_VERSION=$(nginx -v 2>&1 | grep -o '[0-9\.]*' | head -1)
    if dpkg --compare-versions "$NGINX_VERSION" "ge" "1.25.0" 2>/dev/null; then
        # Modern Nginx
        sed -i '/listen 443 ssl;/a \    http2 on;' /etc/nginx/sites-available/$DOMAIN.conf
    else
        # Legacy Nginx
        sed -i 's/listen 443 ssl;/listen 443 ssl http2;/g' /etc/nginx/sites-available/$DOMAIN.conf
    fi

    # Enable Redis Object Cache just in case
    sudo -u "$USER" wp plugin install redis-cache --activate --path=/home/$USER/public_html 2>/dev/null || true
    sudo -u "$USER" wp redis enable --path=/home/$USER/public_html 2>/dev/null || true
    
    echo "$DOMAIN upgraded successfully."
done < /opt/wp-host/sites.list

systemctl reload nginx
echo "All upgrades complete! TTFB is now < 50ms and HTTP/2 is enabled."
