#!/bin/bash

#
# Checks for available OS updates.
# Status report will be provided.
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/modules/defaults_2stdout4scripts.sh
else
  source $DIR/modules/modules/defaults_2stdout4scripts.sh
fi



# Remove files, needed for this scripot
rm --force /tmp/apt_update.out

apt update > /tmp/apt_update.out 2>/dev/null

SUMMARY=`sed '1,/^Reading state information/d' /tmp/apt_update.out  | head --lines=1`

if [ "$SUMMARY" == "All packages are up to date." ]; then
  echo $SUMMARY                        >> $LOGTMP
else
  echo "Available Updates"             >> $LOGTMP
  apt list --upgradable 2>/dev/null    >> $LOGTMP
fi

rm --force /tmp/apt_update.out
