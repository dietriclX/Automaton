#!/bin/bash

# on newly created files/directories
# allow only owner (root) and group (backup) full access
umask 007

# directory of script
DIR=$(dirname "$(realpath "$0")")

if [ -f $DIR/variables.sh ]; then
  echo Set variables, as defined in variables.sh
  source $DIR/variables.sh
  if [ "$NEW_MACHINE" != "yes" ] && [ "$NEW_MACHINE" != "no" ]; then
    echo "ERROR: the file(s) data/parameter_value.*.map was/were NOT adjusted"
    exit 1
  fi
else
  echo ERROR: script "$DIR/variables.sh" not found
  echo 1. ensure your 'parameter_value.*.map' file\(s\) are up-to-date
  echo 2. run $DIR/apply.sh OPTIONS $DIR/data/variables.ORG.sh $DIR/variables.sh
  exit 1
fi

# Set variables for start date/time & log file
#
START=$(date +'%y%m%d-%H%M')
SCRIPTNAME=$(basename "$0")
SCRIPTNAME=${SCRIPTNAME%.*}
LOGTMP=/tmp/$SCRIPTNAME-$START.out
rm --force $LOGTMP


# Check for available locales
#
echo "PostgreSQL: locale for databases = $POSTGRESQL_LOCALES"                     | tee --append $LOGTMP
echo "Locales: check for availability"                                            | tee --append $LOGTMP
locale -a                                                                         | tee --append $LOGTMP
LOCALE_A=`echo "$POSTGRESQL_LOCALES" | sed --expression="s/UTF-/utf/"`
if [ "`locale -a | grep "$LOCALE_A" | wc -l`" == "0" ]; then
  echo ERROR: locales "$POSTGRESQL_LOCALES" are not installed
  echo        Add the missing locale using:  dpkg-reconfigure locales
  exit 1
fi



#
# At the end, the Apache Web-Server is not running. But on the other hand, nginx is running.
#

#
# avoid questions during software installation
#
cat << EOF > /tmp/preset.install.apt
iptables-persistent iptables-persistent/autosave_v4 boolean false
iptables-persistent iptables-persistent/autosave_v6 boolean false
onlyoffice-documentserver onlyoffice/db-host string $ONLYOFFICE_DB_HOST
onlyoffice-documentserver onlyoffice/db-user string $ONLYOFFICE_DB_USER
onlyoffice-documentserver onlyoffice/db-pwd password $ONLYOFFICE_DB_USER_PASSWORD
onlyoffice-documentserver onlyoffice/db-name string $ONLYOFFICE_DB_NAME
msmtp msmtp/apparmor boolean true
EOF
debconf-set-selections /tmp/preset.install.apt    2>>$LOGTMP | tee --append $LOGTMP
rm /tmp/preset.install.apt                        2>>$LOGTMP | tee --append $LOGTMP



#
# Password file for PostgreSQL
#
echo "PostgreSQL: grant access to all databases"                                  | tee --append $LOGTMP
touch ~/.pgpass                                                        2>>$LOGTMP | tee --append $LOGTMP
chmod 600 ~/.pgpass                                                    2>>$LOGTMP | tee --append $LOGTMP
cat << EOF >> ~/.pgpass
$POSTGRESQL_HOST:$POSTGRESQL_PORT:$POSTGRESQL_ADM:$POSTGRESQL_ADM_PASSWORD
$COTURN_DB_HOST:$COTURN_DB_PORT:$COTURN_DB_NAME:$COTURN_DB_USER:$COTURN_DB_USER_PASSWORD
$NEXTCLOUD_DB_HOST:$NEXTCLOUD_DB_PORT:$NEXTCLOUD_DB_NAME:$NEXTCLOUD_DB_USER:$NEXTCLOUD_DB_USER_PASSWORD
$ONLYOFFICE_DB_HOST:$ONLYOFFICE_DB_PORT:$ONLYOFFICE_DB_NAME:$ONLYOFFICE_DB_USER:$ONLYOFFICE_DB_USER_PASSWORD
EOF



#
# Create SQL-Script files for adjusting PostgreSQL and creating application databases.
#

# PostgreSQL
cat << EOF > $DIR/data/prepare_postgresql.sql
ALTER USER postgres WITH PASSWORD '$POSTGRESQL_ADM_PASSWORD'
EOF
chgrp backup $DIR/data/prepare_postgresql.sql    2>>$LOGTMP | tee --append $LOGTMP

# coturn
cat << EOF > $DIR/data/prepare_coturn.sql
CREATE USER $COTURN_DB_USER WITH PASSWORD '$COTURN_DB_USER_PASSWORD';
EOF
chgrp backup $DIR/data/prepare_coturn.sql        2>>$LOGTMP | tee --append $LOGTMP

# Nextcloud
cat << EOF > $DIR/data/prepare_nextcloud.sql
CREATE USER $NEXTCLOUD_DB_USER WITH PASSWORD '$NEXTCLOUD_DB_USER_PASSWORD';
EOF
chgrp backup $DIR/data/prepare_nextcloud.sql     2>>$LOGTMP | tee --append $LOGTMP

# ONLYOFFICE
cat << EOF > $DIR/data/prepare_onlyoffice.sql
CREATE USER $ONLYOFFICE_DB_USER WITH PASSWORD '$ONLYOFFICE_DB_USER_PASSWORD';
CREATE DATABASE $ONLYOFFICE_DB_NAME TEMPLATE template0 OWNER $ONLYOFFICE_DB_USER LC_COLLATE '$POSTGRESQL_LOCALES' LC_CTYPE '$POSTGRESQL_LOCALES';
GRANT ALL privileges ON DATABASE $ONLYOFFICE_DB_NAME TO $ONLYOFFICE_DB_USER;
EOF
chgrp backup $DIR/data/prepare_onlyoffice.sql    2>>$LOGTMP | tee --append $LOGTMP
tar --extract --gzip --file=onlyoffice.sql.tar.gz onlyoffice_schema.sql


#
# Install basic software packages, including PostgreSQL
#
echo "Install curl git gpg postgresql sudo unzip"                                           | tee --append $LOGTMP
apt install --yes curl git gpg postgresql sudo unzip                             2>>$LOGTMP | tee --append $LOGTMP

# postgres becomes part of group backup
usermod --append --groups backup postgres                                        2>>$LOGTMP | tee --append $LOGTMP

# change the authentication via Unix-Sockets from "peer" to "md5"
sed -i -e "s/\(^local[[:space:]]*all[[:space:]]*all[[:space:]]*\)peer/\1md5/" /etc/postgresql/15/main/pg_hba.conf

# PostgreSQL to be reloaded, to take previous changes into account
systemctl reload postgresql



#
# Adjust Postgresql and Preapre the Database(s).
#

# Set postgres password
echo "PostgreSQL: prepare DBMS system e.g. set password"                                    | tee --append $LOGTMP
sudo --user=postgres psql -f $DIR/data/prepare_postgresql.sql                    2>>$LOGTMP | tee --append $LOGTMP

# coturn
echo "coturn: prepare database"                                                             | tee --append $LOGTMP
if [ "$POSTGRESQL_HOST" == "localhost" ]; then
  sudo --user=postgres psql --file=$DIR/data/prepare_coturn.sql                  2>>$LOGTMP | tee --append $LOGTMP
else
  sudo --user=postgres psql --host=$COTURN_DB_HOST \
                            --port=$COTURN_DB_PORT \
                            --username=$POSTGRESQL_ADM \
                            --file=$DIR/data/prepare_coturn.sql                  2>>$LOGTMP | tee --append $LOGTMP
fi

# Nextcloud
echo "Nextcloud: prepare database"                                                          | tee --append $LOGTMP
if [ "$POSTGRESQL_HOST" == "localhost" ]; then
  sudo --user=postgres psql --file=$DIR/data/prepare_nextcloud.sql               2>>$LOGTMP | tee --append $LOGTMP
else
  sudo --user=postgres psql --host=$NEXTCLOUD_DB_HOST \
                            --port=$NEXTCLOUD_DB_PORT \
                            --username=$POSTGRESQL_ADM \
                            --file=$DIR/data/prepare_nextcloud.sql               2>>$LOGTMP | tee --append $LOGTMP
fi

# ONLYOFFICE
echo "ONLYOFFICE: prepare database"                                                         | tee --append $LOGTMP
if [ "$POSTGRESQL_HOST" == "localhost" ]; then
  sudo --user=postgres psql --file=$DIR/data/prepare_onlyoffice.sql              2>>$LOGTMP | tee --append $LOGTMP
  sudo --user=postgres psql --dbname=$ONLYOFFICE_DB_NAME \
                            --file=onlyoffice_schema.sql                         2>>$LOGTMP | tee --append $LOGTMP
else
  sudo --user=postgres psql --host=$COTURN_DB_HOST \
                            --port=$COTURN_DB_PORT \
                            --username=$POSTGRESQL_ADM \
                            --file=$DIR/data/prepare_onlyoffice.sql              2>>$LOGTMP | tee --append $LOGTMP
  sudo --user=postgres psql --host=$COTURN_DB_HOST \
                            --port=$COTURN_DB_PORT \
                            --username=$POSTGRESQL_ADM \
                            --dbname=$ONLYOFFICE_DB_NAME \
                            --file=onlyoffice_schema.sql                         2>>$LOGTMP | tee --append $LOGTMP
fi
rm onlyoffice_schema.sql                                                         2>>$LOGTMP | tee --append $LOGTMP



#
# Prepare the Package Respository, to include contrib, non-free and ONLYOFFICE
#

# add contrib and non-free
if [ -f "/etc/apt/sources.list.ORG" ]; then
  echo "There is already a backup of /etc/apt/sources.list."                                | tee --append $LOGTMP
else 
  echo "Make a backup of  /etc/apt/sources.list."                                           | tee --append $LOGTMP
  cp /etc/apt/sources.list /etc/apt/sources.list.ORG
fi
sed --in-place 's/main non-free-firmware/main contrib non-free non-free-firmware/g' /etc/apt/sources.list

# add ONLYOFFICE
echo "ONLYOFFICE: Add to Repository list"                                                   | tee --append $LOGTMP
mkdir -p -m 700 /root/.gnupg
curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --no-default-keyring --keyring gnupg-ring:/tmp/onlyoffice.gpg --import
chmod 644 /tmp/onlyoffice.gpg
mv /tmp/onlyoffice.gpg /usr/share/keyrings/onlyoffice.gpg
echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list

# get package inventory up-to-date
apt update



#
# Install all the other software packages.
#

# Shutdown Apache Web-Server, as onlyoffice is going to install nginx
echo "Apache: Stop Service"         1                                                       | tee --append $LOGTMP
systemctl stop apache2                                                           2>>$LOGTMP | tee --append $LOGTMP

# the must have ...
echo "Install all the must have ..."                                                        | tee --append $LOGTMP
apt install --yes \
            ffmpeg imagemagick libapache2-mod-php php php-apcu php-bcmath \
            php-bz2 php-cli php-common php-curl php-dev php-dompdf php-fpm \
            php-gd php-gmp php-imagick php-intl php-json php-mbstring \
            php-pear php-pgsql php-redis php-soap php-xml php-zip redis \
            ttf-mscorefonts-installer rabbitmq-server coturn                     2>>$LOGTMP | tee --append $LOGTMP

# moved the installation of ONLYOFFICE to the end ... 
# I had too much with this package ...

# Add-On: Lighttp for Maintenance
if [ "$ADDON_LIGHTTP_503" == "true" ]; then
  echo "Add-On: Lighttp for Maintenance"                                                    | tee --append $LOGTMP
  apt install --yes lighttpd lighttpd-mod-magnet                                 2>>$LOGTMP | tee --append $LOGTMP
  systemctl stop lighttpd                                                        2>>$LOGTMP | tee --append $LOGTMP
fi

# Add-On: Email for root
if [ "$ADDON_ROOT_EMAIL_SEND" == "true" ]; then
  echo "Add-On: Email for root"                                                             | tee --append $LOGTMP
  apt install --yes msmtp msmtp-mta mailutils                                    2>>$LOGTMP | tee --append $LOGTMP
fi

# Add-On: GeoBlocker
if [ "$ADDON_GEOBLOCKER" == "true" ]; then
  echo "Add-On: GeoBlocker"                                                                 | tee --append $LOGTMP
  if [ "$ADDON_GEOBLOCKER_SOURCE" == "MaxMind" ]; then
    echo "        IPs from MaxMind"                                                         | tee --append $LOGTMP
    apt install --yes geoipupdate                                                2>>$LOGTMP | tee --append $LOGTMP
  fi
fi

# Add-On: Let's Encrypt
if [ "$ADDON_LETSENCRYPT" == "true" ]; then
  echo "Add-On: Let's Encrypt"                                                              | tee --append $LOGTMP
  apt install --yes certbot python3-certbot-apache                               2>>$LOGTMP | tee --append $LOGTMP
fi

# Add-On: OpenVPN
if [ "$ADDON_OPENVPN" == "true" ]; then
  echo "Add-On: OpenVPN"                                                                    | tee --append $LOGTMP
  apt install --yes openvpn iptables netfilter-persistent iptables-persistent    2>>$LOGTMP | tee --append $LOGTMP
fi

# Add-On: HDD - idle => power off
if [ "$ADDON_HDPARM" == "true" ]; then
  echo "Add-On: hdparm"                                                                     | tee --append $LOGTMP
  apt install --yes hdparm
fi

# Add-On: S.M.A.R.T.
if [ "$ADDON_SMART" == "true" ]; then
  echo "Add-On: S.M.A.R.T."                                                                 | tee --append $LOGTMP
  apt install --yes smartmontools                                                2>>$LOGTMP | tee --append $LOGTMP
fi

# some of the installed packages got the service started
# stopped for nginx installation, as part of ONLYOFFICE
systemctl stop apache2

if [ -f "$MNT_DIR_DEVICE/onlyoffice/onlyoffice-documentserver.file" ]; then
  echo "ONLYOFFICE: install from saved .deb file"                                           | tee --append $LOGTMP
  sFileName=`cat $MNT_DIR_DEVICE/onlyoffice/onlyoffice-documentserver.file`
  apt install --yes $MNT_DIR_DEVICE/onlyoffice/$sFileName                        2>>$LOGTMP | tee --append $LOGTMP
else
  echo "ONLYOFFICE: install from repository"                                                | tee --append $LOGTMP
  apt install --yes onlyoffice-documentserver                                    2>>$LOGTMP | tee --append $LOGTMP
fi

# DocumentServer (ds) becomes part of group postgres redis
usermod --append --groups postgres,redis ds                                      2>>$LOGTMP | tee --append $LOGTMP
