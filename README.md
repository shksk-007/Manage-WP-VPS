# WP Host Manager v2.0

WP Host Manager is a lightning-fast, fully open-source control panel and CLI tool for managing WordPress sites on a bare-metal LEMP stack (Linux, Nginx, MariaDB, PHP-FPM). 

It was built with a "No-Magic" philosophy. Instead of hiding behind bloated codebases, it uses transparent, easy-to-read Bash scripts to provision highly secure and optimized WordPress installations. 

You can manage your server entirely via the **Command Line** or through the stunning **Web Dashboard**.

---

## 🚀 Features

- **Automated LEMP Stack**: One-click installer sets up Nginx, PHP 8.5, MariaDB, Redis, and ClamAV.
- **Web Dashboard**: A beautiful, dark-mode glassmorphism UI running securely on port `3456`.
- **1-Click WP Login**: Instantly generate a magic link to log into any WordPress admin area without needing a password.
- **Security & Scans**: Built-in UFW firewall configuration, Fail2Ban, and on-demand malware scanning (Maldet + ClamAV).
- **Automated Backups & Restores**: Create, manage, and instantly restore full database and file backups with built-in retention policies.
- **Total User Isolation**: Every WordPress site runs under its own restricted Linux user and dedicated PHP-FPM worker pool.

---

## 🛠️ Installation

Run the following commands on a fresh Ubuntu (22.04 / 24.04) or Debian server as `root`:

```bash
# Clone the repository
git clone https://github.com/shksk-007/Manage-Wordpress-Vps.git /opt/wp-host

# Navigate to the directory
cd /opt/wp-host

# Run the automated installer
sudo bash install.sh
```

The installer will automatically install all dependencies, configure Nginx, set up the Web UI, and link the `wp-host` command globally.

---

## 🌐 Web Dashboard Usage

After installation, you can access the Web Dashboard by navigating to:
**`http://<your-server-ip>:3456`**

### Default Login
- **Username**: `admin`
- **Password**: `admin`

### 🔒 How to Change the Web Password
For security, you must change the default password immediately after installation.
1. Open the API file on your server:
   ```bash
   nano /opt/wp-host/ui/api.php
   ```
2. Find lines 7 and 8 at the top of the file:
   ```php
   $admin_user = 'admin';
   $admin_pass = 'admin';
   ```
3. Change `admin` to your desired username and secure password.
4. Save the file (Ctrl+O, Enter, Ctrl+X). The changes take effect instantly.

---

## 💻 Command Line (CLI) Usage

If you prefer the terminal, or want to script your own automations, you can use the global `wp-host` command from anywhere on your server.

### Available Commands:
```bash
# Site Management
wp-host create example.com      # Interactive site creation wizard
wp-host delete example.com      # Delete a site and database completely
wp-host list                    # List all installed sites

# Backups & Restores
wp-host backup example.com      # Create a full backup
wp-host restore example.com     # Open the interactive restore wizard

# Security & Health
wp-host scan example.com        # Run a ClamAV/Maldet malware scan
wp-host security                # Check firewall and open ports
wp-host doctor                  # Run system health diagnostics
wp-host monitor                 # View live server metrics (top/htop wrapper)

# Utilities
wp-host login example.com       # Generate a 1-click WP Admin magic link
wp-host logs example.com        # View recent Nginx and PHP errors for a site
```

---

## 📂 Architecture & Modifying the Code

WP Host Manager is designed to be modified! If you want to change how a site is provisioned, you don't need to learn a new framework—just edit the bash scripts.

- **`wp-host`**: The main router. It catches your CLI commands and routes them to the `scripts/` folder.
- **`scripts/`**: Contains the individual bash scripts (e.g., `create.sh`, `backup.sh`). Feel free to edit these to add your own custom WordPress plugins or tweaks!
- **`templates/`**: Contains the boilerplate `nginx.conf` and `php-pool.conf` that are used when creating a new site.
- **`ui/`**: Contains the HTML, CSS, JS, and PHP backend for the Web Dashboard. The Web UI interacts with the bash scripts securely via a strict `sudoers` rule.

---
*Built for the open-source community.*
