#!/bin/bash

#
# Turns the Nextcloud Maintenance-Mode ON/OFF.
# Allowed options are "on" and "off".
#
# During Maintenance ...
# If the lighttp Web-Server is setup, it will "replace the Apache Web-Server.
# Lighttp: Serves a single page with HTTP error code 503.
# Apache: Will be shutdown.
#

if [ -z "$DIR" ]; then
  source $(dirname "$0")/modules/defaults_2stdout4scripts.sh
else
  source $DIR/modules/modules/defaults_2stdout4scripts.sh
fi



if [ "$ADDON_LIGHTTP_503" != "true" ]; then
  echo "With option 'aolighttp503ao' not set to 'true', in file(s)"                    >>$LOGTMP 2>&1
  echo "'parameter_value.*.map', the Apache Web-Server status will not be changed."    >>$LOGTMP 2>&1
  echo "With option 'aolighttp503ao' being 'true', Apache would be shutdown and"       >>$LOGTMP 2>&1
  echo "the Lighttp Web-Server would take over and presenting an HTTP error 503"       >>$LOGTMP 2>&1
fi

if [ $# -eq 0 ]; then
  echo "ERROR: Script should have been called with argument 'on' or 'off'."            >>$LOGTMP
elif [ $# -ne 1 ]; then
  echo "ERROR: Script allows only one argument, which can be either 'on' or 'off'."    >>$LOGTMP
elif [ "$1" == "on" ]; then

  sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ maintenance:mode --on                    >>/dev/null 2>>$LOGTMP

  if [ "$ADDON_LIGHTTP_503" == "true" ]; then
    systemctl stop apache2                                                             >>$LOGTMP 2>&1
    touch /tmp/LIGHTTP_MAINTENANCE                                                     >>$LOGTMP 2>&1
    systemctl restart lighttpd                                                         >>$LOGTMP 2>&1
  fi

elif [ "$1" == "off" ]; then

  sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ maintenance:mode --off                   >>/dev/null 2>>$LOGTMP

  if [ "$ADDON_LIGHTTP_503" == "true" ]; then
    rm --force /tmp/LIGHTTP_MAINTENANCE                                                >>$LOGTMP 2>&1
    systemctl restart lighttpd                                                         >>$LOGTMP 2>&1
    systemctl start apache2                                                            >>$LOGTMP 2>&1
  fi

else
  echo "ERROR: Script has been called with neither 'on' nor 'off'."                    >>$LOGTMP
fi
