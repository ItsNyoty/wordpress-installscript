#!/bin/bash

# Variabelen voor installatie
WP_DIR="/var/www/html"
WP_URL="https://wordpress.org/latest.tar.gz"
WP_CONFIG="$WP_DIR/wp-config.php"
APACHE_CONFIG="/etc/apache2/sites-available/wordpress.conf"

# Header
clear
echo "============================================"
echo "  WordPress Installatiescript"
echo "============================================"

# Databasegegevens vragen
echo "De MySQL-database en gebruiker moeten nog worden aangemaakt."
read -p "Voer de naam in voor de NIEUWE database: " DB_NAME
read -p "Voer de gewenste gebruikersnaam in voor de NIEUWE databasegebruiker: " DB_USER
read -s -p "Voer het gewenste wachtwoord in voor de databasegebruiker: " DB_PASS
echo
read -s -p "Voer het MySQL root-wachtwoord in: " DB_ROOT_PASS
echo
read -p "Voer de database host in (standaard: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Voer jouw domeinnaam in (bijv. example.com): " DOMAIN

# MySQL database en gebruiker aanmaken
echo "--------------------------------------------"
echo "Database en gebruiker worden aangemaakt..."
mysql -u root -p$DB_ROOT_PASS <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
echo " Database en gebruiker zijn aangemaakt!"

# Installeren van Apache, MySQL en PHP
sudo apt update
sudo apt install -y apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip certbot python3-certbot-apache

# WordPress downloaden en instellen
echo "--------------------------------------------"
echo "WordPress downloaden en installeren..."
wget -q $WP_URL -O wordpress.tar.gz
tar -xzf wordpress.tar.gz
rm wordpress.tar.gz
sudo mv wordpress/* $WP_DIR
sudo rmdir wordpress
echo " WordPress bestanden zijn geplaatst!"

# Standaard WordPress configuratie kopiëren
cp $WP_DIR/wp-config-sample.php $WP_CONFIG

# Wachtwoorden genereren voor salts
echo "Unieke sleutels genereren..."
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# wp-config.php aanpassen
sed -i "s/database_name_here/$DB_NAME/" $WP_CONFIG
sed -i "s/username_here/$DB_USER/" $WP_CONFIG
sed -i "s/password_here/$DB_PASS/" $WP_CONFIG
sed -i "s/localhost/$DB_HOST/" $WP_CONFIG

# Voeg salts toe
sed -i "/AUTH_KEY/d" $WP_CONFIG
echo "$SALTS" >> $WP_CONFIG

# Apache VirtualHost configureren
echo "--------------------------------------------"
echo "Apache VirtualHost configureren..."
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

# Apache modules en instellingen inschakelen
sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default

# SSL certificaat verkrijgen
echo "--------------------------------------------"
echo "SSL certificaat verkrijgen..."
sudo certbot --apache -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Apache herstarten
sudo systemctl restart apache2

# Bestandsrechten instellen
chown -R www-data:www-data $WP_DIR
find $WP_DIR -type d -exec chmod 755 {} \;
find $WP_DIR -type f -exec chmod 644 {} \;

# Installatie voltooid
echo "--------------------------------------------"
echo " WordPress installatie voltooid!"
echo "Ga naar https://$DOMAIN om verder te gaan."
echo "--------------------------------------------"
