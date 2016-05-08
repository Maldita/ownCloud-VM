#!/bin/bash
## Tech and Me ## - ©2016, https://www.techandme.se/
# Tested on Ubuntu Server 14.04

#Variables
	SCRIPTS=/var/scripts
	LOGS=/var/scripts/logs # OJO - añadido
	BACKUP=/var/backup # OJO - modificado
	OCPATH=/var/www/owncloud
	DATA=/var/www/owncloud/data # OJO - modificado
	BASE=/var/www # OJO - añadido
	SECURE="$SCRIPTS/setup_secure_permissions_owncloud.sh"
	OCVERSION=8.2.4
	SHARED="https://raw.githubusercontent.com/Maldita/ownCloud-VM/despliegue/8.2/shared" # OJO - modificado
	THEME_NAME=""
	NEW_VERSION="https://download.owncloud.org/community/owncloud-$OCVERSION.tar.bz2"
	FILES_BACKUP=$LOGS/"01-DatosSalvados.log" # OJO - añadido
	FILES_NEW=$LOGS/"02-DatosNuevaVersion.log" # OJO - añadido
	FILES_RESTORE=$LOGS/"03-DatosRestaurados.log" # OJO - añadido
	UPDATE_RESULT=$LOGS/"04-ResultadoActualizacion.log" # OJO - añadido

# Provisional # OJO - añadido apartado
	mkdir $BACKUP
	mkdir $LOGS
	chown -R www-data:root /$BACKUP
	chmod -R 770 $BACKUP

# Must be root
	[[ $(id -u) -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Set secure permissions
	if [ -f $SECURE ];
		then
		        echo "Script exists"
		else
		        mkdir -p $SCRIPTS
		        wget $SHARED/setup_secure_permissions_owncloud.sh -P $SCRIPTS
	fi

# System Upgrade
	apt-get update
	aptitude full-upgrade -y
	clear # OJO - añadido

# Enable maintenance mode
# echo "Manteinance mode ON" # OJO - añadido - Innecesario
	sudo -u www-data php $OCPATH/occ maintenance:mode --on

# Stop Apache # OJO - Añadido todo el apartado
	echo "Stopping Apache server"
	service apache2 stop

# Backup data
	touch $SCRIPTS/DatosCopiados.log # OJO - añadido
	rsync -Aaxv $DATA $BACKUP >> $FILES_BACKUP # OJO - modificado - añadido parámetro "v" para aumentar salida verbose a log
	rsync -Aaxv $OCPATH/config $BACKUP  >> $FILES_BACKUP # OJO - modificado
	rsync -Aaxv $OCPATH/themes $BACKUP >> $FILES_BACKUP # OJO - modificado
	rsync -Aaxv $OCPATH/apps $BACKUP >> $FILES_BACKUP # OJO - modificado
	if [[ $? > 0 ]]
		then
		    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
		    exit
		else
				echo -e "\e[32m"
		    echo "Backup OK!"
		    echo -e "\e[0m"
	fi
	
	# Download new version
		wget $NEW_VERSION -P $BACKUP
		
		if [ -f $BACKUP/owncloud-$OCVERSION.tar.bz2 ];
			then
			        echo "$BACKUP/owncloud-latest.tar.bz2 exists"
			else
			        echo "Aborting,something went wrong with the download"
				exit 1
		fi

	if [ -d $OCPATH/config/ ]; 
		then
		        echo "config/ exists" 
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if config/ folder exist."
		   	exit 1
	fi

	if [ -d $OCPATH/themes/ ]; 
		then
		        echo "themes/ exists" 
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if themes/ folder exist."
		   	exit 1
	fi

	if [ -d $OCPATH/apps/ ]; 
		then
		        echo "apps/ exists" 
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if apps/ folder exist."
		   	exit 1
	fi

	if [ -d $DATA/ ]; 
		then
		        echo "data/ exists" && sleep 2
		        rm -rf $OCPATH
		        tar -xvf $BACKUP/owncloud-$OCVERSION.tar.bz2 -C $BASE >> $FILES_NEW # OJO - modificado en ruta de destino y opciones tar
		        rm $BACKUP/owncloud-$OCVERSION.tar.bz2
		        touch $SCRIPTS/DatosRestaurados.log # OJO - añadido
		        cp -R $BACKUP/themes $OCPATH/  >> $FILES_RESTORE && rm -rf $BACKUP/themes # OJO - modificado 
		        cp -Rv $BACKUP/data $DATA  >> $FILES_RESTORE && rm -rf $BACKUP/data # OJO - modificado 
		        cp -R $BACKUP/config $OCPATH/ >> $FILES_RESTORE  && rm -rf $BACKUP/config # OJO - modificado  
		        # cp -R $BACKUP/apps $OCPATH/  >> $FILES_RESTORE  && rm -rf $BACKUP/apps # OJO - modificado, solo se puede hacer para 3party apps - Importante no tocar
		        bash $SECURE
		        # Start Apache # OJO - Añadido todo el apartado
		        echo "Starting Apache server"
		        service apache2 start
		        # echo "Manteinance mode OFF" # OJO - añadido - Innecesario
		        sudo -u www-data php $OCPATH/occ maintenance:mode --off
		        sudo -u www-data php $OCPATH/occ upgrade
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if data/ folder exist."
		   	exit 1
	fi

# Enable Apps
	#sudo -u www-data php $OCPATH/occ app:enable calendar
	#sudo -u www-data php $OCPATH/occ app:enable contacts
	#sudo -u www-data php $OCPATH/occ app:enable documents
	sudo -u www-data php $OCPATH/occ app:enable external

# Disable maintenance mode
	# sudo -u www-data php $OCPATH/occ maintenance:mode --off #OJO - modificado por aparentemente redundante. Si falla el proceso queda con manteinance activado para evitar problemas si usuarios acceden

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
	touch $UPDATE_RESULT #OJO - modificada ruta
	echo "OWNCLOUD UPDATE success-$(date +"%Y%m%d")" >> $UPDATE_RESULT
	echo ownCloud version:
	sudo -u www-data php $OCPATH/occ status
	sleep 3

# Set secure permissions again
	bash $SECURE

## Un-hash this if you want the system to reboot
	# sudo reboot

exit 0
