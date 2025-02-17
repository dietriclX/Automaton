#!/bin/bash

#
# Download the Archive.* files from the servers Backup Device. Check the correctness and remove the files from the server.
# VPN Connection:
# - will be established with the VPN-Server.
# - get close once successeful done
# - remains in case of failure
#

# directory of script
#
DIR=$(dirname "$(realpath "$0")")

# set the variables / script in same directory
#     
. $DIR/variables.sh

# Set variables for start date/time
#     START YYMMDD-HHMM e.g. 241231-2359
# STARTDATE YYMMDD      e.g. 241231
# STARTTIME HHMM        e.g. 2359
# STARTTIME_H HHMM      e.g. 23:59
#
START=$(date +'%y%m%d-%H%M')
STARTDATE=$(date +'%y%m%d')
STARTTIME=$(date +'%H%M')
STARTTIME_H=$(date +'%H:%M')

# Set variable for log file LOGTMP
#
LOGTMP=/tmp/upload_$START.out
rm --force $LOGTMP



# Process script arguments
#

# Do not print, if not required.
PRINT_HELP=false

# Connection name of OpenVPN
OPENVPN_CONNECTION=""

# Test-Mode; in Test-Mode, maximum number of Archive.??? files to be downloaded.
TEST_MODE=false
declare -i TEST_FILE_NUM

# Parse the Options
#
while [ "${1:0:1}" == "-" ]
do
  if [ "$1" == "-c" ] && [ "$2" != "" ]; then
    # 1. argument is "-c"
    # 2. argument is <name>
    shift
    OPENVPN_CONNECTION=$1
    shift
  elif [ "${#1}" -ge 13 ] && [ "${1:0:13}" == "--connection=" ]; then
    # 1. argument is "--connection=<name>"
    OPENVPN_CONNECTION=$((${1:13}))
    shift
  elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    # 1. argument is either "-h" or "--help"
    PRINT_HELP=true
    shift
  elif [ "$1" == "-t" ] || [ "$1" == "--test" ]; then
    # 1. argument is either "-t" or "--test"
    TEST_MODE=true
    shift
  elif [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    # 1. argument is either "-v" or "--verbose"
    LOGTMP=/dev/stdout
    shift
  else
    # 1. argument is unkown => Error
    echo 'ERROR: incorrect option "'$1'"'                        >> /dev/stderr
    PRINT_HELP=true
    shift
  fi
done

# Ignore the Rest of arguments
#

# Print Help, if required
#
if [ "$PRINT_HELP" == "true" ]; then
  # improper call of script
  # or requested help
cat << EOF
Usage: $(basename "$0") [OPTION]

Download all "Archive.???" files from the ACNO server.
The exact path/file(s) are specific in "Archive.FILES".

  -c NAME, --connection=NAME    the OpenVPN connection configuration
                                name. This OpenVPN client service will be
                                registered and used.
  -h, --help                    display this help and exit
  -t, --test                    tests the synchronization, by using option,
                                "--dry-run" of rsync
  -v, --verbose                 instead of writing the output into file
                                /tmp/file upload_YYMMDD-HHMM.out
                                the log information is directed to stdout

EOF
  exit 1
fi



echo "$(date +'%H:%M:%S') Download Script: start ..." >>$LOGTMP



# Inform about execution in Test-Mode, if that is the case ...
#
if [ "$TEST_MODE" == "true" ]; then
    echo "INFO Execution in Test-Mode/Dry-Run."                 >>$LOGTMP
    echo "INFO No changes on the server."                       >>$LOGTMP
    echo "INFO No changes on local machine."                    >>$LOGTMP
fi



#
# Check existance of VPN client configuration and close the related services.
#
echo "$(date +'%H:%M:%S') OpenVPN: Check for existance of Client Configuration(s)."                     >>$LOGTMP

# In case VPN Client Configuration was specified as part of the arguments.
#
if [ -z "$OPENVPN_CONNECTION" ]; then
  echo "$(date +'%H:%M:%S') Going to used Primary/Backup VPN Connection(s) as specified."               >>$LOGTMP
else
  echo "$(date +'%H:%M:%S') $(basename "$0"): VPN Connection specified as part of the arguments."       >>$LOGTMP
  echo "$(date +'%H:%M:%S') OpenVPN: Client Configuration = $OPENVPN_CONNECTION"                        >>$LOGTMP
  if [ -f "/etc/openvpn/client/$OPENVPN_CONNECTION.conf" ]; then
    echo "$(date +'%H:%M:%S') found definition file /etc/openvpn/client/$OPENVPN_CONNECTION.conf"       >>$LOGTMP
    echo "$(date +'%H:%M:%S') OpenVPN: Enable $OPENVPN_CONNECTION service"                              >>$LOGTMP
    systemctl enable openvpn-client@$OPENVPN_CONNECTION                                                 >>$LOGTMP 2>&1
    echo "$(date +'%H:%M:%S') OpenVPN: Stop $OPENVPN_CONNECTION service (maybe already in use)"         >>$LOGTMP
    systemctl stop openvpn-client@$OPENVPN_CONNECTION                                                   >>$LOGTMP 2>&1
  else
    echo "$(date +'%H:%M:%S') OpenVPN: no definition file found"                                        >>$LOGTMP
    echo "$(date +'%H:%M:%S')          /etc/openvpn/client/$OPENVPN_CONNECTION.conf"                    >>$LOGTMP
  fi
fi

# In case LOCAL_VPN_PRIMARY was specified
#
if [ -z "$LOCAL_VPN_PRIMARY" ]; then
  echo "$(date +'%H:%M:%S') No Primary VPN Connection specified."                                       >>$LOGTMP
else
  echo "$(date +'%H:%M:%S') Primary VPN Connection specified."                                          >>$LOGTMP
  echo "$(date +'%H:%M:%S') Variable LOCAL_VPN_PRIMARY = $LOCAL_VPN_PRIMARY"                            >>$LOGTMP
  if [ -f "/etc/openvpn/client/$LOCAL_VPN_PRIMARY.conf" ]; then
    echo "$(date +'%H:%M:%S') found definition file /etc/openvpn/client/$LOCAL_VPN_PRIMARY.conf"        >>$LOGTMP
    echo "$(date +'%H:%M:%S') OpenVPN: Stop $LOCAL_VPN_PRIMARY service"                                 >>$LOGTMP
    systemctl stop openvpn-client@$LOCAL_VPN_PRIMARY                                                    >>$LOGTMP 2>&1
  else
    echo "$(date +'%H:%M:%S') OpenVPN: no definition file found"                                        >>$LOGTMP
    echo "$(date +'%H:%M:%S')          /etc/openvpn/client/$LOCAL_VPN_PRIMARY.conf"                     >>$LOGTMP
  fi
fi

# In case LOCAL_VPN_BACKUP was specified
#
if [ -z "$LOCAL_VPN_BACKUP" ]; then
  echo "$(date +'%H:%M:%S') No Backup VPN Connection specified."                                        >>$LOGTMP
else
  echo "$(date +'%H:%M:%S') Backup VPN Connection specified."                                           >>$LOGTMP
  if [ -f "/etc/openvpn/client/$LOCAL_VPN_BACKUP.conf" ]; then
    echo "$(date +'%H:%M:%S') found definition file /etc/openvpn/client/$LOCAL_VPN_BACKUP.conf"         >>$LOGTMP
    echo "$(date +'%H:%M:%S') OpenVPN: Stop $LOCAL_VPN_BACKUP service"                                  >>$LOGTMP
    systemctl stop openvpn-client@$LOCAL_VPN_BACKUP                                                     >>$LOGTMP 2>&1
  else
    echo "$(date +'%H:%M:%S') OpenVPN: no definition file found"                                        >>$LOGTMP
    echo "$(date +'%H:%M:%S')          /etc/openvpn/client/$LOCAL_VPN_BACKUP.conf"                      >>$LOGTMP
  fi
fi
echo "$(date +'%H:%M:%S') $(basename "$0"): pause for 15 seconds ..."                                   >>$LOGTMP
sleep 15s



if [ ! -z "$OPENVPN_CONNECTION" ]; then
  # The VPN Client Connection from the arguments will be used.
  LOCAL_VPN=$OPENVPN_CONNECTION
else
  # Identify OpenVPN Server IP-Address and thus checks the nslookup on DDNS name(s)
  #
  if [ ! -z "$ACNO_DOMAIN" ]; then
    SERVER_VPN_IP_PRIMARY=`dig +short $ACNO_DOMAIN`
    if [ ! -z "$SERVER_VPN_IP_PRIMARY" ]; then
      echo "$(date +'%H:%M:%S') IP-Address $ACNO_DOMAIN: $SERVER_VPN_IP_PRIMARY"    >>$LOGTMP
    fi
  fi
  if [ ! -z "$ACNO_DOMAIN2" ]; then
    SERVER_VPN_IP_BACKUP=`dig +short $ACNO_DOMAIN2`
    if [ ! -z "$SERVER_VPN_IP_BACKUP" ]; then
      echo "$(date +'%H:%M:%S') IP-Address $ACNO_DOMAIN2: $SERVER_VPN_IP_BACKUP"    >>$LOGTMP
    fi
  fi
  if [ "$SERVER_VPN_IP_PRIMARY" != "$SERVER_VPN_IP_BACKUP" ]; then
  if [ ! -z "$ACNO_DOMAIN" ] && [ ! -z "$ACNO_DOMAIN2" ]; then
     # Both primary and backup domain were specfified, but referring to different IP-Addresses
      echo "$(date +'%H:%M:%S') STOP There is a mismatch on the IP-Addresses."      >>$LOGTMP
      echo "$(date +'%H:%M:%S') $ACNO_DOMAIN=$SERVER_VPN_IP_PRIMARY"               >>$LOGTMP
      echo "$(date +'%H:%M:%S') $ACNO_DOMAIN2=$SERVER_VPN_IP_BACKUP"               >>$LOGTMP
  
      source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"
  
      exit 1
    fi
  fi

  # Select OpenVPN client configuration, preferable order is: Primary, Backup
  #
  LOCAL_VPN=""
  if [ ! -z "$SERVER_VPN_IP_PRIMARY" ]; then
    LOCAL_VPN=$LOCAL_VPN_PRIMARY
  elif [ ! -z "$SERVER_VPN_IP_BACKUP" ]; then
    LOCAL_VPN=$LOCAL_VPN_BACKUP
  else
    echo "$(date +'%H:%M:%S') STOP - No IP-Address for neither primary nor backup VPN-Server found."      >>$LOGTMP
  
    source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"
  
    exit 1
  fi
fi

echo "$(date +'%H:%M:%S') OpenVPN - start Client Configuration $LOCAL_VPN"    >>$LOGTMP
systemctl start openvpn-client@$LOCAL_VPN                                     >>$LOGTMP 2>&1
echo "$(date +'%H:%M:%S') $(basename "$0"): pause for 15 seconds ..."         >>$LOGTMP
sleep 15s

# Check Route
# ip router should have three entries referring to "tun0"
#
if [ "`ip route | grep tun0 | wc -l`" != "0" ]; then
  echo "$(date +'%H:%M:%S') Route for VPN Client is set."              >>$LOGTMP
else
  echo "$(date +'%H:%M:%S') Route for VPN Client not properly set."    >>$LOGTMP
  echo "$(date +'%H:%M:%S') See output of 'ip router'"                 >>$LOGTMP
  ip route                                                             >>$LOGTMP 2>&1
fi

# Try to resolve ACNO server name(s).
#
# 1. $SERVER_HOST_NAME
# 2. $SERVER_HOST_NAME.$SERVER_HOST_DOMAIN
# 3. $SERVER_HOST_NAME2
# 4. $SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN
#
SSH_HOST=""

if [ ! -z "$SERVER_HOST_NAME" ]; then
  SERVER_HOST_IP=`dig +short $SERVER_HOST_NAME`
  if [ ! -z "$SERVER_HOST_IP" ]; then
    # IP-Address identified
    SSH_HOST=$SERVER_HOST_NAME
  elif [ ! -z "$SERVER_HOST_DOMAIN" ]; then
    # unable to resolve host name, let's try it with the given DMZ Domain
    SERVER_HOST_IP=`dig +short $SERVER_HOST_NAME.$SERVER_HOST_DOMAIN`
    if [ ! -z "$SERVER_HOST_IP" ]; then
      # IP-Address identified
      SSH_HOST=$SERVER_HOST_NAME.$SERVER_HOST_DOMAIN
    fi
  fi
fi # Primary Hostname given

if [ -z "$SSH_HOST" ] && [ ! -z "$SERVER_HOST_NAME2" ]; then
  SERVER_HOST_IP=`dig +short $SERVER_HOST_NAME2`
  if [ ! -z "$SERVER_HOST_IP" ]; then
    # IP-Address identified
    SSH_HOST=$SERVER_HOST_NAME2
  elif [ ! -z "$SERVER_HOST_DOMAIN" ]; then
    # unable to resolve host name 2, let's try it with the given DMZ Domain
    SERVER_HOST_IP=`dig +short $SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN`
    if [ ! -z "$SERVER_HOST_IP" ]; then
      # IP-Address identified
      SSH_HOST=$SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN
    fi
  fi
fi # Backup Hostname given

if [ -z "$SSH_HOST" ]; then
  echo "$(date +'%H:%M:%S') Unable to resolve host names."    >>$LOGTMP
  echo "$(date +'%H:%M:%S') Let's simply try to connect."     >>$LOGTMP

  # Test $SERVER_HOST_NAME
  declare -l h=$SERVER_HOST_NAME
  declare -l s=`sudo --user=$LOCAL_OS_SYS_USER_NAME ssh $SERVER_HOST_NAME 'echo $HOSTNAME'`                               >>$LOGTMP 2>&1
  if [ $? -eq 0 ] && [ "$s" == "$h" ]; then
    SSH_HOST=$SERVER_HOST_NAME
  else
    # Test $SERVER_HOST_NAME.$SERVER_HOST_DOMAIN
    declare -l s=`sudo --user=$LOCAL_OS_SYS_USER_NAME ssh $SERVER_HOST_NAME.$SERVER_HOST_DOMAIN 'echo $HOSTNAME'`         >>$LOGTMP 2>&1
    if [ $? -eq 0 ] && [ "$s" == "$h" ]; then
      SSH_HOST=$SERVER_HOST_NAME.$SERVER_HOST_DOMAIN
    else
      declare -l h=$SERVER_HOST_NAME2
      # Test $SERVER_HOST_NAME2
      declare -l s=`sudo --user=$LOCAL_OS_SYS_USER_NAME ssh $SERVER_HOST_NAME2 'echo $HOSTNAME'`                          >>$LOGTMP 2>&1
      if [ $? -eq 0 ] && [ "$s" == "$h" ]; then
        SSH_HOST=$SERVER_HOST_NAME2
      else
        # Test $SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN
        declare -l s=`sudo --user=$LOCAL_OS_SYS_USER_NAME ssh $SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN 'echo $HOSTNAME'`    >>$LOGTMP 2>&1
        if [ $? -eq 0 ] && [ "$s" == "$h" ]; then
          SSH_HOST=$SERVER_HOST_NAME2.$SERVER_HOST_DOMAIN
        fi
      fi  
    fi  
  fi  
fi

if [ -z "$SSH_HOST" ]; then
  echo "$(date +'%H:%M:%S') Unable to connect."                       >>$LOGTMP

  source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"

  exit 1
fi
echo "$(date +'%H:%M:%S') $SSH_HOST identified as ACNO Host Name."    >>$LOGTMP



# mount Backup Device on Server, if required
#
MOUNTPOINT_RESULT=`sudo --user=$LOCAL_OS_SYS_USER_NAME \
                        ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
                        "mountpoint --quiet $SERVER_MNT_DIR_DEVICE; echo $?"`
if [ "$MOUNTPOINT_RESULT" == "0" ]; then
  echo "$(date +'%H:%M:%S') Device: already mounted"    >>$LOGTMP
else
  # mount Backup Device on Server
  echo "$(date +'%H:%M:%S') Device: mountpoint $SERVER_MNT_DIR_DEVICE exit code $MOUNTPOINT_RESULT"             >>$LOGTMP
  echo "$(date +'%H:%M:%S') Device: seems like the Backup Device is not mounted on the Server"                  >>$LOGTMP
  echo "$(date +'%H:%M:%S') Device: will try to mount it"                                                       >>$LOGTMP
  sudo --user=$LOCAL_OS_SYS_USER_NAME \
       ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
           "mount $SERVER_MNT_DIR_DEVICE"    >>$LOGTMP 2>&1
  if [ "$?" -eq 0 ]; then
    echo "$(date +'%H:%M:%S') Device: successfully mounted"                                                     >>$LOGTMP
  else
    echo "$(date +'%H:%M:%S') STOP - Unable to mount Servers Backup Device."                                    >>$LOGTMP

    source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"

    exit 1
  fi
fi

# mount if needed
#
if mountpoint --quiet $LOCAL_MNT_DIR_DEVICE; then
  echo "$(date +'%H:%M:%S') Device: already mounted"                                        >>$LOGTMP
else
  mount $LOCAL_MNT_DIR_DEVICE                                                               >>$LOGTMP 2>&1
  if [ $? -ne 0 ]; then
      echo "$(date +'%H:%M:%S') Device: mount failed"                                       >>$LOGTMP
      echo "$(date +'%H:%M:%S') Device: lsblk"                                              >>$LOGTMP
      lsblk                                                                                 >>$LOGTMP
  
      source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"
  
      exit 1
  fi
fi
LOCAL_BACKUP_DEVICE=`findmnt --noheadings --output SOURCE --target $LOCAL_MNT_DIR_DEVICE`
echo "$(date +'%H:%M:%S') Device: mounted $LOCAL_MNT_DIR_DEVICE on $LOCAL_BACKUP_DEVICE"    >>$LOGTMP

# Create rsync.tmp directory with read/write for everyone
#
if [ ! -d "$LOCAL_MNT_DIR_DEVICE/rsync.tmp" ]; then
  mkdir --mode=770 $LOCAL_MNT_DIR_DEVICE/rsync.tmp          >>$LOGTMP 2>&1
  chown root:backup $LOCAL_MNT_DIR_DEVICE/rsync.tmp         >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') Created rsync.tmp directory"    >>$LOGTMP
fi



cd $LOCAL_MNT_DIR_DEVICE/remote           >>$LOGTMP 2>&1
rm --force /tmp/operation_failed.lines    >>$LOGTMP 2>&1



#
# Wait until file "remote.READY" got written onto the backup device (server)
#
REMOTE_HOSTNAME=`sudo --user=$LOCAL_OS_SYS_USER_NAME \
                      ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
                          'echo $HOSTNAME'`                                                >>$LOGTMP 2>&1
READY_FLAG=false
while [ "$READY_FLAG" == "false" ]
do
  sudo --user=$LOCAL_OS_SYS_USER_NAME \
       ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
           [ -f "$SERVER_MNT_DIR_DEVICE/remote.READY" ]                                    >>$LOGTMP 2>&1
  if [ $? -eq 0 ]; then
    READY_FLAG=true
    echo "$(date +'%H:%M:%S') found remote.READY on server $REMOTE_HOSTNAME"               >>$LOGTMP
  else
    echo "$(date +'%H:%M:%S') pause 15 minute, as the server seems to be not ready yet"    >>$LOGTMP
    sleep 15m
  fi
  if [ "$(date +'%y%m%d')" != "$STARTDATE" ]; then
    echo "$(date +'%H:%M:%S') STOP - A day has pasted until the script was started."       >>$LOGTMP

    source $DIR/modules/send_email.sh $LOGTMP "$SUBJECT_ADMIN_PRIO2"

    exit 1
  fi
done # Wait for "remote.READY"



# Create the indicator "remote.in.progress"
#
sudo --user=$LOCAL_OS_SYS_USER_NAME \
     ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
         "touch $SERVER_MNT_DIR_DEVICE/remote.in.progress"    >>$LOGTMP 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: touch $SERVER_MNT_DIR_DEVICE/remote.in.progress"    >>$LOGTMP
  echo "Creation 'remote.FINISHED' on Server"                                                      >> /tmp/operation_failed.lines
fi



# Synchronize the remote directory
#
if [ "$TEST_MODE" == "true" ]; then
  echo "$(date +'%H:%M:%S') rsync: start dry-run"       >>$LOGTMP
  rsync --dry-run \
        --delete \
        --archive \
        --temp-dir=$LOCAL_MNT_DIR_DEVICE/rsync.tmp \
        $SSH_HOST::Backup \
        $LOCAL_MNT_DIR_DEVICE/remote                    >>$LOGTMP 2>&1
else
  echo "$(date +'%H:%M:%S') rsync: start sync"          >>$LOGTMP
  rsync --delete \
        --archive \
        --temp-dir=$LOCAL_MNT_DIR_DEVICE/rsync.tmp \
        $SSH_HOST::Backup \
        $LOCAL_MNT_DIR_DEVICE/remote                    >>$LOGTMP 2>&1
  if [ $? -ne 0 ]; then
    echo"ERROR: rsync ... $LOCAL_MNT_DIR_DEVICE/remote"                    >>$LOGTMP
    echo "Synchronize local copy $LOCAL_MNT_DIR_DEVICE/remote"                                                      >> /tmp/operation_failed.lines
  fi
fi
echo "$(date +'%H:%M:%S') rsync: finished"              >>$LOGTMP



# Remove the indicator "remote.in.progress"
#
sudo --user=$LOCAL_OS_SYS_USER_NAME \
     ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
         "rm $SERVER_MNT_DIR_DEVICE/remote.in.progress"    >>$LOGTMP 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: rm $SERVER_MNT_DIR_DEVICE/remote.in.progress"    >>$LOGTMP
  echo "Delete 'remote.in.progress' on Server"                                                      >> /tmp/operation_failed.lines
fi



# Check for existing todays directory.
#   If found, backup the same.
#   
if [ -d "$LOCAL_MNT_DIR_DEVICE/$STARTDATE" ]; then
  echo "$(date +'%H:%M:%S') Subdirectory $LOCAL_MNT_DIR_DEVICE/$STARTDATE already exists"    >>$LOGTMP
  mv $LOCAL_MNT_DIR_DEVICE/$STARTDATE $LOCAL_MNT_DIR_DEVICE/$STARTDATE_before_$START         >>$LOGTMP 2>&1
  echo "$(date +'%H:%M:%S') renamed to $STARTDATE_before_$START"                             >>$LOGTMP
fi

# Create todays directory
#
mkdir --mode=770 $LOCAL_MNT_DIR_DEVICE/$STARTDATE          >>$LOGTMP 2>&1
chown root:backup $LOCAL_MNT_DIR_DEVICE/$STARTDATE         >>$LOGTMP 2>&1
echo "$(date +'%H:%M:%S') Created $STARTDATE directory"    >>$LOGTMP

# Create a copy of todays remote directory
#
echo "$(date +'%H:%M:%S') remote Directory: create backup"                        >>$LOGTMP
cp --recursive $LOCAL_MNT_DIR_DEVICE/remote/* $LOCAL_MNT_DIR_DEVICE/$STARTDATE    >>$LOGTMP 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: cp ... $LOCAL_MNT_DIR_DEVICE/$STARTDATE"    >>$LOGTMP
  echo "Creation local copy $LOCAL_MNT_DIR_DEVICE/$STARTDATE"                        >> /tmp/operation_failed.lines
fi
echo "$(date +'%H:%M:%S') remote Directory: backup finished"                      >>$LOGTMP

# Files got downloaded => leave host name in file "remote.FINISHED"
#
# added line in the format: <client host name> <server time HH:MM DD Mmm YYYY>
#
sudo --user=$LOCAL_OS_SYS_USER_NAME \
     ssh $SERVER_OS_SYS_USER_NAME@$SSH_HOST \
         "echo $HOSTNAME $STARTTIME_H-$(date +'%H:%M %d %b %Y') >> $SERVER_MNT_DIR_DEVICE/remote.FINISHED"    >>$LOGTMP 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: echo $HOSTNAME $STARTTIME_H-$(date +'%H:%M %d %b %Y') >> $SERVER_MNT_DIR_DEVICE/remote.FINISHED"    >>$LOGTMP
  echo "Update 'remote.FINISHED' on Server"                                                      >> /tmp/operation_failed.lines
fi


# Report Summary of operations
#
if [ -f /tmp/operation_failed.lines ]; then
  echo "Backup failures at"                                                                >> /tmp/summary.txt
  cat /tmp/operation_failed.lines                                                          >> /tmp/summary.txt
else
  echo "Backup OKAY"                                                                       >> /tmp/summary.txt
fi
echo ""                                                                                    >> /tmp/summary.txt

# Predictions of available space for X days
# (backup size vs. available disk space)
#
DU_OUT=`du --human-readable --block-size=1M --max-depth=0 $LOCAL_MNT_DIR_DEVICE/remote`
# sample output:
# 3317  /mnt/backup/250119.bak
aDU_OUT=(${DU_OUT})
declare -i DU_VALUE=${aDU_OUT[0]}
DF_OUT=`df --human-readable --block-size=1M --output=avail $LOCAL_MNT_DIR_DEVICE`
# sample output:
# Avail
# 49950
aDF_OUT=(${DF_OUT})
declare -i DF_VALUE=${aDF_OUT[1]}
echo "Space for additional $((DF_VALUE/DU_VALUE)) backups"                                 >> /tmp/summary.txt
  
# simple du & df output
#
du --human-readable --max-depth=0 $LOCAL_MNT_DIR_DEVICE/remote                             >> /tmp/summary.txt
df --human-readable --output=avail,pcent,target $LOCAL_MNT_DIR_DEVICE                      >> /tmp/summary.txt
echo ""                                                                                    >> /tmp/summary.txt

# switch to home directory
#
cd ~                          >>$LOGTMP 2>&1

# Defined standby, if wanted
#
if [ "$ADDON_HDPARM" == "true" ]; then
  LOCAL_BACKUP_DEVICE=`findmnt --noheadings --output SOURCE --target $MNT_DIR_DEVICE`
  modules/standby_backup_device.sh $ADDON_HDPARM_MINUTES
  if [ $? -eq 0 ]; then
    echo "$LOCAL_BACKUP_DEVICE setting standby to $ADDON_HDPARM_MINUTES minutes"       >>$LOGTMP
  else
    echo "unable to specify standby for $LOCAL_BACKUP_DEVICE"                          >>$LOGTMP
  fi
fi

# Finishing steps of the backup
#
cat /tmp/summary.txt $LOGTMP > /tmp/$STARTDATE.log
rm --force /tmp/summary.txt
rm --force $LOGTMP
cp /tmp/$STARTDATE.log $LOCAL_MNT_DIR_DEVICE/$STARTDATE/$STARTTIME-$(date +'%H%M').log

# Un-mount Local Backup device
#
echo "$(date +'%H:%M:%S') Device: unmount Local Backup Device ..."    >>$LOGTMP
umount $LOCAL_MNT_DIR_DEVICE                                          >>$LOGTMP 2>&1
echo "$(date +'%H:%M:%S') Device: unmount done"                       >>$LOGTMP

# Send log file
# based on information from the summary, the email might be given a predefined priority
#
if [ -f "/tmp/operation_failed.lines" ]; then
  # something about the backup ... lower Prio
  source $DIR/modules/send_email.sh /tmp/$STARTDATE.log "$SUBJECT_ADMIN_PRIO3"
else
  # all fine ... just FYI
  source $DIR/modules/send_email.sh /tmp/$STARTDATE.log
fi 
rm --force /tmp/$STARTDATE.log
rm --force /tmp/operation_failed.lines
