#!/bin/bash

#
# General operations on the ACNO related services.
# - Checks all relevant services, if they are up and running ... or not.
# - Start all or only a few services
# - Stop all or only a few services
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/modules/defaults_2files4scripts.sh
else
  source $DIR/modules/defaults_2files4scripts.sh
fi



# Definition of crucial service and their status at the end (they should have).
#   Relevant for the backup and restore operation.
source $DIR/modules/create_services_list.sh
ALL_SERVICES=(`sort $DIR/modules/services_list.dat | cut --delimiter=, --fields=3`)
ALL_ALLOWED_SERVICES=(`grep --regexp='^[^,]*,yes' $DIR/modules/services_list.dat| sort | cut --delimiter=, --fields=3`)
ALL_ALLOWED_SERVICES_REVERSE=(`grep --regexp='^[^,]*,yes' $DIR/modules/services_list.dat| sort --reverse | cut --delimiter=, --fields=3`)

bPrintHelp=false
sScriptMode=none
declare -a aExcludedServices

while [ "${1:0:1}" == "-" ]
do
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    # 1. argument is either "-h" or "--help"
    bPrintHelp=true
    shift
  elif [ "$1" == "-c" ] || [ "$1" == "--check" ]; then
    # 1. argument is either "-c" or "--check"
    if [ "$sScriptMode" == "none" ]; then
      sScriptMode=check
      aModeSpecificServices=("${ALL_SERVICES[@]}")
      shift
    else
      echo "ERROR: more than one operation specified with $1" >&2
      bPrintHelp=true
      shift $#
    fi
  elif [ "$1" == "-d" ] || [ "$1" == "--down" ]; then
    # 1. argument is either "-d" or "--down"
    if [ "$sScriptMode" == "none" ]; then
      sScriptMode=stop
      aModeSpecificServices=("${ALL_ALLOWED_SERVICES[@]}")
      shift
    else
      echo "ERROR: more than one operation specified with $1" >&2
      bPrintHelp=true
      shift $#
    fi
  elif [ "$1" == "-e" ] && [ ${#2} -ne 0 ] && [ "$2" != "-" ]; then
    # 1. argument is "-e"
    # 2. argument is "SERVICE"
    shift
    aExcludedService+=("$1")
    shift
  elif [ "${1:0:10}" == "--exclude=" ] && [ ${#1} -gt 10 ]; then
    # 1. argument is "--exclude=SERVICE"
    aExcludedService+=("${1:10}")
    shift
  elif [ "$1" == "-l" ] || [ "$1" == "--list" ]; then
    # 1. argument is either "-l" or "--list"
    if [ "$sScriptMode" == "none" ]; then
      sScriptMode=list
      shift
    else
      echo "ERROR: more than one operation specified with $1" >&2
      bPrintHelp=true
      shift $#
    fi
  elif [ "$1" == "-u" ] || [ "$1" == "--up" ]; then
    # 1. argument is either "-u" or "--up"
    if [ "$sScriptMode" == "none" ]; then
      sScriptMode=start
      aModeSpecificServices=("${ALL_ALLOWED_SERVICES_REVERSE[@]}")
      shift
    else
      echo "ERROR: more than one operation specified with $1" >&2
      bPrintHelp=true
      shift $#
    fi
  else
    # 1. argument is unkown => Error
    echo "ERROR: incorrect option $1" >&2
    bPrintHelp=true
    shift
  fi
done

if [ "$sScriptMode" == "none" ]; then
  sScriptMode=check
  aModeSpecificServices=("${ALL_SERVICES[@]}")
fi

if [ "$bPrintHelp" == true ]; then
  # inproper call of script
  cat << EOF 
Usage: $(basename "$0") [OPTION] [SERVICE] ...

Apply the - in OPTION - specified operation on the SERVICE(s).

The list of services can be specified, after the OPTION(s). Alternatively for
applying the operation to all services, either specify no SERVICE or use key
key word "ALL".

In case no OPTION is specified, the script will run as "-c" or "--check" was
given.

  -c, --check                      verify if the services are in the expected
                                   state

  -d, --down                       shut down the services

  -e SERVICE, --exclude=SERVICE    the specified SERVICE should be excluded
                                   from the service list
                                   option can be used more than once
                                   only used in combination with "ALL" or
                                   no service specified after [OPTION]

  -h, --help                       display this help and exit

  -l, --list                       list all registered services
                                   listed and excluded services get ignored

  -u, --up                         start up the services

The services will be started/stopped in the logical order.
Shut down: 1. application, 2. database
 Start up: 1. database, 2. application
EOF
  exit 1
fi

if [ "$sScriptMode" != "list" ] && [ ${#aExcludedService[@]} -gt 0 ]; then

  # Check the excluded services
  #
  for e in "${aExcludedService[@]}"
  do
    # Check if the service name is known/allowed
    #
    declare bFound=false
    for s in "${aModeSpecificServices[@]}"
    do
      if [ "$e" == "$s" ]; then
        bFound=true
        break
      fi
    done
    if [ "$bFound" != true ]; then
      echo "ERROR: excluded service $e is unknown or not allowed" >&2
      exit 1
    fi
  done

fi # loop through excluded services

if [ "$sScriptMode" != "list" ]; then

  if [ "$1" = "" ] || [ "$1" = "ALL" ]; then

    # Either no SERVICE specified or
    #        "ALL" for all services specified
    #

    declare -a aServiceList
    for s in "${aModeSpecificServices[@]}"
    do

      # Add only those services, which should not be excluded from the list
      #
      declare bFound=false
      for e in "${aExcludedService[@]}"
      do
        if [ "$s" == "$e" ]; then
          bFound=true
          break
        fi
      done
      if [ "$bFound" != true ]; then
        aServiceList+=("$s")
      fi

    done # loop through mode specific services

  else

    if [ ${#aExcludedService[@]} -gt 0 ]; then
      echo "ERROR: excluding services is not permitted, if services are explicitly listed" >&2
      echo "       the exclude opption is allowed, if no specific service is given"        >&2
      exit 1
    fi

    # List of SERVICE(s) provided
    #

    # Variable to be passed on to the specific sub-script
    #
    declare -a aServiceList

    # Variable with specified SERVICE(s) as argument(s) of the script
    #
    declare -a aSpecifiedServices

    # Loop through the arguments after [OPTION]
    #
    while [ "$1" != "" ]
    do

      # Check if the service name is known/allowed
      #
      declare bFound=false
      for s in "${aModeSpecificServices[@]}"
      do
        if [ "$1" == "$s" ]; then
          bFound=true
          break
        fi
      done
      if [ "$bFound" != true ]; then
        echo "ERROR: unknown or not allowed service $1" >&2
        exit 1
      fi

      aSpecifiedServices+=("$1")

      shift

    done

    # Put the named services in the correct order
    # "correct order" in the context of the give operation
    #
    for s in "${aModeSpecificServices[@]}"
    do
      for g in "${aSpecifiedServices[@]}"
      do
        if [ "$s" == "$g" ]; then
          aServiceList+=("$g")
          break
        fi
      done
    done

  fi # if [ "$1" = "" ] || [ "$1" = "ALL" ]; then

fi # if [ "$sScriptMode" != "list" ] 

if [ "$sScriptMode" == "start" ]; then
  source $DIR/modules/services_start.sh ${aServiceList[@]}
elif [ "$sScriptMode" == "stop" ]; then
  source $DIR/modules/services_stop.sh ${aServiceList[@]}
elif [ "$sScriptMode" == "check" ]; then
  source $DIR/modules/services_check.sh ${aServiceList[@]}
else
  echo "Maintained Services"
  for s in "${ALL_SERVICES[@]}"
  do
    echo "- $s"
  done
fi
