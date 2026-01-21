#!/bin/bash
set -e

# ----------------------------
# EDIT THESE VALUES
# ----------------------------
DOMAIN="localhost"              # keep localhost for testing
DOCROOT="/var/www/drupal"
DB_NAME="drupaldb"
DB_USER="drupaluser"
DB_PASS="Drupal@12345"
ADMIN_USER="admin"
ADMIN_PASS="Admin@12345"
ADMIN_EMAIL="admin@example.com"
SITE_NAME="My Drupal Site"

echo "=============================="
echo " Installing Apache + Drupal"
echo "=============================="

# ----------------------------
# Update system
# ----------------------------
sudo apt update -y

# ----------------------------
# Install Apache + MariaDB + PHP + dependencies
# ----------------------------
sudo apt install -y apache2 mariadb-server curl unzip git \
  php php-cli php-common php-mysql php-xml php-gd php-curl php-mbstring php-zip php-intl php-bcmath

# ----------------------------
# Start & enable services
# ----------------------------
sudo systemctl enable --now apache2
sudo systemctl enable --now mariadb

# ----------------------------
# Ensure Apache is listening on port 80
# ----------------------------
sudo systemctl restart apache2

# ----------------------------
# Secure MariaDB (basic cleanup)
# ----------------------------
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# ----------------------------
# Create Drupal DB + user
# ----------------------------
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# ----------------------------
# Install Composer
# ----------------------------
if ! command -v composer >/dev/null 2>&1; then
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/local/bin/composer
fi

# ----------------------------
# Install Drupal using Composer
# ----------------------------
sudo rm -rf "${DOCROOT}"
sudo mkdir -p /var/www
sudo composer create-project drupal/recommended-project "${DOCROOT}" -n

# ----------------------------
# Fix permissions
# ----------------------------
sudo chown -R www-data:www-data "${DOCROOT}"
sudo find "${DOCROOT}" -type d -exec chmod 755 {} \;
sudo find "${DOCROOT}" -type f -exec chmod 644 {} \;

# ----------------------------
# Create Apache VirtualHost
# ----------------------------
sudo tee /etc/apache2/sites-available/drupal.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${DOCROOT}/web

    <Directory ${DOCROOT}/web>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/drupal_error.log
    CustomLog \${APACHE_LOG_DIR}/drupal_access.log combined
</VirtualHost>
EOF

sudo a2enmod rewrite
sudo a2ensite drupal.conf
sudo a2dissite 000-default.conf || true
sudo systemctl reload apache2

# ----------------------------
# Install Drush
# ----------------------------
cd "${DOCROOT}"
sudo -u www-data composer require drush/drush -n

# ----------------------------
# Install Drupal site
# ----------------------------
cd "${DOCROOT}/web"

sudo -u www-data ../vendor/bin/drush site:install standard \
  --db-url="mysql://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}" \
  --site-name="${SITE_NAME}" \
  --account-name="${ADMIN_USER}" \
  --account-pass="${ADMIN_PASS}" \
  --account-mail="${ADMIN_EMAIL}" \
  -y

# ----------------------------
# Show Status
# ----------------------------
echo ""
echo "=============================="
echo " Drupal Installation Completed"
echo "=============================="
echo "Test Apache:"
echo "  curl -I http://localhost"
echo ""
echo "Open in browser:"
echo "  http://SERVER_PUBLIC_IP/"
echo ""
echo "Admin Login:"
echo "  Username: ${ADMIN_USER}"
echo "  Password: ${ADMIN_PASS}"
echo ""
echo "Docroot:"
echo "  ${DOCROOT}/web"
echo "=============================="
