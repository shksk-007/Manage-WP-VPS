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
