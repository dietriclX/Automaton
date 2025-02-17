#!/bin/bash

#
# Script to be called with a valid list of ACNO services
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2stdout.sh
else
  source $DIR/modules/defaults_2stdout.sh
fi



# Definition of crucial service and their status at the end (they should have).
#   Relevant for the backup and restore operation.
source $DIR/modules/create_services_list.sh

# Delete files, needed for this script.
# They should not exist when started.
#
rm --force /tmp/services_are_running.lines
rm --force /tmp/services_not_running.lines
rm --force /tmp/services_not_listed.lines

# for the Summary, evaluate relevant the Services
# in addition, add the same check to the restore.sh file
#
unset backupIFS
[ -n "${IFS+set}" ] && backupIFS=$IFS
LC_CTYPE=C systemctl --all | grep --regexp=".*\.service" > /tmp/services_systemctl.out
IFS=,
while [ "$1" != "" ]
do
  sServiceLine=`grep --regexp="^[0-9]*,[^,]*,$1," $DIR/modules/services_list.dat`
  if [ "$?" -eq 0 ]; then
    read -r nOrder sAllowed sUnit sLoad sActive sSub <<<$sServiceLine
    grep --silent --regexp="^. $sUnit\.service " /tmp/services_systemctl.out
    if [ $? -eq 0 ]; then
      grep --silent --regexp="^. $sUnit\.service *$sLoad *$sActive *$sSub" /tmp/services_systemctl.out
      if [ $? -eq 0 ]; then
        echo $sUnit >> /tmp/services_are_running.lines
      else
        echo $sUnit >> /tmp/services_not_running.lines
      fi
    else
      echo $sUnit   >> /tmp/services_not_listed.lines
    fi
  fi
  shift
done
if [ -f "/tmp/services_not_listed.lines" ]; then
  echo "ALERT: not all services were listed/enabled ..."    >> $LOGTMP
  sed -e "s/^/- /" /tmp/services_not_listed.lines           >> $LOGTMP
fi
if [ -f "/tmp/services_not_running.lines" ]; then
  echo "ERROR: not all services in expected state"          >> $LOGTMP
  sed -e "s/^/- /" /tmp/services_not_running.lines          >> $LOGTMP
fi
if [ ! -f "/tmp/services_not_listed.lines" ] && [ ! -f "/tmp/services_not_running.lines" ]; then
  echo "Services are OKAY."                                 >> $LOGTMP
fi
unset IFS
[ -n "${backupIFS+set}" ] && { IFS=$backupIFS; unset backupIFS; }

rm --force /tmp/services_not_listed.lines
rm --force /tmp/services_not_running.lines
rm --force /tmp/backup_not_successfule.lines
