#!/bin/bash

#
# Script to be called with a valid list of ACNO services
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2stdout.sh
else
  source $DIR/modules/defaults_2stdout.sh
fi



while [ "$1" != "" ]
do
  systemctl stop $1
  echo "$(date +'%H:%M:%S') $1: shut down"    >>$LOGTMP
  shift
done
