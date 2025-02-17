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

if [ "$ADDON_LIGHTTP_503" == "true" ]; then
  # Only if Add-On is enabled

  echo "$(date +'%H:%M:%S') Lighttp: backup files ..."             >>$LOGTMP

  # files for backup
  #
  cat << EOF > /tmp/backup.topic.files
etc/lighttpd/Error503.html
etc/lighttpd/Error503.lua
etc/lighttpd/lighttpd.conf
etc/lighttpd/lighttpd.conf.ORG
etc/lighttpd/lighttpd_include.conf
etc/lighttpd/lighttpd_include.sh
EOF
  cat /tmp/backup.topic.files >> backup.files

  # tar files
  #
  tar --create \
      --gzip \
      --file=lighttp.tar.gz \
      --directory=/ \
      --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
  EXIT_CODE+=$?

  echo "$(date +'%H:%M:%S') Lighttp: backup done"                  >>$LOGTMP


  
  echo "$(date +'%H:%M:%S') Lighttp: add restore commands ..."     >>$LOGTMP

  if [ $EXIT_CODE -eq 0 ]; then
    #
    # restore instructions
    #
    echo ''                                                                        >> $RESTORE_SCRIPT
    echo ''                                                                        >> $RESTORE_SCRIPT
    echo ''                                                                        >> $RESTORE_SCRIPT
    echo '#'                                                                       >> $RESTORE_SCRIPT
    echo '# Lighttp'                                                               >> $RESTORE_SCRIPT
    echo '#'                                                                       >> $RESTORE_SCRIPT
    echo 'echo Restore Lighttp'                                                    >> $RESTORE_SCRIPT
    echo 'cp /etc/lighttpd/lighttpd.conf etc/lighttpd/lighttpd.conf.BAK-$START'    >> $RESTORE_SCRIPT
    echo 'tar --extract \'                                                         >> $RESTORE_SCRIPT
    echo '    --gzip \'                                                            >> $RESTORE_SCRIPT
    echo '    --dereference \'                                                     >> $RESTORE_SCRIPT
    echo '    --directory=/ \'                                                     >> $RESTORE_SCRIPT
    echo '    --file=lighttp.tar.gz'                                               >> $RESTORE_SCRIPT
    echo '# Service'                                                               >> $RESTORE_SCRIPT
    echo 'systemctl stop \'                                                        >> $RESTORE_SCRIPT
    echo '          lighttp'                                                       >> $RESTORE_SCRIPT
    echo 'systemctl disable \'                                                     >> $RESTORE_SCRIPT
    echo '          lighttp'                                                       >> $RESTORE_SCRIPT
    echo ''                                                                        >> $RESTORE_SCRIPT
  else
    echo 'echo Restore Lighttp NOT POSSIBLE'                                       >> $RESTORE_SCRIPT
    echo 'echo There had been an issue with Backup'                                >> $RESTORE_SCRIPT
  fi
fi
(exit $EXIT_CODE)
