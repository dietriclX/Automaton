#!/bin/bash

#
# Information will be provided, when script is called with option "-h" or "--help".
#

# directory of script
#
DIR=$(dirname "$(realpath "$0")")

# Temporary files
#
TEMP_FILE_SCRIPT=`mktemp`
TEMP_FILE_TARGET=`mktemp`

# Do not print, if not required.
PRINT_HELP=false

# Wether or not do a test/dry run
DRY_RUN=false

# Default is, file will not be overwritten.
OVERWRITE_TARGET=false

# Mapping files (absolute path)
FILE_DEFAULT=$DIR/data/parameter_value.Default.map
FILE_TYPE=

# sed script file
FILE_SCRIPT=$DIR/data/parameter_value.sed

# Line number of processed lines of map file
declare -i MAP_LINE=0

while [ "${1:0:1}" == "-" ]
do
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    # 1. argument is either "-h" or "--help"
    PRINT_HELP=true
    shift
  elif [ "$1" == "-f" ] || [ "$1" == "--force" ]; then
    # 1. argument is either "-f" or "--force"
    OVERWRITE_TARGET=true
    shift
  elif [ "$1" == "-i" ] && [ "$2" != "" ]; then
    # 1. argument is "-i"
    # 2. argument is <type>
    shift
    FILE_TYPE=$DIR/data/parameter_value.$1.map
    shift
  elif [ "${#1}" -ge 11 ] && [ "${1:0:11}" == "--instance=" ]; then
    # 1. argument is "--instance=<type>"
    FILE_TYPE=$DIR/data/parameter_value.${1:11}.map
    shift
  elif [ "$1" == "-t" ] || [ "$1" == "--test" ]; then
    # 1. argument is either "-t" or "--test"
    DRY_RUN=true
    shift
  else
    # 1. argument is unkown => Error
    echo 'ERROR: incorrect option "'$1'"' >&2
    PRINT_HELP=true
    shift
  fi
done

if [ "$1" == "" ]; then
  echo 'ERROR: no file(s) specified' >&2
  PRINT_HELP=true
elif [ "$2" == "" ]; then
  # Only one argument given, regarding the files
  FILE_SOURCE=$1
  FILE_TARGET=$1
  FILE_BACKUP=$1.org
elif [ "$3" == "" ]; then
  # Two argument given, regarding the files
  FILE_SOURCE=$1
  FILE_BACKUP=$1
  FILE_TARGET=$2
else
  # There is even a third argument given
  echo 'ERROR: too many arguments specified' >&2
  PRINT_HELP=true
fi

if [ "$PRINT_HELP" == "true" ]; then
  # inproper call of script
cat << EOF 
Usage: $(basename "$0") [OPTION] FILE [TARGET FILE]

In FILE search for parameters and replace them by their values.
Either write the result into the same FILE or into TARGET FILE.

  -f, --force                  if an existing backup file exists,
                                 overwrite the file
  -h, --help                   display this help and exit
  -i TYPE, --instance=TYPE     the parameters/values of file
                                 "parameter_value.TYPE.map" 
                                 will be taken into account
  -t, --test                   test/dry run without modifying files

With only FILE specified, a backup is created with name "FILE.org".
  By default, an existing backup file will be not overwritten.
With TARGET FILE specified, the result is written into this file.
  By default, an existing TARGET FILE will be not overwritten.

The parameters get their default values from file "$(basename "$FILE_DEFAULT")".
If instance type is specified, their default values get overwritten by those
specified in file "parameter_value.TYPE.map".

Format of "parameter_value.*.map" file(s) is like on command prompt. The 0.
parameter is the parameter name and the 1. parameter is the value.
- a parameter name starts at first position. At n SPACEs/TABs after the
  parameter name, follows the value
- the shortest allowed form of a parameter/value pair is 7 characters long
  e.g. "aoxao X"
- a value has to be placed between quotes, if it contains a SPACE
- a line with a SPACE/TAB/# at the first position gets ignored
- an empty gets ignored
EOF
  exit 1
fi

# Check if Mapping file(s) exist
#
echo "Default Mapping File: $FILE_DEFAULT"
if [ ! -f "$FILE_DEFAULT" ]; then
  echo 'ERROR: mapping file "'$FILE_DEFAULT'" not found' >&2
  exit 1
fi
if [ ! -z "$FILE_TYPE" ]; then
  echo "Instance-Type specific Mapping File: $FILE_TYPE"
  if [ ! -f "$FILE_TYPE" ]; then
    echo 'ERROR: instance-type mapping file "'$FILE_TYPE'" not found' >&2
    exit 1
  fi
fi

# Check if Source File exists
#
echo "Source File: $FILE_SOURCE"
if [ ! -f "$FILE_SOURCE" ]; then
  echo 'ERROR: source file "'$FILE_SOURCE'" not found' >&2
  exit 1
fi

# Check if Backup/Target File exists
#
if [ "$FILE_SOURCE" == "$FILE_TARGET" ]; then
  # No target file specified => create a backup
  echo "Backup File: $FILE_BACKUP"
  if [ "$OVERWRITE_TARGET" != "true" ] && [ -f "$FILE_BACKUP" ]; then
    # The target file should NOT be overwritten
    # The target file exists
    echo 'ERROR: backup file "'$FILE_BACKUP'" already exists' >&2
    exit 1
  fi
  if [ "$DRY_RUN" != "true" ]; then
    cp $FILE_SOURCE $FILE_BACKUP
  fi
else
  echo "Target File: $FILE_TARGET"
  # The target file was specified => copy source file to target file
  if [ "$OVERWRITE_TARGET" != "true" ] && [ -f "$FILE_TARGET" ]; then
    # The target file should NOT be overwritten
    # The target file exists
    echo 'ERROR: target file "'$FILE_TARGET'" already exists' >&2
    exit 1
  fi
  if [ "$DRY_RUN" != "true" ]; then
    cp $FILE_SOURCE $FILE_TARGET
  fi
fi

# Do we need to prepare a dry run?
#
if [ "$DRY_RUN" == "true" ]; then
  # dry run => no backup, target is $TEMP_FILE_TARGET
  echo "test/dry run, with the result written into $TEMP_FILE_TARGET"
  FILE_TARGET=$TEMP_FILE_TARGET
  cp $FILE_SOURCE $FILE_TARGET
fi

# Generate sed script file
#
rm --force $TEMP_FILE_SCRIPT
# Process the default mapping file.
MAP_LINE=1
cat $FILE_DEFAULT | while read l
do
  if [[ ${#l} -gt 0 ]] && [[ ${l:0:1} != " " ]] &&  [[ ${l:0:1} != "	" ]] && [[ ${l:0:1} != "#" ]]; then
    al=(${l/ / })
    parameter=${al[0]}
    if [ ${#parameter} -ge 5 ] && [ "${parameter:0:2}" == "${parameter: -2}" ]; then
      echo "bla "$l | xargs --max-args=3 sh -c 'printf "s|$1|$2|g\n"' >> $TEMP_FILE_SCRIPT
    else
      echo 'ERROR found in "'$(basename "$FILE_DEFAULT")'" at line '$MAP_LINE': incorrect parameter "'$parameter'"' >&2
      exit 1
    fi
  fi
  MAP_LINE+=1
done

# Process the Instance-Type mapping file, if wanted.
MAP_LINE=1
if [ ! -z "$FILE_TYPE" ]; then
  cat $FILE_TYPE | while read l
  do
    if [[ ${#l} -gt 0 ]] && [[ ${l:0:1} != " " ]] &&  [[ ${l:0:1} != "	" ]] && [[ ${l:0:1} != "#" ]]; then
      al=(${l/ / })
      parameter=${al[0]}
      if [ ${#parameter} -ge 5 ] && [ "${parameter:0:2}" == "${parameter: -2}" ]; then
        # Delete default parameter/value pair.
        sed --in-place --expression="s/^s|$parameter|.*|g$//" $TEMP_FILE_SCRIPT
        # Add Instance-Type specifc parameter/value pair.
        echo "bla "$l | xargs --max-args=3 sh -c 'printf "s|$1|$2|g\n"' >> $TEMP_FILE_SCRIPT
      else
        echo 'ERROR found in "'$(basename "$FILE_TYPE")'" at line '$MAP_LINE': incorrect parameter "'$parameter'"' >&2
        exit 1
      fi
    fi
    MAP_LINE+=1
  done
fi

# Check for SPACE in values.
#
FILES_VALUE_SPACE_ALLOWED=`cat $DIR/data/value_space.allowed`
PARAMETER_SPACE_ALLOWED=( $FILES_VALUE_SPACE_ALLOWED )
cat $TEMP_FILE_SCRIPT | while read l
do
  FOUND_ALLOWED_PARAMETER=false
  lt=${l/ //}
  if [ "$l" != "$lt" ]; then
    PARAMETER_NAME=`echo $l | sed --expression="s/^s|\([a-z0-9@]*\)|.*$/\1/"`
    for p in "${PARAMETER_SPACE_ALLOWED[@]}"
    do
      if [ "$PARAMETER_NAME" == "$p" ]; then
        FOUND_ALLOWED_PARAMETER=true
        break;
      fi
    done
    if [ "$FOUND_ALLOWED_PARAMETER" != "true" ]; then
      echo 'ERROR Parameter $PARAMETER_NAME allows not space in value. See sed script at line '$l'.' >&2
      exit 1
    fi
  fi # value with a space
done

# Remove empty lines and sort the sed script file
sed '/^[[:space:]]*$/d' $TEMP_FILE_SCRIPT | sort --unique > $FILE_SCRIPT
#rm --force $TEMP_FILE_SCRIPT

# Replace placeholders by values using sed script file $FILE_SCRIPT
#
sed --in-place --file=$FILE_SCRIPT $FILE_TARGET
