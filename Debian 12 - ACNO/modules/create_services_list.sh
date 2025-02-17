#!/bin/bash

if [ -z "$DIR" ]; then
  source $(dirname "$0")/defaults_2stdout.sh
else
  source $DIR/modules/defaults_2stdout.sh
fi



# Definition of crucial service and their status at the end (they should have).
#   Relevant for the backup and restore operation.
# File: modules/services_list.dat
# <shutdown order>,<allowed to stop>,<service>,<unit>,<load>,<active>,<sub>
#
cat << EOF > /tmp/services_list.dat
01,no,ssh,loaded,active,running
11,yes,apache2,loaded,active,running
12,yes,php8.2-fpm,loaded,active,running
21,yes,notify_push,loaded,active,running
31,yes,coturn,loaded,active,running
41,yes,nginx,loaded,active,running
42,yes,ds-converter,loaded,active,running
43,yes,ds-metrics,loaded,active,running
44,yes,ds-docservice,loaded,active,running
71,yes,rabbitmq-server,loaded,active,running
81,yes,redis-server,loaded,active,running
91,yes,postgresql@15-main,loaded,active,running
92,yes,postgresql,loaded,active,exited
EOF
if [ "$ADDON_OPENVPN" == "true" ]; then
cat << EOF >> /tmp/services_list.dat
02,no,openvpn-server@server,loaded,active,running
03,no,openvpn,loaded,active,exited
EOF
fi
if [ "$ADDON_LIGHTTP_503" == "true" ]; then
cat << EOF >> /tmp/services_list.dat
04,no,lighttpd,loaded,active,running
EOF
fi

if [ -f "$DIR/modules/services_list.dat" ]; then
  if [ ! `diff $DIR/modules/services_list.dat /tmp/services_list.dat > /dev/null` ]; then
    cp /tmp/services_list.dat $DIR/modules/services_list.dat
  fi  
else
  cp /tmp/services_list.dat $DIR/modules/services_list.dat
fi
rm /tmp/services_list.dat
