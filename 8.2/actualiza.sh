#!/bin/bash
#
## Tech and Me ## - ©2016, https://www.techandme.se/
#
# Tested on Ubuntu Server 14.04.
#
SCRIPTS=/var/scripts
HTML=/var/backup # OJO - modificado
OCPATH=/var/www/owncloud
DATA=/var/www/owncloud/data # OJO - modificado
BASE=/var/www # OJO - añadido
SECURE="$SCRIPTS/setup_secure_permissions_owncloud.sh"
OCVERSION=8.2.4
STATIC="https://raw.githubusercontent.com/Maldita/ownCloud-VM/master/static"
THEME_NAME=""

# Provisional
mkdir /var/backup
chown -R www-data:www-data /var/backup
chmod -R 777 /var/backup

# Must be root
[[ $(id -u) -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Set secure permissions
if [ -f $SECURE ];
then
        echo "Script exists"
else
        mkdir -p $SCRIPTS
        wget $STATIC/setup_secure_permissions_owncloud.sh -P $SCRIPTS
fi

# System Upgrade
apt-get update
aptitude full-upgrade -y

# Enable maintenance mode
sudo -u www-data php $OCPATH/occ maintenance:mode --on

# Stop Apache # OJO - Añadido todo el apartado
echo "Stopping Apache server"
service apache2 stop

# Backup data
touch $SCRIPTS/DatosCopiados.log # OJO - añadido
rsync -Aaxv $DATA $HTML >> $SCRIPTS/DatosCopiados.log # OJO - modificado 
rsync -Aax $OCPATH/config $HTML  >> $SCRIPTS/DatosCopiados.log # OJO - modificado
rsync -Aax $OCPATH/themes $HTML >> $SCRIPTS/DatosCopiados.log # OJO - modificado
rsync -Aax $OCPATH/apps $HTML >> $SCRIPTS/DatosCopiados.log # OJO - modificado
if [[ $? > 0 ]]
then
    echo "Backup was not OK. Please check $HTML and see if the folders are backed up properly"
    exit
else
		echo -e "\e[32m"
    echo "Backup OK!"
    echo -e "\e[0m"
fi
wget https://download.owncloud.org/community/owncloud-$OCVERSION.tar.bz2 -P $HTML

if [ -f $HTML/owncloud-$OCVERSION.tar.bz2 ];
then
        echo "$HTML/owncloud-latest.tar.bz2 exists"
else
        echo "Aborting,something went wrong with the download"
   exit 1
fi

if [ -d $OCPATH/config/ ]; then
        echo "config/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if config/ folder exist."
   exit 1
fi

if [ -d $OCPATH/themes/ ]; then
        echo "themes/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if themes/ folder exist."
   exit 1
fi

if [ -d $OCPATH/apps/ ]; then
        echo "apps/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if apps/ folder exist."
   exit 1
fi

if [ -d $DATA/ ]; then
        echo "data/ exists" && sleep 2
        rm -rf $OCPATH
        tar -xvf $HTML/owncloud-$OCVERSION.tar.bz2 -C $BASE # OJO - modificado en ruta de destino y opciones tar
        rm $HTML/owncloud-$OCVERSION.tar.bz2
        touch $SCRIPTS/DatosRestaurados.log # OJO - añadido
        cp -R $HTML/themes $OCPATH/ && rm -rf $HTML/themes >> $SCRIPTS/DatosRestaurados.log # OJO - modificado 
        cp -Rv $HTML/data $DATA && rm -rf $HTML/data >> $SCRIPTS/DatosRestaurados.log # OJO - modificado 
        cp -R $HTML/config $OCPATH/ && rm -rf $HTML/config >> $SCRIPTS/DatosRestaurados.log # OJO - modificado  
        # cp -R $HTML/apps $OCPATH/ && rm -rf $HTML/apps # OJO - modificado, solo se puede hacer para 3party apps - Importante no tocar
        bash $SECURE
        # Start Apache # OJO - Añadido todo el apartado
        echo "Starting Apache server"
        service apache2 start
        sudo -u www-data php $OCPATH/occ maintenance:mode --off
        sudo -u www-data php $OCPATH/occ upgrade
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ folder exist."
   exit 1
fi

# Enable Apps
#sudo -u www-data php $OCPATH/occ app:enable calendar
#sudo -u www-data php $OCPATH/occ app:enable contacts
#sudo -u www-data php $OCPATH/occ app:enable documents
sudo -u www-data php $OCPATH/occ app:enable external

# Disable maintenance mode
# sudo -u www-data php $OCPATH/occ maintenance:mode --off #OJO - modificado por aparentemente redundante

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 1000M"
if grep -Fxq "$VALUE" $OCPATH/.htaccess
then
        echo "Upload value correct"
else
        sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 1000M/g' $OCPATH/.htaccess
        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 1000M/g' $OCPATH/.htaccess
        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 1000M/g' $OCPATH/.htaccess
fi

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if grep -Fxq "$VALUE2" $OCPATH/config/config.php
then
        echo "Theme correct"
else
        sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $OCPATH/config/config.php
        echo "Theme set"
fi

# Repair
sudo -u www-data php $OCPATH/occ maintenance:repair

# Cleanup un-used packages
sudo apt-get autoremove -y
sudo apt-get autoclean

# Update GRUB, just in case
sudo update-grub

# Write to log
touch /$SCRIPTS/cronjobs_success.log #OJO - modificada ruta
echo "OWNCLOUD UPDATE success-$(date +"%Y%m%d")" >> /var/log/cronjobs_success.log
echo
echo ownCloud version:
sudo -u www-data php $OCPATH/occ status
echo
echo
sleep 3

# Set secure permissions again
bash $SECURE

## Un-hash this if you want the system to reboot
# sudo reboot

exit 0
