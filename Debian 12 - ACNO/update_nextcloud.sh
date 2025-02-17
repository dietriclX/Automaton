#!/bin/bash

# on newly created files/directories
# allow only owner (root) and group (backup) full access
umask 007

# directory of script
#
DIR=$(dirname "$(realpath "$0")")

# set the variables / script in same directory
#
source $DIR/variables.sh

# Set variables for start date/time
#
START=$(date +'%y%m%d-%H%M')
STARTDATE=$(date +'%y%m%d')
STARTTIME=$(date +'%H%M')



PRINT_HELP=false

if [ $# -ne 2 ]; then
  echo 'ERROR: no argument specified' >&2
  PRINT_HELP=true
elif [ "$1" != "github" ] || [ "$1" == "nextcloud"]; then
  echo 'ERROR: 1. argument is unknown' >&2
  PRINT_HELP=true
fi

if [ "$PRINT_HELP" == "true" ]; then
  # inproper call of script
  cat << EOF 
Usage: $(basename "$0")  SOURCE VERSION
Script will download the specified VERSION from its SOURCE. Once extracted,
the Nextcloud instance will be switched into the Maintenance-Mode and the
update will be applied. At the end the Maintenance-Mode will be truned off.

  SOURCE     the source can be either "github" or "nextcloud". the sources are
             github URL: https://github.com/nextcloud/server/releases
             nextcloud URL: https://download.nextcloud.com/server/releases/
  VERSION    the version number to be downloaded and applied. Version can
             be for example "30.0.6".
EOF
  exit 1
fi

# Remove existing files/directory, needed for the update operation
#
rm --recursive --force /tmp/server
rm --recursive --force /tmp/nextcloud
rm --force             /tmp/nextcloud-$2.zip

cd /tmp

# Download the Update
#
if [ "$1" == "github" ]; then
  # Get the release from GitHub
  #
  git clone \
       --single-branch \
       --recurse-submodules \
       --shallow-submodules \
       --branch=v$2 \
       --depth 1 \
       https://github.com/nextcloud/server.git
  if [ $? -ne 0 ]; then
    echo 'ERROR: unable to correctly download the update of Nextcloud' >&2
    exit 1
  fi
  mv server nextcloud
else
  # Get the release from Nextcloud
  #
  wget https://download.nextcloud.com/server/releases/nextcloud-$2.zip
  unzip nextcloud-$2.zip
  if [ $? -ne 0 ]; then
    echo 'ERROR: unable to correctly download the update of Nextcloud' >&2
    exit 1
  fi
  rm nextcloud-$2.zip
fi

# Add the missing APPS to the next Nextcloud installation
#
cd $NEXTCLOUD_WEB_DIR
cp config/config.php /tmp/nextcloud/config
cd apps
echo Take over Nextcloud Apps
ls --directory * | while read d
do
  if [ ! -d "/tmp/nextcloud/apps/$d" ]; then
    echo $d
    cp --recursive "$d" "/tmp/nextcloud/apps"
  fi
done

cd /tmp

# Correct the ownership of the new Nextcloud installation
# Add the exeecution flag to the notify_push binary
#
chown --recursive --no-dereference www-data:www-data nextcloud
find nextcloud/ -type d -exec chmod 750 {} \;
find nextcloud/ -type f -exec chmod 640 {} \;
chmod 740 nextcloud/apps/notify_push/bin/x86_64/notify_push

# Turn Maintenance-Mode ON
# Shutdown all services
#
source $DIR/maintenance.sh on
if [ "$ADDON_LIGHTTP_503" == "true" ]; then
  systemctl stop php8.2-fpm notify_push coturn nginx ds-converter ds-metrics ds-docservice
else
  systemctl stop apache2 php8.2-fpm notify_push coturn nginx ds-converter ds-metrics ds-docservice
fi

# Create a backup of existing Nextcloud installation.
# Place the downloaded update into the right place.
#
if [ -d "$NEXTCLOUD_WEB_DIR.BAK" ]; then
  mv $NEXTCLOUD_WEB_DIR.BAK $NEXTCLOUD_WEB_DIR.BAK.before.$START
fi
mv $NEXTCLOUD_WEB_DIR $NEXTCLOUD_WEB_DIR.BAK
mv nextcloud $NEXTCLOUD_WEB_DIR

# Execute the upgrade script from Nextcloud
#
sudo --user=www-data php $NEXTCLOUD_WEB_DIR/occ upgrade
if [ $? -ne 0 ]; then
  echo 'ERROR: the upgrade script failed ...' >&2
  exit 1
fi

# Turn Maintenance-Mode OFF
# Start all services
#
if [ "$ADDON_LIGHTTP_503" == "true" ]; then
  systemctl start php8.2-fpm notify_push coturn nginx ds-converter ds-metrics ds-docservice
else
  systemctl start apache2 php8.2-fpm notify_push coturn nginx ds-converter ds-metrics ds-docservice
fi
source $DIR/maintenance.sh on
