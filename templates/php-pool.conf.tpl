[{{USER}}]

user = {{USER}}
group = {{USER}}

listen = /run/php/php8.5-{{USER}}.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660

pm = dynamic

pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6

pm.max_requests = 500

clear_env = no

security.limit_extensions = .php

php_admin_value[upload_tmp_dir] = /home/{{USER}}/tmp
php_admin_value[session.save_path] = /home/{{USER}}/tmp
php_admin_value[open_basedir] = /home/{{USER}}/:/tmp/:/usr/share/php/
