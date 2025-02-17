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

# Backup SOMETHING

echo here is a command
EXIT_CODE+=$?


echo "$(date +'%H:%M:%S') SOMETHING: backup done"        >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo 'echo Restore SOMETHING'                      >> $RESTORE_SCRIPT
  .
  .
  .
else
  echo 'echo Restore SOMETHING NOT POSSIBLE'         >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'    >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
