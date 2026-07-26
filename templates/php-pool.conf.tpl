[{{USER}}]

user = {{USER}}
group = {{USER}}

listen = /run/php/php8.5-{{USER}}.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660

pm = dynamic

pm.max_children = 200
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 30

pm.max_requests = 1000

php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[upload_max_filesize] = 256M
php_admin_value[post_max_size] = 256M
php_admin_value[max_input_vars] = 5000

clear_env = no

security.limit_extensions = .php

php_admin_value[upload_tmp_dir] = /home/{{USER}}/tmp
php_admin_value[session.save_path] = /home/{{USER}}/tmp
php_admin_value[open_basedir] = /home/{{USER}}/:/tmp/:/usr/share/php/
