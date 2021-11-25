#!/bin/bash
clear

#Probado en Ubuntu 18.04 LTS y 20.04 LTS
#BETA
#Solo es recomendable usarlo en la primera instalacion de Wordpress, se crea clave root para Mysql cada vez que se inicia el script

echo "###############################################################################"
echo "# WordPress Auto Installation Script for CentOS 8 by Daniele Lolli (UncleDan) #"
echo "###############################################################################"
echo "#"
echo "###############################################################################"
echo "# Editado por kmilo0327 para el uso multi sitio y automatizacion de tareas    #"
echo "###############################################################################"

echo -n "¿Nombre de la pagina?: "
read WPC8_SITE_NAME

echo -n "¿Dominio de la pagina? ex(.com .org)(add dot):  "
read WPC8_SITE_DOMAIN

# Setting parameters
WPC8_MYSQL_WORDPRESS_DATABASE="${WPC8_SITE_NAME}_database"
WPC8_MYSQL_WORDPRESS_USER="${WPC8_SITE_NAME}_user"
WPC8_MYSQL_WORDPRESS_PASSWORD=`date |md5sum |cut -c '1-12'`
WPC8_MYSQL_ROOT_PASSWORD=`date |md5sum |cut -c '1-12'`
WPC8_SITE_FOLDER="/var/www/${WPC8_SITE_NAME}"
WPC8_DATABASE_TABLES_PREFIX="wp_${WPC8_SITE_NAME}"

#Actualizando Sistema
apt update -y && apt upgrade -y

#Instalando Apache y Mysql
apt install apache2 mariadb-server unzip php php-mysql -y php-xml

systemctl start mariadb

echo "*** DONE Configuring both the Apache webserver and the MariaDB services to start after reboot."
echo -e "\n\n*** START Creating a new database for WordPress and a new user with password with all privileges on it..."
echo "CREATE DATABASE $WPC8_MYSQL_WORDPRESS_DATABASE;
CREATE USER \`$WPC8_MYSQL_WORDPRESS_USER\`@\`localhost\` IDENTIFIED BY '$WPC8_MYSQL_WORDPRESS_PASSWORD';
GRANT ALL ON $WPC8_MYSQL_WORDPRESS_DATABASE.* TO \`$WPC8_MYSQL_WORDPRESS_USER\`@\`localhost\`;
FLUSH PRIVILEGES;
EXIT" > __TEMP__.sql
mysql -u root < __TEMP__.sql
rm -f __TEMP__.sql

#######################################################################################################################################

echo -e "\n\n*** START Securing your MariaDB installation and set root password..."
# Hint from: https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
echo "UPDATE mysql.user SET Password=PASSWORD('$WPC8_MYSQL_ROOT_PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE db='test' OR db='test\\_%';
FLUSH PRIVILEGES;
EXIT" > __TEMP__.sql
mysql -u root < __TEMP__.sql
rm -f __TEMP__.sql

#######################################################################################################################################

echo -e "\n\n*** START Adjusting new httpd.conf with custom folder and and rewrite enabled..."
sed -i "122 s|/var/www/|"$WPC8_SITE_FOLDER"|g ;
        134 s|/var/www/|"$WPC8_SITE_FOLDER"|g ;
        154 s|AllowOverride None|AllowOverride All|g" /etc/apache2/apache2.conf

#######################################################################################################################################

curl https://cl.wordpress.org/latest-es_CL.zip --output __TEMP__.zip && unzip -o __TEMP__.zip && rm -f __TEMP__.zip

echo -e "\n\n*** START Moving the extracted WordPress directory into the /var/www/ folder..."
mv -f wordpress $WPC8_SITE_FOLDER

#######################################################################################################################################
echo -e "\n\n*** Configurando WP-config.PHP"

cp /var/www/juegatelag/wp-config-sample.php $WPC8_SITE_FOLDER/wp-config.php
sed -i "s/database_name_here/$WPC8_MYSQL_WORDPRESS_DATABASE/g
        s/username_here/$WPC8_MYSQL_WORDPRESS_USER/g
        s/password_here/$WPC8_MYSQL_WORDPRESS_PASSWORD/g
        s/wp_/$WPC8_DATABASE_TABLES_PREFIX/g" $WPC8_SITE_FOLDER/wp-config.php

sed -i "49s/^/#/g
    50s/^/#/g
    51s/^/#/g
    52s/^/#/g
    53s/^/#/g
    54s/^/#/g
    55s/^/#/g
    56s/^/#/g" $WPC8_SITE_FOLDER/wp-config.php

echo -e "\n\n*** FIN, Configurando WP-config.PHP"

#######################################################################################################################################

echo -e "\n\n*** START Adjusting permissions and change file SELinux security context..."
chown -R www-data: $WPC8_SITE_FOLDER/
find $WPC8_SITE_FOLDER -type d -exec chmod 750 {} \;
find $WPC8_SITE_FOLDER -type f -exec chmod 640 {} \;

echo -e "\n\n*** Habilitando Archivo .conf y LOGS en Apache"

touch /etc/apache2/sites-available/${WPC8_SITE_NAME}.conf
mkdir /var/log/apache2/${WPC8_SITE_NAME}
touch /var/log/apache2/${WPC8_SITE_NAME}/${WPC8_SITE_NAME}-access.log
touch /var/log/apache2/${WPC8_SITE_NAME}/${WPC8_SITE_NAME}-error.log

echo "<VirtualHost *:80>
  ServerName ${WPC8_SITE_NAME}${WPC8_SITE_DOMAIN}
  #ServerAlias www.${WPC8_SITE_NAME}${WPC8_SITE_DOMAIN}
  DocumentRoot $WPC8_SITE_FOLDER/
  #DocumentRoot /var/www/${WPC8_SITE_NAME}

    <Directory /var/www/${WPC8_SITE_NAME}>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>

    <Directory /var/www/${WPC8_SITE_NAME}/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>

  ErrorLog /var/log/apache2/${WPC8_SITE_NAME}/${WPC8_SITE_NAME}-error.log
  CustomLog /var/log/apache2/${WPC8_SITE_NAME}/${WPC8_SITE_NAME}-access.log combined
</VirtualHost>" >> /etc/apache2/sites-available/${WPC8_SITE_NAME}.conf

clear
a2ensite ${WPC8_SITE_NAME}
systemctl restart apache2
echo
echo "########################################################"
echo "Nombre base de datos: $WPC8_MYSQL_WORDPRESS_DATABASE "
echo "Nombre usuario Mysql: $WPC8_MYSQL_WORDPRESS_USER "
echo "Contraseña Mysql: $WPC8_MYSQL_WORDPRESS_PASSWORD "
echo "Contraseña ROOT Mysql: $WPC8_MYSQL_ROOT_PASSWORD "
echo "Ruta WordPress: $WPC8_SITE_FOLDER "
echo "Prefijo: $WPC8_DATABASE_TABLES_PREFIX "
echo 
echo 
echo "Debes agregar las claves SALT a tu wp-config.php"
curl https://api.wordpress.org/secret-key/1.1/salt/
