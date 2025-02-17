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

echo "$(date +'%H:%M:%S') user: backup ..."                      >>$LOGTMP

# files for backup
cat << EOF > /tmp/backup.topic.files
home/$OS_SYS_USER_NAME/.ssh
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
tar --create \
    --gzip \
    --file=user.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') user: backup done"                     >>$LOGTMP



echo "$(date +'%H:%M:%S') user: add restore commands ..."    >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                            >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
  echo '#'                                           >> $RESTORE_SCRIPT
  echo '# User regular'                              >> $RESTORE_SCRIPT
  echo '#'                                           >> $RESTORE_SCRIPT
  echo 'echo Restore user'                           >> $RESTORE_SCRIPT
  echo 'tar --extract \'                             >> $RESTORE_SCRIPT
  echo '    --gzip \'                                >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                         >> $RESTORE_SCRIPT
  echo '    --file=user.tar.gz'                      >> $RESTORE_SCRIPT
  echo ''                                            >> $RESTORE_SCRIPT
else
  echo 'echo Restore user NOT POSSIBLE'              >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'    >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
