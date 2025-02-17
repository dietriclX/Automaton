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

echo "$(date +'%H:%M:%S') PostgreSQL: backup roles and users ..."    >>$LOGTMP

# SQL-Scripts: prepare
#
if [ "$POSTGRESQL_HOST" == "localhost" ]; then
  sudo --user=postgres pg_dumpall --globals-only \
                                  --file=postgresql.sql              >>$LOGTMP 2>&1
  EXIT_CODE+=$?
else
  sudo --user=postgres pg_dumpall --host=$POSTGRESQL_HOST \
                                  --port=$POSTGRESQL_PORT \
                                  --username=$POSTGRESQL_ADM \
                                  --globals-only \
                                  --file=postgresql.sql              >>$LOGTMP 2>&1
fi
chown root:backup postgresql.sql                                     >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') PostgreSQL: backup done"                   >>$LOGTMP

echo "$(date +'%H:%M:%S') PostgreSQL: backup files ..."              >>$LOGTMP

# files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/postgresql.sql
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat << EOF >> /tmp/backup.topic.files
etc/postgresql/15/main/pg_hba.conf
etc/postgresql/15/main/postgresql.conf
var/lib/postgresql/.pgpass
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=postgresql.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                             >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') PostgreSQL: backup done"                   >>$LOGTMP



echo "$(date +'%H:%M:%S') PostgreSQL: add restore commands ..."      >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                                           >> $RESTORE_SCRIPT
  echo ''                                                                           >> $RESTORE_SCRIPT
  echo ''                                                                           >> $RESTORE_SCRIPT
  echo '#'                                                                          >> $RESTORE_SCRIPT
  echo '# PostgreSQL'                                                               >> $RESTORE_SCRIPT
  echo '#'                                                                          >> $RESTORE_SCRIPT
  echo 'echo Restore PostgreSQL'                                                    >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                            >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                               >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                        >> $RESTORE_SCRIPT
  echo '    --file=postgresql.tar.gz'                                               >> $RESTORE_SCRIPT
  echo '# Service'                                                                  >> $RESTORE_SCRIPT
  echo 'systemctl start \'                                                          >> $RESTORE_SCRIPT
  echo '          postgresql \'                                                     >> $RESTORE_SCRIPT
  echo '          postgresql@15-main'                                               >> $RESTORE_SCRIPT
  if [ "$POSTGRESQL_HOST" == "localhost" ]; then
    echo 'sudo --user=postgres psql --file=$MNT_DIR_DEVICE/today/postgresql.sql'    >> $RESTORE_SCRIPT
  else
    echo 'sudo --user=postgres psql --host=$POSTGRESQL_HOST \'                      >> $RESTORE_SCRIPT
    echo '                          --port=$POSTGRESQL_PORT \'                      >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                   >> $RESTORE_SCRIPT
    echo '                          --file=$MNT_DIR_DEVICE/today/postgresql.sql'    >> $RESTORE_SCRIPT
  fi
  echo ''                                                                           >> $RESTORE_SCRIPT
else
  echo 'echo Restore PostgreSQL NOT POSSIBLE'                                       >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                                   >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
