#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2stdout.sh
else
  source $DIR/modules/defaults_2stdout.sh
fi



apt list upgradeable |& grep -Ev '^(Listing|WARNING)'    >>$LOGTMP
