#!/bin/bash
set -e

# ----------------------------
# CONFIG (edit if needed)
# ----------------------------
DOMAIN="localhost"
DOCROOT="/var/www/moodle"
MOODLEDATA="/var/moodledata"

DB_NAME="moodledb"
DB_USER="moodleuser"
DB_PASS="Moodle@12345"

# Moodle version branch (recommended stable)
MOODLE_BRANCH="MOODLE_404_STABLE"

echo "======================================"
echo " CLEAN + INSTALL MOODLE (Apache + DB)"
echo "======================================"

# ----------------------------
# CLEANUP OLD INSTALL
# ----------------------------
echo "[1/8] Cleaning old Moodle + Apache configs..."
sudo rm -rf "${DOCROOT}"
sudo rm -rf "${MOODLEDATA}"

sudo a2dissite moodle.conf >/dev/null 2>&1 || true
sudo rm -f /etc/apache2/sites-available/moodle.conf
sudo rm -f /etc/apache2/sites-enabled/moodle.conf

# ----------------------------
# INSTALL PACKAGES
# ----------------------------
echo "[2/8] Installing packages..."
sudo apt update -y

sudo apt install -y apache2 mariadb-server mariadb-client git unzip curl \
  php libapache2-mod-php \
  php-mysql php-xml php-mbstring php-curl php-zip php-intl php-gd php-soap php-xmlrpc php-cli php-bcmath php-tokenizer

# ----------------------------
# START SERVICES
# ----------------------------
echo "[3/8] Starting services..."
sudo systemctl enable --now apache2
sudo systemctl enable --now mariadb
sudo systemctl restart apache2
sudo systemctl restart mariadb

# ----------------------------
# RESET DB
# ----------------------------
echo "[4/8] Creating Moodle DB + user..."
sudo mysql -e "DROP DATABASE IF EXISTS ${DB_NAME};" || true
sudo mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" || true

sudo mysql -e "
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
"

# ----------------------------
# DOWNLOAD MOODLE (GIT)
# ----------------------------
echo "[5/8] Downloading Moodle from git..."
sudo git clone -b "${MOODLE_BRANCH}" https://github.com/moodle/moodle.git "${DOCROOT}"

# ----------------------------
# CREATE MOODLEDATA DIRECTORY
# ----------------------------
echo "[6/8] Creating moodledata directory..."
sudo mkdir -p "${MOODLEDATA}"
sudo chown -R www-data:www-data "${DOCROOT}"
sudo chown -R www-data:www-data "${MOODLEDATA}"
sudo chmod -R 770 "${MOODLEDATA}"

# ----------------------------
# APACHE VHOST
# ----------------------------
echo "[7/8] Configuring Apache VirtualHost..."
sudo tee /etc/apache2/sites-available/moodle.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/moodle_error.log
    CustomLog \${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>
EOF

sudo a2enmod rewrite
sudo a2ensite moodle.conf
sudo a2dissite 000-default.conf || true
sudo systemctl restart apache2

# ----------------------------
# FINAL MESSAGE
# ----------------------------
echo ""
echo "======================================"
echo " Moodle Installed (Files Ready)"
echo "======================================"
echo "Now open in browser:"
echo "  http://<your-public-ip>/"
echo ""
echo "During Moodle Web Setup use:"
echo "  DB Type:   MariaDB / MySQL"
echo "  DB Host:   localhost"
echo "  DB Name:   ${DB_NAME}"
echo "  DB User:   ${DB_USER}"
echo "  DB Pass:   ${DB_PASS}"
echo ""
echo "Moodle code path:     ${DOCROOT}"
echo "Moodle data path:     ${MOODLEDATA}"
echo "======================================"
