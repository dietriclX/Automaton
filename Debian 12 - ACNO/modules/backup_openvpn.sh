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

# OpenVPN
#
# /etc/openvpn/server
#
if [ "$ADDON_OPENVPN" == "true" ]; then
  echo "$(date +'%H:%M:%S') OpenVPN: backup files ..."             >>$LOGTMP

  # files for backup
  #
  cat << EOF > /tmp/backup.topic.files
etc/default/netfilter-persistent
etc/iptables
etc/openvpn/server
etc/sysctl.conf
usr/share/netfilter-persistent/plugins.d
EOF
  cat /tmp/backup.topic.files >> backup.files

  # tar files
  #
  tar --create \
      --gzip \
      --file=openvpn.tar.gz \
      --directory=/ \
      --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
  EXIT_CODE+=$?
  echo "$(date +'%H:%M:%S') OpenVPN: backup done"                  >>$LOGTMP

  if [ $EXIT_CODE -eq 0 ]; then
    #
    # restore instructions
    #
    echo ''                                                       >> $RESTORE_SCRIPT
    echo ''                                                       >> $RESTORE_SCRIPT
    echo ''                                                       >> $RESTORE_SCRIPT
    echo '#'                                                      >> $RESTORE_SCRIPT
    echo '# OpenVPN'                                              >> $RESTORE_SCRIPT
    echo '#'                                                      >> $RESTORE_SCRIPT
    echo 'echo Restore OpenVPN'                                   >> $RESTORE_SCRIPT
    echo 'tar --extract \'                                        >> $RESTORE_SCRIPT
    echo '    --gzip \'                                           >> $RESTORE_SCRIPT
    echo '    --dereference \'                                    >> $RESTORE_SCRIPT
    echo '    --directory=/ \'                                    >> $RESTORE_SCRIPT
    echo '    --file=openvpn.tar.gz'                              >> $RESTORE_SCRIPT
    echo '# iptables netfilter-persistent iptables-persistent'    >> $RESTORE_SCRIPT
    echo 'iptables-restore < /etc/iptables/rules.v4'              >> $RESTORE_SCRIPT
    echo 'iptables-restore < /etc/iptables/rules.v6'              >> $RESTORE_SCRIPT
    echo 'systemctl restart netfilter-persistent.service'         >> $RESTORE_SCRIPT
    echo '# Service OpenVPN server'                               >> $RESTORE_SCRIPT
    echo 'systemctl enable --now openvpn-server@server'           >> $RESTORE_SCRIPT
    echo ''                                                       >> $RESTORE_SCRIPT
  else
    echo 'echo Restore OpenVPN NOT POSSIBLE'                      >> $RESTORE_SCRIPT
    echo 'echo There had been an issue with Backup'               >> $RESTORE_SCRIPT
  fi
else
  echo "$(date +'%H:%M:%S') OpenVPN: skipped"             >>$LOGTMP
fi # only if OpenVPN is in use
(exit $EXIT_CODE)
