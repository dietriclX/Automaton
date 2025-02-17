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

echo "$(date +'%H:%M:%S') OS basic: backup files ..."            >>$LOGTMP

# files for backup
#
cat << EOF > /tmp/backup.topic.files
etc/default/grub
etc/apt/sources.list
etc/apt/sources.list.d
usr/share/keyrings/onlyoffice.gpg
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=osbasis.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') OS basic: backup done"                 >>$LOGTMP


echo "$(date +'%H:%M:%S') OS basic: add restore commands ..."    >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                >> $RESTORE_SCRIPT
  echo ''                                                >> $RESTORE_SCRIPT
  echo ''                                                >> $RESTORE_SCRIPT
  echo '#'                                               >> $RESTORE_SCRIPT
  echo '# OS Basics'                                     >> $RESTORE_SCRIPT
  echo '#'                                               >> $RESTORE_SCRIPT
  echo 'echo Restore basic OS related parts'             >> $RESTORE_SCRIPT
  echo 'if [ "$NEW_MACHINE" == "yes" ]; then'            >> $RESTORE_SCRIPT
  echo '  tar --extract \'                               >> $RESTORE_SCRIPT
  echo '      --gzip \'                                  >> $RESTORE_SCRIPT
  echo '      --dereference \'                           >> $RESTORE_SCRIPT
  echo '      --directory=/ \'                           >> $RESTORE_SCRIPT
  echo '      --file=osbasis.tar.gz'                     >> $RESTORE_SCRIPT
  echo '  rm /etc/ssh/ssh_host_*'                        >> $RESTORE_SCRIPT
  echo '  ssh-keygen -A'                                 >> $RESTORE_SCRIPT
  echo '  update-grub'                                   >> $RESTORE_SCRIPT
  echo 'fi'                                              >> $RESTORE_SCRIPT
  echo ''                                                >> $RESTORE_SCRIPT
else
  echo 'echo Restore basis OS relatered NOT POSSIBLE'    >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'        >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
