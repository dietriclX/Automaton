#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2files4backup.sh
else
  source $DIR/modules/defaults_2files4backup.sh
fi



# Assuming the script will succeed
EXIT_CODE=0

# # # ^^^^^^ The general part of the Script ^^^^^^  # # #
# # # vvv The topic specific part of the Script vvv # # #

if [ "$ADDON_GEOBLOCKER" == "true" ]; then
  echo "$(date +'%H:%M:%S') GeoBlocker: backup files ..."             >>$LOGTMP

  # files for backup
  #
  if [ "$ADDON_GEOBLOCKER_SOURCE" == "MaxMind" ]; then
    cat << EOF > /tmp/backup.topic.files
etc/GeoIP.conf
usr/share/GeoIP/
var/lib/GeoIP
EOF
  else
    cat << EOF > /tmp/backup.topic.files
EOF
  fi
  cat /tmp/backup.topic.files >> backup.files

  # tar files
  #
  tar --create \
      --gzip \
      --file=geoblocker.tar.gz \
      --directory=/ \
      --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
  EXIT_CODE+=$?
  echo "$(date +'%H:%M:%S') GeoBlocker: backup done"               >>$LOGTMP

  if [ $EXIT_CODE -eq 0 ]; then
    #
    # restore instructions
    #
    echo ''                                                       >> $RESTORE_SCRIPT
    echo ''                                                       >> $RESTORE_SCRIPT
    echo ''                                                       >> $RESTORE_SCRIPT
    echo '#'                                                      >> $RESTORE_SCRIPT
    echo '# GeoBlocker'                                           >> $RESTORE_SCRIPT
    echo '#'                                                      >> $RESTORE_SCRIPT
    echo 'echo Restore GeoBlocker'                                >> $RESTORE_SCRIPT
    echo 'tar --extract \'                                        >> $RESTORE_SCRIPT
    echo '    --gzip \'                                           >> $RESTORE_SCRIPT
    echo '    --dereference \'                                    >> $RESTORE_SCRIPT
    echo '    --directory=/ \'                                    >> $RESTORE_SCRIPT
    echo '    --file=geoblocker.tar.gz'                           >> $RESTORE_SCRIPT
    if [ "$ADDON_GEOBLOCKER_SOURCE" == "MaxMind" ]; then
      echo 'systemctl restart geoipupdate'                        >> $RESTORE_SCRIPT
    fi
    echo ''                                                       >> $RESTORE_SCRIPT
  else
    echo 'echo Restore GeoBlocker NOT POSSIBLE'                   >> $RESTORE_SCRIPT
    echo 'echo There had been an issue with Backup'               >> $RESTORE_SCRIPT
  fi
else
  echo "$(date +'%H:%M:%S') GeoBlocker: skipped"                   >>$LOGTMP
fi # only if OpenVPN is in use
(exit $EXIT_CODE)
