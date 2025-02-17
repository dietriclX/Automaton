if [ -z "$DIR" ] && [ -z "$LOGTMP"]; then
  # on newly created files/directories
  # allow only owner (root) and group (backup) full access
  umask 007

  # directory of script
  #
  DIR=$(dirname "$(realpath "$0")")/..

  # set the variables / script in same directory
  #
  source $DIR/variables.sh

  # Set variables for start date/time & log file
  #
  START=$(date +'%y%m%d-%H%M')
  STARTDATE=$(date +'%y%m%d')
  STARTTIME=$(date +'%H%M')

  # script name
  SCRIPTNAME=$(basename "$0")
  SCRIPTNAME=${SCRIPTNAME%.*}

  LOGTMP='/dev/stdout'
fi
