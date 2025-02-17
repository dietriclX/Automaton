#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2files.sh
else
  source $DIR/modules/defaults_2files.sh
fi



PRINT_HELP=false
if [ $# -eq 0 ] || [ $# -gt 1 ]; then
  echo "ERROR: script has to be started with one argument"    >>$LOGTMP
  PRINT_HELP=true
elif [ "$1" != "`expr $1`" ]; then
  echo "ERROR: argument has to be an integer"                 >>$LOGTMP
  PRINT_HELP=true
else
  declare -i iArgument=$1
  if [ $iArgument -gt 330 ]; then
    echo "ERROR: specified TIME is too high"                  >>$LOGTMP
    PRINT_HELP=true
  fi
  if [ $iArgument -gt 21 ] && [ $iArgument -lt 30 ]; then
    echo "ERROR: specified TIME is invalid"                   >>$LOGTMP
    PRINT_HELP=true
  fi
fi

if [ "$PRINT_HELP" == "true" ]; then
  # inproper call of script
cat << EOF
Usage: $(basename "$0") [OPTION] TIME

Can enable the standby in TIME minutes for device of $MNT_DIR_DEVICE.

  -h, --help                   display this help and exit

With TIME specified as "0", disables the automatic standby.
Other allowed values for TIME in minutes are:

  1 - 21   : in 1 minute increments
  30 - 330 : in 30 minute increments
EOF
  exit 1
fi

LOCAL_SYSTEM_DEVICE=`findmnt --noheadings --output SOURCE --target /`
LOCAL_BACKUP_DEVICE=`findmnt --noheadings --output SOURCE --target $MNT_DIR_DEVICE`

if [ "$LOCAL_SYSTEM_DEVICE" == "$LOCAL_BACKUP_DEVICE" ]; then
  BACKUP_DEVICE_ALREADY_MOUNTED=false
else
  BACKUP_DEVICE_ALREADY_MOUNTED=true
fi

if [ "$BACKUP_DEVICE_ALREADY_MOUNTED" == "false" ]; then
  echo "have to mount the device in order to identify the devices name"    >>$LOGTMP
  mount /$MNT_DIR_DEVICE                                                   >>$LOGTMP 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: unable to mount backup device"                            >>$LOGTMP
    exit 1
  fi
fi

if [ $iArgument -le 21 ]; then
  if [ $iArgument -eq 21 ]; then
   declare -i iHDPARM_S=252
  else
    declare -i iHDPARM_S=$(($iArgument * 12))
  fi
else
  declare -i iHDPARM_S=$(($iArgument / 30 + 240))
fi

hdparm -S $iHDPARM_S $LOCAL_BACKUP_DEVICE    >>$LOGTMP 2>&1

if [ "$BACKUP_DEVICE_ALREADY_MOUNTED" == "false" ]; then
  echo "going to unmout the temporarly mounted device"      >>$LOGTMP
  umount /$MNT_DIR_DEVICE                                   >>$LOGTMP 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: unable to mount backup device"             >>$LOGTMP
    exit 1
  fi
fi
