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

echo "$(date +'%H:%M:%S') Redis: backup files ..."               >>$LOGTMP

# files for backup
cat << EOF > /tmp/backup.topic.files
etc/redis/redis.conf
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
tar --create \
    --gzip \
    --file=redis.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') Redis: backup done"                    >>$LOGTMP



echo "$(date +'%H:%M:%S') Redis: add restore commands ..."       >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                            >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
  echo '#'                                           >> $RESTORE_SCRIPT
  echo '# Redis'                                     >> $RESTORE_SCRIPT
  echo '#'                                           >> $RESTORE_SCRIPT
  echo 'echo Restore Redis'                          >> $RESTORE_SCRIPT
  echo 'tar --extract \'                             >> $RESTORE_SCRIPT
  echo '    --gzip \'                                >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                         >> $RESTORE_SCRIPT
  echo '    --file=redis.tar.gz'                     >> $RESTORE_SCRIPT
  echo '# Service'                                   >> $RESTORE_SCRIPT
  echo 'systemctl start \'                           >> $RESTORE_SCRIPT
  echo '          redis-server'                      >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
else
  echo 'echo Restore Redis NOT POSSIBLE'             >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'    >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
