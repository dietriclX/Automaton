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

echo "$(date +'%H:%M:%S') OS: backup files ..."               >>$LOGTMP

# create a host name based backup of the ssh keys
#
if [ ! -d "/etc/ssh/KEY-BACKUP.$HOST_NAME" ]; then
  mkdir /etc/ssh/KEY-BACKUP.$HOST_NAME
  cp /etc/ssh/*key* /etc/ssh/KEY-BACKUP.$HOST_NAME
fi

# create an ACNO specific backup of fstab
#
( \
  echo '# --- START OF ACNO SPECIFIC DEFINITIONS --- #'; \
  sed '1,/START OF ACNO SPECIFIC DEFINITIONS/d' /etc/fstab \
) > fstab.ACNO
 
# files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/fstab.ACNO
EOF
cp /tmp/backup.topic.files /tmp/backup.temp.files
cat << EOF >> /tmp/backup.topic.files
etc/ssl/certs/$ACNO_DOMAIN.crt
etc/ssl/private/$ACNO_DOMAIN.key
EOF
if [ ! -z "$ACNO_DOMAIN2" ]; then
  cat << EOF >> /tmp/backup.topic.files
etc/ssl/certs/$ACNO_DOMAIN2.crt
etc/ssl/private/$ACNO_DOMAIN2.key
EOF
fi
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=osandco.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                  >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') OS: backup done"                    >>$LOGTMP



echo "$(date +'%H:%M:%S') OS: add restore commands ..."    >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                        >> $RESTORE_SCRIPT
  echo ''                                                        >> $RESTORE_SCRIPT
  echo ''                                                        >> $RESTORE_SCRIPT
  echo '#'                                                       >> $RESTORE_SCRIPT
  echo '# OS related'                                            >> $RESTORE_SCRIPT
  echo '#'                                                       >> $RESTORE_SCRIPT
  echo 'echo Restore OS related parts'                           >> $RESTORE_SCRIPT
  echo 'if [ "$NEW_MACHINE" == "yes" ]; then'                    >> $RESTORE_SCRIPT
  echo '  mkdir /etc/ssh/KEY-BACKUP.$HOST_NAME'                  >> $RESTORE_SCRIPT
  echo '  cp /etc/ssh/*key* /etc/ssh/KEY-BACKUP.$HOST_NAME'      >> $RESTORE_SCRIPT
  echo 'fi'                                                      >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                         >> $RESTORE_SCRIPT
  echo '    --gzip \'                                            >> $RESTORE_SCRIPT
  echo '    --dereference \'                                     >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                     >> $RESTORE_SCRIPT
  echo '    --file=osandco.tar.gz'                               >> $RESTORE_SCRIPT
  echo 'cp /etc/ssh/KEY-BACKUP.$HOST_NAME/*key* /etc/ssh'        >> $RESTORE_SCRIPT
  echo 'if [ "$NEW_MACHINE" == "yes" ]; then'                    >> $RESTORE_SCRIPT
  echo '  cat $MNT_DIR_DEVICE/today/fstab.ACNO >> /etc/fstab'    >> $RESTORE_SCRIPT
  echo '  systemctl daemon-reload'                               >> $RESTORE_SCRIPT
  echo 'fi'                                                      >> $RESTORE_SCRIPT
  echo 'systemctl restart sshd'                                  >> $RESTORE_SCRIPT
  echo 'sysctl --load'                                           >> $RESTORE_SCRIPT
  echo 'netfilter-persistent save'                               >> $RESTORE_SCRIPT
  echo 'update-ca-certificates'                                  >> $RESTORE_SCRIPT
  echo ''                                                        >> $RESTORE_SCRIPT
else
  echo 'echo Restore OS related parts NOT POSSIBLE'              >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
