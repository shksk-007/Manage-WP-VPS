server {
    listen 80;

    server_name {{DOMAIN}} www.{{DOMAIN}};

    root /home/{{USER}}/public_html;
    index index.php index.html;

    access_log /home/{{USER}}/logs/access.log;
    error_log  /home/{{USER}}/logs/error.log;

    client_max_body_size 256M;

    set $skip_cache 0;

    # POST requests and urls with a query string should always go to PHP
    if ($request_method = POST) {
        set $skip_cache 1;
    }
    if ($query_string != "") {
        set $skip_cache 1;
    }

    # Don't cache uris containing the following segments
    if ($request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
        set $skip_cache 1;
    }

    # Don't use the cache for logged-in users or recent commenters
    if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
        set $skip_cache 1;
    }

    # WooCommerce specific bypass
    if ($request_uri ~* "/store.*|/cart.*|/my-account.*|/checkout.*|/addons.*") {
        set $skip_cache 1;
    }
    if ($http_cookie ~* "woocommerce_items_in_cart|woocommerce_cart_hash|wp_woocommerce_session_") {
        set $skip_cache 1;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Aggressive caching for static assets
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml|webp|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, no-transform";
    }

    # Enable Gzip Compression
    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types application/javascript application/json application/xml text/css text/plain text/xml;

    location ~ \.php$ {
        try_files $uri =404;

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;

        fastcgi_pass unix:/run/php/php8.5-{{USER}}.sock;

        # FastCGI Cache Directives
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        fastcgi_cache WORDPRESS;
        fastcgi_cache_valid 200 301 302 60m;
        add_header X-FastCGI-Cache $upstream_cache_status;
    }

    location ~ /\. {
        deny all;
    }
}
