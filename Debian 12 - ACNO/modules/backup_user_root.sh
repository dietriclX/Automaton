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

echo "$(date +'%H:%M:%S') root: backup ..."                          >>$LOGTMP

# create an ACNO specific backup of crontab (root)
#
crontab -l | \
  ( \
    echo '# --- START OF ACNO SPECIFIC DEFINITIONS --- #'; \
    sed --expression='1,/START OF ACNO SPECIFIC DEFINITIONS/d' \
  ) > crontab.root.ACNO

# files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/crontab.root.ACNO
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat << EOF >> /tmp/backup.topic.files
root/.gnupg
root/scripts
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
tar --create \
    --gzip \
    --file=root.tar.gz \
    --directory=/ \
    --exclude=S.* \
    --files-from=/tmp/backup.topic.files                             >>$LOGTMP 2>&1
EXIT_CODE+=$?

# copy over the ACNO scripts
# backup group has to have access to directory scripts/data
#
cp --preserve --recursive $DIR/* scripts                             >>$LOGTMP 2>&1
EXIT_CODE+=$?
chgrp backup scripts                                                 >>$LOGTMP 2>&1
EXIT_CODE+=$?
chgrp backup scripts/data                                            >>$LOGTMP 2>&1
EXIT_CODE+=$?

# force the admin to re-build the variables.sh
#
rm --force scripts/variables.sh                                      >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') root: backup done"                         >>$LOGTMP



echo "$(date +'%H:%M:%S') root: add restore commands ..."            >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                                  >> $RESTORE_SCRIPT
  echo ''                                                                  >> $RESTORE_SCRIPT
  echo ''                                                                  >> $RESTORE_SCRIPT
  echo '#'                                                                 >> $RESTORE_SCRIPT
  echo '# User root'                                                       >> $RESTORE_SCRIPT
  echo '#'                                                                 >> $RESTORE_SCRIPT
  echo 'echo Restore root'                                                 >> $RESTORE_SCRIPT
  echo 'rm --force \'                                                      >> $RESTORE_SCRIPT
  echo '   .#lk0* \'                                                       >> $RESTORE_SCRIPT
  echo '   private-keys-* \'                                               >> $RESTORE_SCRIPT
  echo '   pubring.* \'                                                    >> $RESTORE_SCRIPT
  echo '   random_seed \'                                                  >> $RESTORE_SCRIPT
  echo '   trustdb.gpg'                                                    >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                   >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                      >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                               >> $RESTORE_SCRIPT
  echo '    --file=root.tar.gz'                                            >> $RESTORE_SCRIPT
  echo '# save crontab w/o the ACNO part'                                  >> $RESTORE_SCRIPT
  echo 'crontab -l | \'                                                    >> $RESTORE_SCRIPT
  echo '  sed --quiet \'                                                   >> $RESTORE_SCRIPT
  echo '      --expression="/START OF ACNO SPECIFIC DEFINITIONS/q;p" \'    >> $RESTORE_SCRIPT
  echo '  > $MNT_DIR_DEVICE/today/crontab.root.woACNO'                     >> $RESTORE_SCRIPT
  echo '# replace existing crontab by .woACNO + .ACNO'                     >> $RESTORE_SCRIPT
  echo 'cat   $MNT_DIR_DEVICE/today/crontab.root.woACNO \'                 >> $RESTORE_SCRIPT
  echo '      $MNT_DIR_DEVICE/today/crontab.root.ACNO \'                   >> $RESTORE_SCRIPT
  echo '    > $MNT_DIR_DEVICE/today/crontab.root'                          >> $RESTORE_SCRIPT
  echo 'crontab -r'                                                        >> $RESTORE_SCRIPT
  echo 'crontab $MNT_DIR_DEVICE/today/crontab.root'                        >> $RESTORE_SCRIPT
  echo ''                                                                  >> $RESTORE_SCRIPT
else
  echo 'echo Restore root NOT POSSIBLE'                                    >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                          >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
