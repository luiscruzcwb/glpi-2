#!/bin/bash
#
set -x
# 

SetSubVersion () {
    local _version=$1
    local _index=$2
    local _out=`echo ${_version} | cut -d . -f${_index}`
    return $_out
}

SetPermission () {

    chown -Rf apache:apache /var/www/html/glpi

}

GetCurrentVersion () {

    echo "{ `curl -s http://localhost/glpi/ajax/telemetry.php | grep -v code` }" | jq -r '.glpi.version'

}

Install () {

    echo "Download and install GLPI $VERSION ..."
    
    if [ -e /glpi-$VERSION.tgz ]; then

      tar -zxf /glpi-$VERSION.tgz -C /var/www/html/

    else

      curl --progress-bar -L https://github.com/glpi-project/glpi/releases/download/$VERSION/glpi-$VERSION.tgz | tar -zxf - -C /var/www/html/

    fi

    SetPermission	
}

Upgrade () {
    
    SetSubVersion $VERSION 2

    if [ $? -ge 4 ]; then
      echo "Upgrade to $VERSION using bin/console..."

      /usr/bin/php /var/www/html/glpi/bin/console glpi:database:update --no-interaction

      /usr/bin/php /var/www/html/glpi/bin/console glpi:migration:myisam_to_innod --no-interaction

    else

      echo "Upgrade to $VERSION using cliupdate script..."

      /usr/bin/php /var/www/html/glpi/scripts/cliupdate.php

      /usr/bin/php /var/www/html/glpi/scripts/innodb_migration.php

    fi
}


RemoveInstall () {

    rm -rf /var/www/html/glpi/install/install.php;

}

ConfigDataBase () {

      {
        echo "<?php"; \
        echo "class DB extends DBmysql {"; \
        echo "   public \$dbhost     = \"${MARIADB_HOST}\";"; \
        echo "   public \$dbport     = \"${MARIADB_PORT}\";"; \
        echo "   public \$dbuser     = \"${MARIADB_USER}\";"; \
        echo "   public \$dbpassword = \"${MARIADB_PASSWORD}\";"; \
        echo "   public \$dbdefault  = \"${MARIADB_DATABASE}\";"; \
        echo "}"; \
        echo ; 
      } > /var/www/html/glpi/config/config_db.php

}

DeployDataBase () {

    SetSubVersion $VERSION 2

    if [ $? -ge 4 ]; then

      echo "Deploy DB using bin/console. Please wait..."

      /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install \
	--no-interaction \
	--db-host=${MARIADB_HOST}:${MARIADB_PORT} \
	--db-name=$MARIADB_DATABASE \
	--db-user=$MARIADB_USER \
	--db-password=$MARIADB_PASSWORD \
	--force \
	--default-language=$GLPI_LANG
    else 
      
      echo "Deploy DB using cliinstall.php. Please wait..." 
      
      /usr/bin/php /var/www/html/glpi/scripts/cliinstall.php \
        --host=${MARIADB_HOST} \
        --hostport=${MARIADB_PORT} \
        --db=$MARIADB_DATABASE \
        --user=$MARIADB_USER \
        --pass=$MARIADB_PASSWORD \
        --lang=$GLPI_LANG 
   
    fi

}

PluginModifications() {

	curl --progress-bar -L "https://github.com/stdonato/glpi-modifications/archive/1.4.0.tar.gz" | tar -zxf - -C /var/www/html/glpi/plugins/

	mv /var/www/html/glpi/plugins/glpi-modifications-1.4.0 /var/www/html/glpi/plugins/Mod

	SetPermission

}


PluginTelegramBot() {

	curl --progress-bar -L "https://github.com/pluginsGLPI/telegrambot/releases/download/2.0.0/glpi-telegrambot-2.0.0.tar.bz2" | tar -jxf - -C /var/www/html/glpi/plugins/

	SetPermission

}

PluginPDF() {

	curl --progress-bar -L "https://forge.glpi-project.org/attachments/download/2293/glpi-pdf-1.6.0.tar.gz" | tar -zxf - -C /var/www/html/glpi/plugins/

	SetPermission

}

InstallPlugins() {

	if [ ! -z $PLUGINS ]
	then
		
		LIST=$(echo $PLUGINS | sed "s/,/ /g")

		for i in $LIST
		do

			case $i in

				glpi-modifications)

					PluginModifications

				;;

				glpi-telegrambot)

					PluginTelelgramBot

				;;

				glpi-pdf)

					PluginPDF

				;;

				all)
					PluginModifications
					PluginTelegramBot
					PluginPDF

				;;

				*)
				
					echo "Use: $0 <plugin_name> "
					echo "Available: "
					echo " all (all plugins above)"
					echo " glpi-modifications"
					echo " glpi-telegrambot"
					echo " glpi-pdf"

				;;

			esac	

		done

	fi

}

if [ ! -d /var/www/html/glpi/ ]; then

    echo "Directory not found, go to install..." 

    Install 

    if [ $? -ne 0 ]; then

      echo "fail"

      exit 2

    fi

fi

if [ -e /var/www/html/glpi/config/config_db.php ]; then

    echo "DB Already installed. " 

    ConfigDataBase

    CURRENTVERSION=$(GetCurrentVersion)

    if [ -n $CURRENTVERSION ] && [ $CURRENTVERSION != $VERSION ]; then

        Install

        Upgrade

    fi

else

    sleep 5

    DeployDataBase

    ConfigDataBase

fi
#
#
InstallPlugins
#
#
SetPermission
#
#
RemoveInstall
#
# httpd -D FOREGROUND
#
GetCurrentVersion
