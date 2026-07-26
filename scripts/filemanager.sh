#!/bin/bash

set -e

DOMAIN=$1
ACTION=$2

if [ -z "$DOMAIN" ] || [ -z "$ACTION" ]; then
    echo "Usage: wp-host fm <domain> <on|off>"
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

if [ ! -d "/home/$USER/public_html" ]; then
    echo "Error: Site $DOMAIN not found."
    exit 1
fi

FM_DIR="/home/$USER/public_html/fm-manager"

if [ "$ACTION" = "on" ]; then
    if [ -d "$FM_DIR" ]; then
        echo "File Manager is already ON."
        exit 0
    fi
    
    # Cache elFinder if not exists
    if [ ! -d "/opt/wp-host/lib/elfinder" ]; then
        echo "Downloading elFinder..."
        mkdir -p /opt/wp-host/lib
        cd /opt/wp-host/lib
        wget -q https://github.com/Studio-42/elFinder/archive/refs/tags/2.1.65.zip
        unzip -q 2.1.65.zip
        mv elFinder-2.1.65 elfinder
        rm 2.1.65.zip
    fi
    
    mkdir -p "$FM_DIR"
    cp -r /opt/wp-host/lib/elfinder/* "$FM_DIR/"
    
    PASSWORD=$(openssl rand -base64 12)
    HASH=$(php -r "echo password_hash('$PASSWORD', PASSWORD_DEFAULT);")
    
    cat > "$FM_DIR/index.php" <<EOF
<?php
session_start();
\$hash = '$HASH';
if (isset(\$_GET['logout'])) {
    session_destroy();
    header("Location: index.php");
    exit;
}
if (isset(\$_POST['password'])) {
    if (password_verify(\$_POST['password'], \$hash)) {
        \$_SESSION['fm_auth'] = true;
    } else {
        \$error = "Invalid Password";
    }
}
if (!isset(\$_SESSION['fm_auth'])) {
    ?>
    <!DOCTYPE html>
    <html><head><title>File Manager Login</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f2f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .login-box { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); text-align: center; }
        input[type=password] { padding: 10px; width: 200px; border: 1px solid #ccc; border-radius: 4px; outline: none; }
        button { padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; margin-left: 10px; }
        button:hover { background: #0056b3; }
        .logo { width: 64px; margin-bottom: 20px; }
    </style>
    </head><body>
    <div class="login-box">
        <svg class="logo" viewBox="0 0 24 24" fill="none" stroke="#007bff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>
        <h2 style="margin-top:0; color:#333;">File Manager</h2>
        <?php if(isset(\$error)) echo "<p style='color:red;'>\$error</p>"; ?>
        <form method="POST">
            <input type="password" name="password" placeholder="Enter Password" required>
            <button type="submit">Login</button>
        </form>
    </div>
    </body></html>
    <?php
    exit;
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=2">
    <title>File Manager</title>
    <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.12.1/themes/smoothness/jquery-ui.min.css">
    <link rel="stylesheet" type="text/css" href="css/elfinder.min.css">
    <link rel="stylesheet" type="text/css" href="css/theme.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js"></script>
    <script src="js/elfinder.min.js"></script>
    <script type="text/javascript" charset="utf-8">
        \$(document).ready(function() {
            \$('#elfinder').elfinder({
                url : 'php/connector.minimal.php',
                height: \$(window).height(),
                uiOptions: {
                    toolbar : [
                        ['back', 'forward'],
                        ['reload'],
                        ['home', 'up'],
                        ['mkdir', 'mkfile', 'upload'],
                        ['open', 'download', 'getfile'],
                        ['info'],
                        ['quicklook'],
                        ['copy', 'cut', 'paste'],
                        ['rm'],
                        ['duplicate', 'rename', 'edit'],
                        ['extract', 'archive'],
                        ['search'],
                        ['view'],
                        ['help']
                    ]
                }
            });
            \$(window).resize(function(){
                var h = \$(window).height();
                \$('#elfinder').height(h).resize();
            });
        });
    </script>
    <style> body, html { margin: 0; padding: 0; height: 100%; overflow: hidden; background: #fff; } </style>
</head>
<body>
    <div id="elfinder"></div>
</body>
</html>
EOF
    
    # Secure the connector minimal php
    sed -i 's|<?php|<?php session_start(); if(!isset($_SESSION["fm_auth"])) exit;|' "$FM_DIR/php/connector.minimal.php"
    
    # Change root path to the user's public_html instead of elFinder folder
    sed -i "s|'path'          => '../'|'path'          => '/home/$USER/public_html/'|g" "$FM_DIR/php/connector.minimal.php"
    sed -i "s|'URL'           => dirname(\\$_SERVER\\['PHP_SELF'\\]) . '/../'|'URL'           => '/'|g" "$FM_DIR/php/connector.minimal.php"

    chown -R "$USER:$USER" "$FM_DIR"
    
    echo "File Manager ON"
    echo "URL: http://$DOMAIN/fm-manager"
    echo "Password: $PASSWORD"
    
elif [ "$ACTION" = "off" ]; then
    if [ -d "$FM_DIR" ]; then
        rm -rf "$FM_DIR"
    fi
    echo "File Manager OFF"
else
    echo "Invalid action. Use 'on' or 'off'."
    exit 1
fi
