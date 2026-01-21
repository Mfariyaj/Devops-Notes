#!/bin/bash
set -e

# ----------------------------
# CONFIG
# ----------------------------
DOMAIN="localhost"
DOCROOT="/var/www/joomla"

# Local DB
DB_HOST="localhost"
DB_NAME="joomladb"
DB_USER="joomlauser"
DB_PASS="Joomla@12345"

# ✅ Joomla official download link (from your screenshot)
JOOMLA_URL="https://downloads.joomla.org/cms/joomla5/5-1-2/Joomla_5-1-2-Stable-Full_Package.zip?format=zip"

echo "======================================"
echo " CLEAN + INSTALL JOOMLA (Ubuntu)"
echo "======================================"

# ----------------------------
# CLEANUP
# ----------------------------
echo "[1/7] Cleaning old Joomla + Apache configs..."
sudo rm -rf "${DOCROOT}"
sudo mkdir -p "${DOCROOT}"

sudo rm -f /etc/apache2/sites-available/joomla.conf
sudo rm -f /etc/apache2/sites-enabled/joomla.conf

# ----------------------------
# INSTALL PACKAGES
# ----------------------------
echo "[2/7] Installing packages..."
sudo apt update -y
sudo apt install -y apache2 mariadb-server mariadb-client \
  php libapache2-mod-php php-mysql php-xml php-mbstring php-curl php-zip php-intl php-gd \
  unzip wget

# ----------------------------
# START SERVICES
# ----------------------------
echo "[3/7] Starting services..."
sudo systemctl enable --now apache2
sudo systemctl enable --now mariadb
sudo systemctl restart apache2
sudo systemctl restart mariadb

# ----------------------------
# RESET DB
# ----------------------------
echo "[4/7] Resetting Joomla DB (LOCAL MariaDB)..."
sudo mysql -e "DROP DATABASE IF EXISTS ${DB_NAME};" || true
sudo mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" || true

sudo mysql -e "
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
"

# ----------------------------
# DOWNLOAD + EXTRACT JOOMLA
# ----------------------------
echo "[5/7] Downloading and extracting Joomla..."
cd /tmp
sudo rm -f /tmp/joomla.zip

sudo wget -O /tmp/joomla.zip "${JOOMLA_URL}"

# Validate zip
if ! unzip -t /tmp/joomla.zip >/dev/null 2>&1; then
  echo "ERROR: Downloaded file is not a valid zip."
  ls -lh /tmp/joomla.zip
  file /tmp/joomla.zip
  exit 1
fi

sudo rm -rf "${DOCROOT:?}/"*
sudo unzip -q /tmp/joomla.zip -d "${DOCROOT}"

if [ ! -f "${DOCROOT}/index.php" ]; then
  echo "ERROR: Joomla extraction failed. index.php not found."
  exit 1
fi

# ----------------------------
# PERMISSIONS
# ----------------------------
echo "[6/7] Fixing permissions..."
sudo chown -R www-data:www-data "${DOCROOT}"
sudo find "${DOCROOT}" -type d -exec chmod 755 {} \;
sudo find "${DOCROOT}" -type f -exec chmod 644 {} \;

# ----------------------------
# APACHE VHOST
# ----------------------------
echo "[7/7] Configuring Apache VirtualHost..."
sudo tee /etc/apache2/sites-available/joomla.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        AllowOverride All
        Require all granted
    </Directory>

    DirectoryIndex index.php index.html

    ErrorLog \${APACHE_LOG_DIR}/joomla_error.log
    CustomLog \${APACHE_LOG_DIR}/joomla_access.log combined
</VirtualHost>
EOF

sudo a2enmod rewrite
sudo a2ensite joomla.conf
sudo a2dissite 000-default.conf || true
sudo systemctl restart apache2

echo ""
echo "======================================"
echo " Joomla Installed Successfully"
echo "======================================"
echo "Open in browser:"
echo "  http://<your-public-ip>/"
echo ""
echo "Database Details for Joomla Setup:"
echo "  DB Host: ${DB_HOST}"
echo "  DB Name: ${DB_NAME}"
echo "  DB User: ${DB_USER}"
echo "  DB Pass: ${DB_PASS}"
echo "======================================"
