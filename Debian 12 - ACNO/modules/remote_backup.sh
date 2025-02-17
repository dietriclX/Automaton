#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2files.sh
else
  source $DIR/modules/defaults_2files.sh
fi



if [ "$ADDON_REMOTE_BACKUP" != "true" ]; then
  echo "$(date +'%H:%M:%S') Remote Backup: is disabled"     >>$LOGTMP
  exit 0
fi



# Clean-Up files from a previous backup
#
if [ "$1" == "prepare" ]; then
  echo "$(date +'%H:%M:%S') Remote Backup: prepare directory"     >>$LOGTMP

  if [ -d "$MNT_DIR_DEVICE/remote" ]; then
    echo "$(date +'%H:%M:%S') Remote Directory: exists"           >>$LOGTMP
    rm --force remote.READY                                       >>$LOGTMP 2>&1
  else
    echo "$(date +'%H:%M:%S') Remote Directory: missing"          >>$LOGTMP
    mkdir --mode=770 $MNT_DIR_DEVICE/remote                       >>$LOGTMP 2>&1
    chgrp backup $MNT_DIR_DEVICE/remote                           >>$LOGTMP 2>&1
    echo "$(date +'%H:%M:%S') Remote Directory: created"          >>$LOGTMP
  fi
  exit 0
fi



# Update the remote directory
#
if [ "$1" == "backup" ]; then
  echo "$(date +'%H:%M:%S') Remote Backup: update directory"                >>$LOGTMP

  # rsync local files into remote directory
  #
  if [ -f "$MNT_DIR_DEVICE/remote.in.progress" ]; then
    # in case the remote client is still working on the backup
    # no new rsync should take place
    echo "$(date +'%H:%M:%S') Remote Backup: last one still in progress"    >>$LOGTMP
  else
    echo "$(date +'%H:%M:%S') Remote Backup: update directory"              >>$LOGTMP
    rsync --delete \
          --recursive --links \
          --perms --group --owner \
          --times \
          --devices --specials \
          --files-from=backup.files \
          / $MNT_DIR_DEVICE/remote                                          >>$LOGTMP 2>&1
  fi
  
  exit 0
fi



# Update the remote directory
#
if [ "$1" == "initiate" ]; then
  echo "$(date +'%H:%M:%S') Remote Backup: indirectly initated on remote"    >>$LOGTMP

  # create indicator, that the remote directory is ready to downloaded
  #
  touch remote.READY                                                         >>$LOGTMP 2>&1
  chown root:backup remote.READY                                             >>$LOGTMP 2>&1

  exit 0
fi
