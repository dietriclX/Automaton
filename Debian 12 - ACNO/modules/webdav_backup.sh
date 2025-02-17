#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2files.sh
else
  source $DIR/modules/defaults_2files.sh
fi



if [ "$ADDON_WEBDAV_BACKUP" == "true" ]; then
  echo "$(date +'%H:%M:%S') WebDAV Backup: is disabled"     >>$LOGTMP
  exit 0
fi



# Clean-Up files from a previous backup
#
if [ "$1" == "prepare" ]; then
  echo "$(date +'%H:%M:%S') WebDAV Backup: prepare directory"     >>$LOGTMP

  if [ -d "$MNT_DIR_DEVICE/webdav" ]; then
    echo "$(date +'%H:%M:%S') WebDAV Directory: exists"     >>$LOGTMP
    rm --force $MNT_DIR_DEVICE/webdav/Archive.READY \
               $MNT_DIR_DEVICE/webdav/Archive.FILES \
               $MNT_DIR_DEVICE/webdav/Archive.SHA1 \
               $MNT_DIR_DEVICE/webdav/Archive.???           >>$LOGTMP 2>&1
  else
    echo "$(date +'%H:%M:%S') WebDAV Directory: missing"    >>$LOGTMP
    mkdir --mode=770 $MNT_DIR_DEVICE/webdav                 >>$LOGTMP 2>&1
    chgrp backup $MNT_DIR_DEVICE/webdav                     >>$LOGTMP 2>&1
    echo "$(date +'%H:%M:%S') WebDAV Directory: created"    >>$LOGTMP
  fi

  exit 0
fi



# Update the webdav directory
#
# Archive.???      - CD-sized chucks of the encrypted tarball from directory $MNT_DIR_DEVICE/$STARTDATE
# Archive.FILES    - list of the Archive.??? files
# Archive.SHA1     - list of the Archive.??? files with their SHA1 checksum
# Archive.READY    - "Flag" for remote backup system, indicating that everything had been prepared and is ready to be pulled over
# Archive.FINISHED - "Flag" set by remote backup system, indicating that all files were correctly transfered
#
if [ "$1" == "backup" ]; then
  echo "$(date +'%H:%M:%S') WebDAV Backup: update directory"                                                                      >>$LOGTMP

  tar --create --directory=$MNT_DIR_DEVICE/today \
      . | \
    gpg --encrypt --recipient $NEXTCLOUD_ADMIN_EMAIL --output - | \
      split --numeric-suffixes --suffix-length=3 --bytes=650M - $MNT_DIR_DEVICE/webdav/Archive.                                   >>$LOGTMP 2>&1
  # create file list (command is "ls" minus one)
  ls -1 $MNT_DIR_DEVICE/webdav/Archive.??? > $MNT_DIR_DEVICE/webdav/Archive.FILES
  # create checksum file list
  shasum $MNT_DIR_DEVICE/webdav/Archive.??? > $MNT_DIR_DEVICE/webdav/Archive.SHA1
  chown root:backup $MNT_DIR_DEVICE/webdav/Archive.*                                                                              >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') WebDAV Backup: prepare archive done"                                                                  >>$LOGTMP
  echo "$(date +'%H:%M:%S') WebDAV Backup: Backup split up into `wc -l $MNT_DIR_DEVICE/webdav/Archive.FILES` Archive.?? files"    >>$LOGTMP
  
  exit 0
fi



# Inititate the upload
#
if [ "$1" == "initiate" ]; then
  echo "$(date +'%H:%M:%S') WebDAV Backup: initated upload"              >>$LOGTMP

  (
    SCRIPTNAME=$(basename "$0")
    SCRIPTNAME=${SCRIPTNAME%.*}
    LOGTMP=/tmp/$SCRIPTNAME_$START.out

    $DIR/modules/$SCRIPTNAME.sh upload &
  )
fi



# The Upload
#
if [ "$1" == "upload" ]; then
  echo "$(date +'%H:%M:%S') WebDAV Backup: start upload"                               >>$LOGTMP

  # mount WebDav drive
  echo "$(date +'%H:%M:%S') WebDAV: mounting ..."                                      >>$LOGTMP
  mount $MNT_DIR_WEBDAV                                                                >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') WebDAV: mounting done"                                     >>$LOGTMP

  echo "$(date +'%H:%M:%S') Archive.* : delete old archive ..."                        >>$LOGTMP
  rm --force $MNT_DIR_WEBDAV/$WEBDAV_BACKUP_DIR/Archive.*                              >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') Archive.* : delete old archive done"                       >>$LOGTMP

  echo "$(date +'%H:%M:%S') Archive.* : upload archive ..."                            >>$LOGTMP
  cp Archive.SIZE $MNT_DIR_WEBDAV/$WEBDAV_BACKUP_DIR                                   >>$LOGTMP 2>&1
  ls Archive.??? | while read f
  do
    echo "$(date +'%H:%M:%S') cp $f $MNT_DIR_WEBDAV/$WEBDAV_BACKUP_DIR"                >>$LOGTMP 
    cp $f $MNT_DIR_WEBDAV/$WEBDAV_BACKUP_DIR                                           >>$LOGTMP 2>&1
    echo "$(date +'%H:%M:%S') sync $MNT_DIR_WEBDAV"                                    >>$LOGTMP
    sync $MNT_DIR_WEBDAV                                                               >>$LOGTMP 2>&1
  done 
  cp Archive.SHA1 $MNT_DIR_WEBDAV/$WEBDAV_BACKUP_DIR                                   >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') Archive.* : upload archive done"                           >>$LOGTMP

  # Number of Archive.* which were not uploaded and therefor placed in lost+found
  i=`ls /mnt/webdav.magentacloud/lost+found/Archive.* 2>/dev/null | wc -l`             >>$LOGTMP 2>&1

  if [ "$i" -ne "0" ]; then
    echo "$(date +'%H:%M:%S') Archive.* : ERROR $i files were not uploaded"            >>$LOGTMP
  fi # WebDAV directory lost+found got some Archive.* file

  # un-mount WebDav drive
  echo "$(date +'%H:%M:%S') WebDAV: un-mounting ..."                                   >>$LOGTMP
  umount $MNT_DIR_WEBDAV                                                               >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') WebDAV: un-mounting done"                                  >>$LOGTMP

  # switch to home directory
  cd ~

  # Un-mount backup device
  #
  echo "$(date +'%H:%M:%S') Device: unmount ..."                                       >>$LOGTMP
  umount $MNT_DIR_DEVICE                                                               >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') Device: unmount done"                                      >>$LOGTMP

  # Send log file
  #
  if [ "$ADDON_ROOT_EMAIL_SEND" == "true" ]; then
    if [ "$ADDON_ROOT_EMAIL_ENCRYPTION" == "true" ]; then
      gpg --recipient $NEXTCLOUD_ADMIN_EMAIL --sign --armor --output $LOGTMP.asc --encrypt $LOGTMP
      mail $NEXTCLOUD_ADMIN_EMAIL < $LOGTMP.asc
    else
      mail $NEXTCLOUD_ADMIN_EMAIL < $LOGTMP
    fi # use encryption, or not
  fi # root is able to send emails

  # Send log file
  # based on information from the summary, the email might be given a predefined priority
  #
  source $DIR/modules/send_email.sh /tmp/$LOGTMP.log

  exit 0
fi
