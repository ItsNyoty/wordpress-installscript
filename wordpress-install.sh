#!/bin/bash

# Variables for installation
WP_DIR="/var/www/html"
WP_URL="https://wordpress.org/latest.tar.gz"
WP_CONFIG="$WP_DIR/wp-config.php"
APACHE_CONFIG="/etc/apache2/sites-available/wordpress.conf"

# Header
clear
echo "============================================"
echo "  WordPress Installation Script"
echo "============================================"

# Requesting database details
echo "The MySQL database and user need to be created."
read -p "Enter the name for the NEW database: " DB_NAME
read -p "Enter the desired username for the NEW database user: " DB_USER
read -s -p "Enter the desired password for the database user: " DB_PASS
echo
read -s -p "Enter the MySQL root password: " DB_ROOT_PASS
echo
read -p "Enter the database host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Enter your domain name (e.g., example.com): " DOMAIN

# Create MySQL database and user
echo "--------------------------------------------"
echo "Creating database and user..."
mysql -u root -p$DB_ROOT_PASS <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
echo " Database and user have been created!"

# Installing Apache, MySQL, and PHP
sudo apt update
sudo apt install -y apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip certbot python3-certbot-apache

# Download and set up WordPress
echo "--------------------------------------------"
echo "Downloading and installing WordPress..."
wget -q $WP_URL -O wordpress.tar.gz
tar -xzf wordpress.tar.gz
rm wordpress.tar.gz
sudo mv wordpress/* $WP_DIR
sudo rmdir wordpress
echo " WordPress files have been placed!"

# Copy default WordPress configuration
cp $WP_DIR/wp-config-sample.php $WP_CONFIG

# Generate passwords for salts
echo "Generating unique keys..."
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Modify wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WP_CONFIG
sed -i "s/username_here/$DB_USER/" $WP_CONFIG
sed -i "s/password_here/$DB_PASS/" $WP_CONFIG
sed -i "s/localhost/$DB_HOST/" $WP_CONFIG

# Add salts
sed -i "/AUTH_KEY/d" $WP_CONFIG
echo "$SALTS" >> $WP_CONFIG

# Configure Apache VirtualHost
echo "--------------------------------------------"
echo "Configuring Apache VirtualHost..."
echo "<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $WP_DIR

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem

    <Directory $WP_DIR>
        Options FollowSymLinks
        AllowOverride All
        DirectoryIndex index.php
        Require all granted
    </Directory>

    <Directory $WP_DIR/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>" | sudo tee $APACHE_CONFIG

# Enable Apache modules and settings
sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default

# Obtain SSL certificate
echo "--------------------------------------------"
echo "Obtaining SSL certificate..."
sudo certbot --apache -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Restart Apache
sudo systemctl restart apache2

# Set file permissions
chown -R www-data:www-data $WP_DIR
find $WP_DIR -type d -exec chmod 755 {} \;
find $WP_DIR -type f -exec chmod 644 {} \;

# Installation complete
echo "--------------------------------------------"
echo " WordPress installation complete!"
echo "Visit https://$DOMAIN to continue."
echo "--------------------------------------------"
