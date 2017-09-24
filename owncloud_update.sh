#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && MYCNFPW=1 && NC_UPDATE=1 . <(curl -sL https://raw.githubusercontent.com/techandme/owncloud-vm/master/lib.sh)
unset NC_UPDATE
unset MYCNFPW
unset NCDB

# Tech and Me © - 2017, https://www.techandme.se/

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Put your theme name here:
THEME_NAME=""

# Must be root
if ! is_root
then
    echo "Must be root to run script, in Ubuntu type: sudo -i"
    exit 1
fi

# Check if dpkg or apt is running
is_process_running dpkg
is_process_running apt

# System Upgrade
apt update -q4 & spinner_loading
export DEBIAN_FRONTEND=noninteractive ; apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Update Redis PHP extention
if type pecl > /dev/null 2>&1
then
    install_if_not php7.0-dev
    echo "Trying to upgrade the Redis Pecl extenstion..."
    pecl upgrade redis
    service apache2 restart
fi

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

# Remove update lists
rm /var/lib/apt/lists/* -r

# Set secure permissions
if [ ! -f "$SECURE" ]
then
    mkdir -p "$SCRIPTS"
    download_static_script setup_secure_permissions_owncloud
    chmod +x "$SECURE"
fi

# Major versions unsupported
if [ "${CURRENTVERSION%%.*}" == "$NCBAD" ]
then
    echo
    echo "Please note that updates between multiple major versions are unsupported! Your situation is:"
    echo "Current version: $CURRENTVERSION"
    echo "Latest release: $NCVERSION"
    echo
    echo "It is best to keep your ownCloud server upgraded regularly, and to install all point releases"
    echo "and major releases without skipping any of them, as skipping releases increases the risk of"
    echo "errors. Major releases are 9, 10, 11 and 12. Point releases are intermediate releases for each"
    echo "major release. For example, 9.0.52 and 10.0.2 are point releases."
    echo
    echo "Please contact Tech and Me to help you with upgrading between major versions."
    echo "https://shop.techandme.se/index.php/product-category/support/"
    echo
    exit 1
fi

# Check if new version is larger than current version installed.
if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    echo "Latest release is: $NCVERSION. Current version is: $CURRENTVERSION."
    printf "${Green}New version available! Upgrade continues...${Color_Off}\n"
else
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "No need to upgrade, this script will exit..."
    exit 0
fi

# Make sure old instaces can upgrade as well
if [ ! -f "$MYCNF" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(cat /var/mysql_password.txt)
cat << LOGIN > "$MYCNF"
[client]
password='$regressionpw'
LOGIN
    chmod 0600 $MYCNF
    chown root:root $MYCNF
    echo "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1    
elif [ -z "$MARIADBMYCNFPASS" ] && [ -f /var/mysql_password.txt ]
then
    regressionpw=$(cat /var/mysql_password.txt)
    {
    echo "[client]"
    echo "password='$regressionpw'"
    } >> "$MYCNF"
    echo "Please restart the upgrade process, we fixed the password file $MYCNF."
    exit 1    
fi

if [ -z "$MARIADBMYCNFPASS" ]
then
    echo "Something went wrong with copying your mysql password to $MYCNF."
    echo "We wrote a guide on how to fix this. You can find the guide here:"
    echo "https://www.techandme.se/reset-mysql-5-7-root-password/"
    exit 1
else
    rm -f /var/mysql_password.txt
fi

# Upgrade ownCloud
echo "Checking latest released version on the ownCloud download server and if it's possible to download..."
if ! wget -q --show-progress -T 10 -t 2 "$ocdownloadrepo/$STABLEVERSION.tar.bz2"
then
    echo
    printf "${IRed}ownCloud %s doesn't exist.${Color_Off}\n" "$NCVERSION"
    echo "Please check available versions here: $NCREPO"
    echo
    exit 1
else
    rm -f "$STABLEVERSION.tar.bz2"
fi

echo "Backing up files and upgrading to ownCloud $NCVERSION in 10 seconds..."
echo "Press CTRL+C to abort."
sleep 10

# Check if backup exists and move to old
echo "Backing up data..."
DATE=$(date +%Y-%m-%d-%H%M%S)
if [ -d $BACKUP ]
then
    mkdir -p "/var/NCBACKUP_OLD/$DATE"
    mv $BACKUP/* "/var/NCBACKUP_OLD/$DATE"
    rm -R $BACKUP
    mkdir -p $BACKUP
fi

# Backup data
for folders in config themes apps
do
    if [[ "$(rsync -Aax $NCPATH/$folders $BACKUP)" -eq 0 ]]
    then
        BACKUP_OK=1
    else
        unset BACKUP_OK
    fi
done

if [ -z $BACKUP_OK ]
then
    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
    exit 1
else
    printf "${Green}\nBackup OK!${Color_Off}\n"
fi

# Backup MARIADB
if mysql -u root -p"$MARIADBMYCNFPASS" -e "SHOW DATABASES LIKE '$NCCONFIGDB'" > /dev/null
then
    echo "Doing mysqldump of $NCCONFIGDB..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d "$NCCONFIGDB" > "$BACKUP"/ownclouddb.sql
else
    echo "Doing mysqldump of all databases..."
    check_command mysqldump -u root -p"$MARIADBMYCNFPASS" -d --all-databases > "$BACKUP"/alldatabases.sql
fi

# Download and validate ownCloud package
check_command download_verify_owncloud_stable

if [ -f "$HTML/$STABLEVERSION.tar.bz2" ]
then
    echo "$HTML/$STABLEVERSION.tar.bz2 exists"
else
    echo "Aborting,something went wrong with the download"
    exit 1
fi

if [ -d $BACKUP/config/ ]
then
    echo "$BACKUP/config/ exists"
else
    echo "Something went wrong with backing up your old owncloud instance, please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d $BACKUP/apps/ ]
then
    echo "$BACKUP/apps/ exists"
else
    echo "Something went wrong with backing up your old owncloud instance, please check in $BACKUP if apps/ folder exist."
    exit 1
fi

if [ -d $BACKUP/themes/ ]
then
    echo "$BACKUP/themes/ exists"
    echo 
    printf "${Green}All files are backed up.${Color_Off}\n"
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --on
    echo "Removing old ownCloud instance in 5 seconds..." && sleep 5
    rm -rf $NCPATH
    tar -xjf "$HTML/$STABLEVERSION.tar.bz2" -C "$HTML"
    rm "$HTML/$STABLEVERSION.tar.bz2"
    cp -R $BACKUP/themes "$NCPATH"/
    cp -R $BACKUP/config "$NCPATH"/
    bash $SECURE & spinner_loading
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    sudo -u www-data php "$NCPATH"/occ upgrade --no-app-disable
else
    echo "Something went wrong with backing up your old owncloud instance, please check in $BACKUP if the folders exist."
    exit 1
fi

# Recover apps that exists in the backed up apps folder
# run_static_script recover_apps

# Enable Apps
if [ -d "$SNAPDIR" ]
then
    run_app_script spreedme
fi

# Change owner of $BACKUP folder to root
chown -R root:root "$BACKUP"

# Set max upload in ownCloud .htaccess
configure_max_upload

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if ! grep -Fxq "$VALUE2" "$NCPATH/config/config.php"
then
    sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" "$NCPATH"/config/config.php
    echo "Theme set"
fi

# Pretty URLs
echo "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data "$NCPATH"
sudo -u www-data php "$NCPATH"/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php "$NCPATH"/occ maintenance:update:htaccess
bash "$SECURE"

# Repair
sudo -u www-data php "$NCPATH"/occ maintenance:repair

CURRENTVERSION_after=$(sudo -u www-data php "$NCPATH"/occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    echo "UPGRADE SUCCESS!"
    echo "OWNCLOUD UPDATE success-$(date +"%Y%m%d")" >> /var/log/cronjobs_success.log
    sudo -u www-data php "$NCPATH"/occ status
    sudo -u www-data php "$NCPATH"/occ maintenance:mode --off
    echo
    echo "If you notice that some apps are disabled it's due to that they are not compatible with the new ownCloud version."
    echo "To recover your old apps, please check $BACKUP/apps and copy them to $NCPATH/apps manually."
    echo
    echo "Thank you for using Tech and Me's updater!"
    ## Un-hash this if you want the system to reboot
    # reboot
    exit 0
else
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    sudo -u www-data php "$NCPATH"/occ status
    echo "UPGRADE FAILED!"
    echo "Your files are still backed up at $BACKUP. No worries!"
    echo "Please report this issue to $ISSUES"
    exit 1
fi