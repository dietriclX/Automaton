#!/bin/bash

#
# Send log file via email, either plain text or encrypted.
# 1. Argument: File name
# 2. Argument: Subject
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2stdout.sh
else
  source $DIR/modules/defaults_2stdout.sh
fi



echo "$(date +'%H:%M:%S') function $FUNCNAME"                           >>$LOGTMP
if [ ! -z "$1" ]; then
  echo "$(date +'%H:%M:%S') 1. Parameter: $1"                           >>$LOGTMP
fi
if [ ! -z "$2" ]; then
  echo "$(date +'%H:%M:%S') 2. Parameter: $2"                           >>$LOGTMP
fi
if [ ! -z "$3" ]; then
  echo "$(date +'%H:%M:%S') 3. Parameter: $3"                           >>$LOGTMP
fi
if [ "$ADDON_ROOT_EMAIL_SEND" == "true" ]; then
  # Root is cablable of sending email
  if [ "$ADDON_ROOT_EMAIL_ENCRYPTION" == "true" ]; then
    # send encrypted log file
    rm --force $1.asc
    gpg --recipient $NEXTCLOUD_ADMIN_EMAIL \
        --sign \
        --armor \
        --output $1.asc \
        --encrypt $1                                         >>$LOGTMP 2>&1
    if [ $? -eq 0 ]; then
      # able to send encrypted log file
      if [ "$#" -eq 2 ]; then
        mail --subject="$2" $NEXTCLOUD_ADMIN_EMAIL < $1.asc
      else
        mail $NEXTCLOUD_ADMIN_EMAIL < $1.asc
      fi
    else
      # unable to encrypt log file => send plain log file
      echo "$(date +'%H:%M:%S') gpg failed"                  >>$LOGTMP
      if [ "$#" -eq 2 ]; then
        mail --subject="$2" $NEXTCLOUD_ADMIN_EMAIL < $1
      else
        mail $NEXTCLOUD_ADMIN_EMAIL < $1
      fi
    fi # gpg was successful, or not
  else
    # send log file as plain text
    if [ "$#" -eq 2 ]; then
      mail --subject="$2" $NEXTCLOUD_ADMIN_EMAIL < $1
    else
      mail $NEXTCLOUD_ADMIN_EMAIL < $1
    fi
  fi # use encryption, or not
fi # root is able to send emails
