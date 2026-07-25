server {
    listen 80;

    server_name {{DOMAIN}} www.{{DOMAIN}};

    root /home/{{USER}}/public_html;
    index index.php index.html;

    access_log /home/{{USER}}/logs/access.log;
    error_log  /home/{{USER}}/logs/error.log;

    client_max_body_size 256M;

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
    }

    location ~ /\. {
        deny all;
    }
}
