#!/bin/bash
set -e

# ----------------------------
# EDIT THESE VALUES
# ----------------------------
DOMAIN="localhost"
DOCROOT="/var/www/wordpress"

# ----------------------------
# DATABASE MODE
# ----------------------------
# Default: LOCAL DB (MariaDB on EC2)
DB_HOST="localhost"

# If you want AWS RDS, comment above and uncomment below
# DB_HOST="mysql.bksdjbck.bwcdubud.rds.aws.com"
# RDS_ADMIN_USER="admin"
# RDS_ADMIN_PASS="test1234"

# WordPress DB details (works for both local & RDS)
DB_NAME="wpdb"
DB_USER="wpuser"
DB_PASS="Wp@12345"

echo "======================================"
echo " Installing WordPress (Local DB Default)"
echo "======================================"

# ----------------------------
# Update system
# ----------------------------
sudo apt update -y

# ----------------------------
# Install Apache + PHP + required packages
# ----------------------------
sudo apt install -y apache2 curl unzip wget \
  php php-cli php-common php-mysql php-xml php-gd php-curl php-mbstring php-zip php-intl php-bcmath

# ----------------------------
# Install DB packages (LOCAL DB)
# ----------------------------
sudo apt install -y mariadb-server mariadb-client

# If using RDS, you only need mysql-client (not mariadb-server)
# sudo apt install -y mysql-client

# ----------------------------
# Enable services
# ----------------------------
sudo systemctl enable --now apache2
sudo systemctl restart apache2

sudo systemctl enable --now mariadb
sudo systemctl restart mariadb

# ----------------------------
# Create DB + user (LOCAL MariaDB)
# ----------------------------
echo "Creating WordPress DB and user (LOCAL MariaDB)..."
sudo mysql -e "
CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
"

# ----------------------------
# Create DB + user (AWS RDS) - COMMENTED
# ----------------------------
# echo "Creating WordPress DB and user (AWS RDS)..."
# mysql -h "${DB_HOST}" -u "${RDS_ADMIN_USER}" -p"${RDS_ADMIN_PASS}" -e "
# CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
# CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
# GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
# FLUSH PRIVILEGES;
# "

# ----------------------------
# Download WordPress
# ----------------------------
echo "Downloading WordPress..."
sudo rm -rf "${DOCROOT}"
sudo mkdir -p /var/www
cd /tmp

wget -q https://wordpress.org/latest.zip -O wordpress.zip
unzip -q wordpress.zip
sudo mv wordpress "${DOCROOT}"

# ----------------------------
# Configure wp-config.php
# ----------------------------
echo "Configuring WordPress wp-config.php..."
sudo cp "${DOCROOT}/wp-config-sample.php" "${DOCROOT}/wp-config.php"

sudo sed -i "s/database_name_here/${DB_NAME}/" "${DOCROOT}/wp-config.php"
sudo sed -i "s/username_here/${DB_USER}/" "${DOCROOT}/wp-config.php"
sudo sed -i "s/password_here/${DB_PASS}/" "${DOCROOT}/wp-config.php"
sudo sed -i "s/localhost/${DB_HOST}/" "${DOCROOT}/wp-config.php"

# ----------------------------
# Fix permissions
# ----------------------------
sudo chown -R www-data:www-data "${DOCROOT}"
sudo find "${DOCROOT}" -type d -exec chmod 755 {} \;
sudo find "${DOCROOT}" -type f -exec chmod 644 {} \;

# ----------------------------
# Apache VirtualHost
# ----------------------------
echo "Configuring Apache VirtualHost..."
sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

sudo a2enmod rewrite
sudo a2ensite wordpress.conf
sudo a2dissite 000-default.conf || true
sudo systemctl reload apache2

# ----------------------------
# Done
# ----------------------------
echo ""
echo "======================================"
echo " WordPress Installed Successfully"
echo "======================================"
echo "Open in browser:"
echo "  http://SERVER_PUBLIC_IP/"
echo ""
echo "DB Details:"
echo "  Host: ${DB_HOST}"
echo "  DB:   ${DB_NAME}"
echo "  User: ${DB_USER}"
echo "  Pass: ${DB_PASS}"
echo ""
echo "WordPress Path:"
echo "  ${DOCROOT}"
echo "======================================"
