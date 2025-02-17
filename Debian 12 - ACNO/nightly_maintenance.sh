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

# Set variables for start date/time & log file
#
START=$(date +'%y%m%d-%H%M')
STARTDATE=$(date +'%y%m%d')
STARTTIME=$(date +'%H%M')
LOGTMP=/tmp/backup_$START.out



#
# Mount Backup device and prepare working directory
#

# unmount if needed
#
if mount | grep "on $MNT_DIR_DEVICE type" > /dev/null; then
  echo "$(date +'%H:%M:%S') Backup Device: already mounted; going to unmount first"    >>$LOGTMP
  echo "$(date +'%H:%M:%S') Backup Device: unmount ..."                                >>$LOGTMP
  umount $MNT_DIR_DEVICE                                                               >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') Backup Device: unmount done"                               >>$LOGTMP
fi

# mount as regular user (group "backup") allows to un-mount later as particular user
#
echo "$(date +'%H:%M:%S') Backup Device: mounting ..."         >>$LOGTMP
sudo --user=$OS_SYS_USER_NAME mount $MNT_DIR_DEVICE            >>$LOGTMP 2>&1
if [ $? -ne 0 ]; then
    echo "$(date +'%H:%M:%S') Backup Device: mount failed"     >>$LOGTMP
    echo "$(date +'%H:%M:%S') Backup Device: lsblk"            >>$LOGTMP
    lsblk                                                      >>$LOGTMP 2>&1

    # Send log file
    source $DIR/modules/send_email.sh $LOGTMP

    exit 1
fi
LOCAL_BACKUP_DEVICE=`findmnt --noheadings --output SOURCE --target $MNT_DIR_DEVICE`
echo "$(date +'%H:%M:%S') Backup Device: mounted $MNT_DIR_DEVICE on $LOCAL_BACKUP_DEVICE"    >>$LOGTMP

# defined standby, if wanted 
#
if [ "$ADDON_HDPARM" == "true" ]; then
  LOCAL_BACKUP_DEVICE=`findmnt --noheadings --output SOURCE --target $MNT_DIR_DEVICE`
  modules/standby_backup_device.sh $ADDON_HDPARM_MINUTES
  if [ $? -eq 0 ]; then
    echo "$(date +'%H:%M:%S') Backup Device: $LOCAL_BACKUP_DEVICE setting standby to $ADDON_HDPARM_MINUTES minutes"       >>$LOGTMP
  else
    echo "$(date +'%H:%M:%S') Backup Device: unable to specify standby for $LOCAL_BACKUP_DEVICE"                          >>$LOGTMP
  fi
fi

# Mount was successful ... do a quick check if the device was intended for the job
#
if [ -f "$MNT_DIR_DEVICE/ACNO-Backup" ]; then
  echo "$(date +'%H:%M:%S') Backup Device: has the marker file ACNO-Backup"         >>$LOGTMP
else
  # keep the temporary log file in /tmp
  echo "$(date +'%H:%M:%S') Backup Device: MISSING marker file ACNO-Backup"         >>$LOGTMP
fi

# Check for existing today directory. 
#   If found, keep it under name today_before_$START.
#
if [ -d "$MNT_DIR_DEVICE/today" ]; then
  echo "$(date +'%H:%M:%S') today Directory: already exists"                    >>$LOGTMP
  mv $MNT_DIR_DEVICE/today $MNT_DIR_DEVICE/today_before_$START                  >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') today Directory: renamed to today_before_$START"    >>$LOGTMP
fi

# Create today directory with read/write for root:backup
#
mkdir --mode=770 $MNT_DIR_DEVICE/today                 >>$LOGTMP 2>&1
chgrp backup $MNT_DIR_DEVICE/today                     >>$LOGTMP 2>&1
echo "$(date +'%H:%M:%S') today Directory: created"    >>$LOGTMP

# Remote Backup: Preparation
#
$DIR/modules/remote_backup.sh prepare

# WebDAV Backup: Preparation
#
$DIR/modules/webdav_backup.sh prepare



# Put Nextcloud into maintenance mode
#
echo "$(date +'%H:%M:%S') Nextcloud: turn Maintenance-Mode ON"    >>$LOGTMP
source $DIR/maintenance.sh on

# Shutdown all services (except PostgreSQL)
source $DIR/modules/services_stop.sh apache2 php8.2-fpm notify_push coturn nginx ds-converter ds-metrics ds-docservice rabbitmq-server redis-server



# Prepare Script for restore
# and create the sctripts/data directory
#
cd $MNT_DIR_DEVICE/today
mkdir --mode=770 --parents scripts/data
chgrp --recursive backup scripts
chmod --recursive 770 scripts
RESTORE_SCRIPT=$MNT_DIR_DEVICE/today/restore.sh
touch $RESTORE_SCRIPT
chmod 770 $RESTORE_SCRIPT



# Prepare restore script
#
echo '#!/bin/bash'                                                                       >> $RESTORE_SCRIPT
echo ''                                                                                  >> $RESTORE_SCRIPT
echo '# allow only owner (root) and group (backup) full access'                          >> $RESTORE_SCRIPT
echo 'umask 007'                                                                         >> $RESTORE_SCRIPT
echo ''                                                                                  >> $RESTORE_SCRIPT
echo '# directory of the other scripts'                                                  >> $RESTORE_SCRIPT
echo 'DIR=$(dirname "$(realpath "$0")")/scripts'                                         >> $RESTORE_SCRIPT
echo ''                                                                                  >> $RESTORE_SCRIPT
echo 'if [ -f $DIR/variables.sh ]; then'                                                 >> $RESTORE_SCRIPT
echo '  echo Set variables, as defined in variables.sh'                                  >> $RESTORE_SCRIPT
echo '  source $DIR/variables.sh'                                                        >> $RESTORE_SCRIPT
echo '  if [ "$NEW_MACHINE" != "yes" ] && [ "$NEW_MACHINE" != "no" ]; then'              >> $RESTORE_SCRIPT
echo '    echo "ERROR: the file(s) data/parameter_value.*.map was/were NOT adjusted"'    >> $RESTORE_SCRIPT
echo '    exit 1'                                                                        >> $RESTORE_SCRIPT
echo '  fi'                                                                              >> $RESTORE_SCRIPT
echo 'else'                                                                              >> $RESTORE_SCRIPT
echo '  echo ERROR: script "$DIR/variables.sh" not found'                                >> $RESTORE_SCRIPT
echo '  exit 1'                                                                          >> $RESTORE_SCRIPT
echo 'fi'                                                                                >> $RESTORE_SCRIPT
echo 'LOCALE_A=`echo "$POSTGRESQL_LOCALES" | sed --expression="s/UTF-/utf/"`'            >> $RESTORE_SCRIPT
echo 'if [ "`locale -a | grep "$LOCALE_A" | wc -l`" == "0" ]; then'                      >> $RESTORE_SCRIPT
echo '  echo ERROR: locales "$POSTGRESQL_LOCALES" are not installed'                     >> $RESTORE_SCRIPT
echo '  echo        Add the missing locale using:  dpkg-reconfigure locales'             >> $RESTORE_SCRIPT
echo '  exit 1'                                                                          >> $RESTORE_SCRIPT
echo 'fi'                                                                                >> $RESTORE_SCRIPT
echo ''                                                                                  >> $RESTORE_SCRIPT
echo 'echo stop all services'                                                            >> $RESTORE_SCRIPT
echo 'if [ "$NEW_MACHINE" == "yes" ]; then'                                              >> $RESTORE_SCRIPT
echo '  echo Note: Apache should be already down'                                        >> $RESTORE_SCRIPT
echo '  echo - FPM-PHP'                                                                  >> $RESTORE_SCRIPT
echo '  systemctl stop \'                                                                >> $RESTORE_SCRIPT
echo '            php8.2-fpm'                                                            >> $RESTORE_SCRIPT
echo 'else'                                                                              >> $RESTORE_SCRIPT
echo '  # No fresh installation'                                                         >> $RESTORE_SCRIPT
echo '  echo - Apache'                                                                   >> $RESTORE_SCRIPT
echo '  systemctl stop \'                                                                >> $RESTORE_SCRIPT
echo '            apache2'                                                               >> $RESTORE_SCRIPT
echo '  echo - FPM-PHP'                                                                  >> $RESTORE_SCRIPT
echo '  systemctl stop \'                                                                >> $RESTORE_SCRIPT
echo '            php8.2-fpm'                                                            >> $RESTORE_SCRIPT
echo '  echo - Nextcloud'                                                                >> $RESTORE_SCRIPT
echo '  systemctl stop \'                                                                >> $RESTORE_SCRIPT
echo '            notify_push'                                                           >> $RESTORE_SCRIPT
echo 'fi'                                                                                >> $RESTORE_SCRIPT
echo 'echo - ONLYOFFICE'                                                                 >> $RESTORE_SCRIPT
echo 'systemctl stop \'                                                                  >> $RESTORE_SCRIPT
echo '          ds-converter \'                                                          >> $RESTORE_SCRIPT
echo '          ds-docservice \'                                                         >> $RESTORE_SCRIPT
echo '          ds-metrics \'                                                            >> $RESTORE_SCRIPT
echo '          nginx \'                                                                 >> $RESTORE_SCRIPT
echo '          rabbitmq-server'                                                         >> $RESTORE_SCRIPT
echo 'echo - coturn'                                                                     >> $RESTORE_SCRIPT
echo 'systemctl stop \'                                                                  >> $RESTORE_SCRIPT
echo '          coturn'                                                                  >> $RESTORE_SCRIPT
echo 'echo - PostgreSQL'                                                                 >> $RESTORE_SCRIPT
echo 'systemctl stop \'                                                                  >> $RESTORE_SCRIPT
echo '          postgresql \'                                                            >> $RESTORE_SCRIPT
echo '          postgresql@15-main'                                                      >> $RESTORE_SCRIPT
echo 'echo - Redis'                                                                      >> $RESTORE_SCRIPT
echo 'systemctl stop \'                                                                  >> $RESTORE_SCRIPT
echo '          redis-server'                                                            >> $RESTORE_SCRIPT
if [ "$ADDON_OPENVPN" == "true" ]; then
  echo 'echo - OpenVPN'                                                                  >> $RESTORE_SCRIPT
  echo 'systemctl stop \'                                                                >> $RESTORE_SCRIPT
  echo '          openvpn-server@server'                                                 >> $RESTORE_SCRIPT
fi # only if OpenVPN is in use
echo ''                                                                                  >> $RESTORE_SCRIPT



#
# Backup Data: Files & Database(s)
#

# remove old stuff
#
rm --force /tmp/backup_not_successfule.lines
rm --force /tmp/backup.temp.files
if [ -f "$MNT_DIR_DEVICE/backup.files" ]; then
  mv $MNT_DIR_DEVICE/backup.files $MNT_DIR_DEVICE/backup.files.BAK-$START
fi

#  Backup data to have it available, just in case it would be needed.
#
source $DIR/modules/backup_logs.sh
EXIT_CODE_LOGS=$?

# Create Backup & Restore script
#
source $DIR/modules/backup_os_basis.sh
if [ $? -ne 0 ]; then
  echo "Basis OS related"                >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_user_root.sh
if [ $? -ne 0 ]; then
  echo "root"                            >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_user_regular.sh
if [ $? -ne 0 ]; then
  echo "regular user"                    >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_os_related.sh
if [ $? -ne 0 ]; then
  echo "OS related"                      >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_letsencrypt.sh
if [ $? -ne 0 ]; then
  echo "Let's Encrypt"                   >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_php.sh
if [ $? -ne 0 ]; then
  echo "PHP"                             >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_redis.sh
if [ $? -ne 0 ]; then
  echo "Redis"                           >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_postgresql.sh
if [ $? -ne 0 ]; then
  echo "PostgreSQL"                      >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_coturn.sh
if [ $? -ne 0 ]; then
  echo "coturn"                          >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_nextcloud.sh
if [ $? -ne 0 ]; then
  echo "Nextcloud"                       >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_apache.sh
if [ $? -ne 0 ]; then
  echo "Apache"                          >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_onlyoffice.sh
if [ $? -ne 0 ]; then
  echo "ONLYOFFICE"                      >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_openvpn.sh
if [ $? -ne 0 ]; then
  echo "OpenVPN"                         >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_lighttp.sh
if [ $? -ne 0 ]; then
  echo "Lighttp"                         >> /tmp/backup_not_successfule.lines
fi
source $DIR/modules/backup_geoblocker.sh
if [ $? -ne 0 ]; then
  echo "GeoBlocker"                      >> /tmp/backup_not_successfule.lines
fi

# Sort remote.files list (with removing duplicates)
#
mv backup.files backup.files.unsorted
sort --unique --output=backup.files backup.files.unsorted



# remote prepare backup
#
$DIR/modules/remote_backup.sh backup



# delete temporary files
#
cat /tmp/backup.temp.files | while read x
do
  rm /$x                                                                                  >>$LOGTMP
done
rm /tmp/backup.temp.files                                                                 >>$LOGTMP



# Shutdown PostgreSQL
#
source $DIR/modules/services_stop.sh postgresql@15-main postgresql



# Remove log files
#
echo "$(date +'%H:%M:%S') log files: remove all ..."            >>$LOGTMP
rm --force /var/log/apache2/* \
           /var/log/nextcloud/* \
           /var/log/nginx/* \
           /var/log/onlyoffice/documentserver/converter/* \
           /var/log/onlyoffice/documentserver/docservice/* \
           /var/log/onlyoffice/documentserver/metrics/* \
           /var/log/php8.2-fpm.log \
           /var/log/postgresql/* \
           /var/log/rabbitmq/* \
           /var/log/redis/* \
           /var/log/turn/*                                      >>$LOGTMP 2>&1



source $DIR/modules/services_start.sh postgresql postgresql@15-main redis-server notify_push rabbitmq-server ds-docservice ds-converter ds-metrics nginx coturn php8.2-fpm apache2



# End the maintenance mode for Nextcloud
echo "$(date +'%H:%M:%S') Nextcloud: turn Maintenance-Mode OFF"       >>$LOGTMP
source $DIR/maintenance.sh off



# WebDAV prepare backup
#
$DIR/modules/webdav_backup.sh backup



# Store Backup on another Server
#
$DIR/modules/remote_backup.sh initiate
sleep 3s
$DIR/modules/webdav_backup.sh initiate
sleep 3s



#
# Create Summary
#

# evaluate relevant the Services
#
LOGTMP=/tmp/summary.txt source $DIR/check_services.sh
echo ""                                                                             >> /tmp/summary.txt

# evaluate Exit Codes of backup_<topic>.sh scripts
#
if [ -f "/tmp/backup_not_successfule.lines" ]; then
  echo "ALERT: not every backup was done ..."                                       >> /tmp/summary.txt
  sed -e "s/^/- /" /tmp/backup_not_successfule.lines                                >> /tmp/summary.txt
else
  echo "Backups OKAY"                                                               >> /tmp/summary.txt
  echo ""                                                                           >> /tmp/summary.txt
fi

# evaluate available Updates
#
LOGTMP=/tmp/summary.txt source $DIR/check_os_updates.sh
echo ""                                                                             >> /tmp/summary.txt

# Predictions of available space for X days 
# (backup size vs. available disk space)
#
DU_OUT=`du --human-readable --block-size=1M --max-depth=0 $MNT_DIR_DEVICE/today`
# sample output:
# 3317	/mnt/backup/250119.bak
aDU_OUT=(${DU_OUT})
declare -i DU_VALUE=${aDU_OUT[0]}
DF_OUT=`df --human-readable --block-size=1M --output=avail $MNT_DIR_DEVICE`
# sample output:
# Avail
# 49950
aDF_OUT=(${DF_OUT})
declare -i DF_VALUE=${aDF_OUT[1]}
echo "Space for additional $((DF_VALUE/DU_VALUE)) backups"                          >> /tmp/summary.txt

# simple du & df output
#
du --human-readable --max-depth=0 $MNT_DIR_DEVICE/today                             >> /tmp/summary.txt
df --human-readable --output=avail,pcent,target $MNT_DIR_DEVICE                     >> /tmp/summary.txt
echo ""                                                                             >> /tmp/summary.txt


cd /root

# Finishing steps of the backup
#
echo "$(date +'%H:%M:%S') directory today becomes $STARTDATE"    >>$LOGTMP
mv $MNT_DIR_DEVICE/today $MNT_DIR_DEVICE/$STARTDATE              >>$LOGTMP 2>&1
cat /tmp/summary.txt $LOGTMP > /tmp/$STARTDATE.log
rm --force /tmp/summary.txt
rm --force $LOGTMP
cp /tmp/$STARTDATE.log $MNT_DIR_DEVICE/$STARTDATE/$STARTTIME-$(date +'%H%M').log

# Send log file
# based on information from the summary, the email might be given a predefined priority
#
if [ -f "/tmp/services_not_listed.lines" ] || [ -f "/tmp/services_not_running.lines" ]; then
  # something with the services ... high Prio
  source $DIR/modules/send_email.sh /tmp/$STARTDATE.log "$SUBJECT_ADMIN_PRIO1"
elif [ -f "/tmp/backup_not_successfule.lines" ]; then
  # something about the backup ... lower Prio
  source $DIR/modules/send_email.sh /tmp/$STARTDATE.log "$SUBJECT_ADMIN_PRIO2"
else
  # all fine ... just FYI
  source $DIR/modules/send_email.sh /tmp/$STARTDATE.log
fi
rm --force /tmp/$STARTDATE.log
