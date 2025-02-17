#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2files4backup.sh
else
  source $DIR/modules/defaults_2files4backup.sh
fi



# Assuming the script will succeed
EXIT_CODE=0



# Backup Log Files
#
# /var/log
#
echo "$(date +'%H:%M:%S') /var/log: backup files ..."     >>$LOGTMP
tar --create \
    --gzip \
    --file=var_log.tar.gz \
    --directory=/ \
    var/log                                               >>$LOGTMP 2>&1
EXIT_CODE+=$?
echo "$(date +'%H:%M:%S') /var/log: backup files done"    >>$LOGTMP

# log files will not be restored
(exit $EXIT_CODE)
