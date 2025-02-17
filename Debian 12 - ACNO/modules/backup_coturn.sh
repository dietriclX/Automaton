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

echo "$(date +'%H:%M:%S') coturn: backup database ..."           >>$LOGTMP

# SQL-Scripts: prepare
#
if [ "$COTURN_DB_HOST" == "localhost" ]; then
  sudo --user=postgres pg_dump --dbname=$COTURN_DB_NAME \
                               --file=$COTURN_DB_NAME.sql        >>$LOGTMP 2>&1
  EXIT_CODE+=$?
else 
  sudo --user=postgres pg_dump --host=$COTURN_DB_HOST \
                               --port=$COTURN_DB_PORT \
                               --username=$POSTGRESQL_ADM \
                               --dbname=$COTURN_DB_NAME \
                               --file=$COTURN_DB_NAME.sql        >>$LOGTMP 2>&1
  EXIT_CODE+=$?
fi
chown root:backup $COTURN_DB_NAME.sql                            >>$LOGTMP 2>&1
EXIT_CODE+=$?
cp /usr/share/coturn/schema.sql coturn_schema.sql                >>$LOGTMP 2>&1
EXIT_CODE+=$?
chown root:backup coturn_schema.sql                              >>$LOGTMP 2>&1
EXIT_CODE+=$?

# SQL-Scripts: files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/$COTURN_DB_NAME.sql
${PWD:1}/coturn_schema.sql
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat /tmp/backup.topic.files >> backup.files

# SQL-Scripts: tar files
#
tar --create \
    --gzip \
    --file=coturn.sql.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') coturn: backup database done"          >>$LOGTMP

echo "$(date +'%H:%M:%S') coturn: backup files ..."              >>$LOGTMP

# files for backup
#
cat << EOF > /tmp/backup.topic.files
lib/systemd/system/coturn.service
etc/turnserver.conf
usr/local/etc/ca.crt
usr/local/etc/server.crt
usr/local/etc/server.key
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=coturn.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                         >>$LOGTMP 2>&1
EXIT_CODE+=$?
echo "$(date +'%H:%M:%S') coturn: backup done"                   >>$LOGTMP



echo "$(date +'%H:%M:%S') coturn: add restore commands ..."      >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                                                    >> $RESTORE_SCRIPT
  echo ''                                                                                    >> $RESTORE_SCRIPT
  echo ''                                                                                    >> $RESTORE_SCRIPT
  echo '#'                                                                                   >> $RESTORE_SCRIPT
  echo '# cotrurn'                                                                           >> $RESTORE_SCRIPT
  echo '#'                                                                                   >> $RESTORE_SCRIPT
  echo 'echo Restore coturn'                                                                 >> $RESTORE_SCRIPT
  echo ''                                                                                    >> $RESTORE_SCRIPT
  echo 'cat << EOF > $DIR/data/create_db_coturn.sql'                                         >> $RESTORE_SCRIPT
  echo 'CREATE DATABASE $COTURN_DB_NAME '                                                    >> $RESTORE_SCRIPT
  echo '                OWNER $COTURN_DB_USER '                                              >> $RESTORE_SCRIPT
  echo '                TEMPLATE template0 '                                                 >> $RESTORE_SCRIPT
  echo '                ENCODING '$'\'UNICODE\' '                                            >> $RESTORE_SCRIPT
  echo '                LC_COLLATE '$'\'$POSTGRESQL_LOCALES\' '                              >> $RESTORE_SCRIPT
  echo '                LC_CTYPE '$'\'$POSTGRESQL_LOCALES\';'                                >> $RESTORE_SCRIPT
  echo 'GRANT ALL privileges ON DATABASE $COTURN_DB_NAME '                                   >> $RESTORE_SCRIPT
  echo '                     TO $COTURN_DB_USER;'                                            >> $RESTORE_SCRIPT
  echo 'EOF'                                                                                 >> $RESTORE_SCRIPT
  echo 'chgrp backup $DIR/data/create_db_coturn.sql'                                         >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                                     >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                        >> $RESTORE_SCRIPT
  echo '    --file=coturn.sql.tar.gz'                                                        >> $RESTORE_SCRIPT
  echo ''                                                                                    >> $RESTORE_SCRIPT
  if [ "$COTURN_DB_HOST" == "localhost" ]; then
    echo 'sudo --user=postgres psql --command="DROP DATABASE IF EXISTS $COTURN_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --file=$DIR/data/create_db_coturn.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --dbname=$COTURN_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --file=$COTURN_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  else
    echo 'sudo --user=postgres psql --host=$COTURN_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$COTURN_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                            >> $RESTORE_SCRIPT
    echo '                          --command="DROP DATABASE IF EXISTS $COTURN_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$COTURN_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$COTURN_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                            >> $RESTORE_SCRIPT
    echo '                          --file=$DIR/data/create_db_coturn.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$COTURN_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$COTURN_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --dbname=$COTURN_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                            >> $RESTORE_SCRIPT
    echo '                          --file=$COTURN_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  fi
  echo 'tar --extract \'                                                                     >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                        >> $RESTORE_SCRIPT
  echo '    --dereference \'                                                                 >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                                 >> $RESTORE_SCRIPT
  echo '    --file=coturn.tar.gz'                                                            >> $RESTORE_SCRIPT
  echo '# Service'                                                                           >> $RESTORE_SCRIPT
  echo 'systemctl daemon-reload'                                                             >> $RESTORE_SCRIPT
  echo 'systemctl enable \'                                                                  >> $RESTORE_SCRIPT
  echo '          --now \'                                                                   >> $RESTORE_SCRIPT
  echo '          coturn'                                                                    >> $RESTORE_SCRIPT
  echo ''                                                                                    >> $RESTORE_SCRIPT
else
  echo 'echo Restore coturn NOT POSSIBLE'                    >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'            >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
