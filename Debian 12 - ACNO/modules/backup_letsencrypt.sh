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

if [ "$ADDON_LETSENCRYPT" == "true" ]; then

  echo "$(date +'%H:%M:%S') Lets Encrypt: backup files ..."        >>$LOGTMP

  # files for backup
  #
  cat << EOF > /tmp/backup.topic.files
etc/letsencrypt
EOF
  cat /tmp/backup.topic.files >> backup.files

  # tar files
  #
  tar --create \
      --gzip \
      --file=letsencrypt.tar.gz \
      --directory=/ \
      --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
  EXIT_CODE+=$?

  echo "$(date +'%H:%M:%S') Lets Encrypt: backup done"             >>$LOGTMP



  echo "$(date +'%H:%M:%S') Lets Encrypt: add restore commands ..."    >>$LOGTMP

  if [ $EXIT_CODE -eq 0 ]; then
    #
    # restore instructions
    #
    echo ''                                            >> $RESTORE_SCRIPT
    echo ''                                            >> $RESTORE_SCRIPT
    echo ''                                            >> $RESTORE_SCRIPT
    echo '#'                                           >> $RESTORE_SCRIPT
    echo '# Lets Encrypt'                              >> $RESTORE_SCRIPT
    echo '#'                                           >> $RESTORE_SCRIPT
    echo 'echo Restore Lets Encrypt'                   >> $RESTORE_SCRIPT
    echo 'tar --extract \'                             >> $RESTORE_SCRIPT
    echo '    --gzip \'                                >> $RESTORE_SCRIPT
    echo '    --dereference \'                         >> $RESTORE_SCRIPT
    echo '    --directory=/ \'                         >> $RESTORE_SCRIPT
    echo '    --file=letsencrypt.tar.gz'               >> $RESTORE_SCRIPT
    echo ''                                            >> $RESTORE_SCRIPT
  else
    echo 'echo Restore Lets Encrypt NOT POSSIBLE'      >> $RESTORE_SCRIPT
    echo 'echo There had been an issue with Backup'    >> $RESTORE_SCRIPT
  fi

fi # only if Let's Encrypt is in use
(exit $EXIT_CODE)
