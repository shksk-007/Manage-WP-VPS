[{{USER}}]

user = {{USER}}
group = {{USER}}

listen = /run/php/php8.5-{{USER}}.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660

pm = dynamic

pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15

pm.max_requests = 1000

clear_env = no

security.limit_extensions = .php

php_admin_value[upload_tmp_dir] = /home/{{USER}}/tmp
php_admin_value[session.save_path] = /home/{{USER}}/tmp
php_admin_value[open_basedir] = /home/{{USER}}/:/tmp/:/usr/share/php/
