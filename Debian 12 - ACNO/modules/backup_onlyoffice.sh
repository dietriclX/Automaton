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

echo "$(date +'%H:%M:%S') nginx: backup files ..."                                                     >>$LOGTMP

# nginx: files for backup
#
cat << EOF > /tmp/backup.topic.files
etc/nginx/nginx.conf
EOF
cat /tmp/backup.topic.files >> backup.files

# nginx: tar files
#
tar --create \
    --gzip \
    --file=nginx.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                                                               >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') nginx: backup done"                                                          >>$LOGTMP

echo "$(date +'%H:%M:%S') ONLYOFFICE: backup database ..."                                             >>$LOGTMP

# SQL-Scripts: prepare
#
if [ "$ONLYOFFICE_DB_HOST" == "localhost" ]; then
  sudo --user=postgres pg_dump --dbname=$ONLYOFFICE_DB_NAME \
                               --file=$ONLYOFFICE_DB_NAME.sql                                          >>$LOGTMP 2>&1
  EXIT_CODE+=$?
else 
  sudo --user=postgres pg_dump --host=$ONLYOFFICE_DB_HOST \
                               --port=$ONLYOFFICE_DB_PORT \
                               --username=$POSTGRESQL_ADM \
                               --dbname=$ONLYOFFICE_DB_NAME \
                               --file=$ONLYOFFICE_DB_NAME.sql                                          >>$LOGTMP 2>&1
  EXIT_CODE+=$?
fi
cp $ONLYOFFICE_WEB_DIR/documentserver/server/schema/postgresql/createdb.sql onlyoffice_schema.sql      >>$LOGTMP 2>&1
EXIT_CODE+=$?
chown root:backup $ONLYOFFICE_DB_NAME.sql                                                              >>$LOGTMP 2>&1
EXIT_CODE+=$?
chown root:backup onlyoffice_schema.sql                                                                >>$LOGTMP 2>&1
EXIT_CODE+=$?

# SQL-Scripts: files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/$ONLYOFFICE_DB_NAME.sql
${PWD:1}/onlyoffice_schema.sql
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat /tmp/backup.topic.files >> backup.files

# SQL-Scripts: tar files
#
tar --create \
    --gzip \
    --file=onlyoffice.sql.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                                                               >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') ONLYOFFICE: backup database done"                                            >>$LOGTMP

echo "$(date +'%H:%M:%S') ONLYOFFICE: backup files ..."                                                >>$LOGTMP

# files for backup
#
cat << EOF > /tmp/backup.topic.files
etc/onlyoffice
${ONLYOFFICE_LIB_DIR:1}
${ONLYOFFICE_WEB_DIR:1}
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=onlyoffice.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                                                               >>$LOGTMP 2>&1
EXIT_CODE+=$?
echo "$(date +'%H:%M:%S') ONLYOFFICE: backup done"                                                     >>$LOGTMP



echo "$(date +'%H:%M:%S') ONLYOFFICE: add restore commands ..."                                        >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
#
# restore instructions
#
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo '#'                                                                                       >> $RESTORE_SCRIPT
  echo '# ONLYOFFICE'                                                                            >> $RESTORE_SCRIPT
  echo '#'                                                                                       >> $RESTORE_SCRIPT
  echo 'echo Restore ONLYOFFICE'                                                                 >> $RESTORE_SCRIPT
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo 'cat << EOF > $DIR/data/create_db_onlyoffice.sql'                                         >> $RESTORE_SCRIPT
  echo 'CREATE DATABASE $ONLYOFFICE_DB_NAME '                                                    >> $RESTORE_SCRIPT
  echo '                OWNER $ONLYOFFICE_DB_USER '                                              >> $RESTORE_SCRIPT
  echo '                TEMPLATE template0 '                                                     >> $RESTORE_SCRIPT
  echo '                ENCODING '$'\'UNICODE\' '                                                >> $RESTORE_SCRIPT
  echo '                LC_COLLATE '$'\'$POSTGRESQL_LOCALES\' '                                  >> $RESTORE_SCRIPT
  echo '                LC_CTYPE '$'\'$POSTGRESQL_LOCALES\';'                                    >> $RESTORE_SCRIPT
  echo 'GRANT ALL privileges ON DATABASE $ONLYOFFICE_DB_NAME '                                   >> $RESTORE_SCRIPT
  echo '                     TO $ONLYOFFICE_DB_USER;'                                            >> $RESTORE_SCRIPT
  echo 'EOF'                                                                                     >> $RESTORE_SCRIPT
  echo 'chgrp backup $DIR/data/create_db_onlyoffice.sql'                                         >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                                         >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                            >> $RESTORE_SCRIPT
  echo '    --file=onlyoffice.sql.tar.gz'                                                        >> $RESTORE_SCRIPT
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo 'echo Restore ONLYOFFICE'                                                                 >> $RESTORE_SCRIPT
  if [ "$ONLYOFFICE_DB_HOST" == "localhost" ]; then
    echo 'sudo --user=postgres psql --command="DROP DATABASE IF EXISTS $ONLYOFFICE_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --file=$DIR/data/create_db_onlyoffice.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --dbname=$ONLYOFFICE_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --file=$ONLYOFFICE_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  else
    echo 'sudo --user=postgres psql --host=$ONLYOFFICE_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$ONLYOFFICE_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                                >> $RESTORE_SCRIPT
    echo '                          --command="DROP DATABASE IF EXISTS $ONLYOFFICE_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$ONLYOFFICE_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$ONLYOFFICE_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                                >> $RESTORE_SCRIPT
    echo '                          --file=$DIR/data/create_db_onlyoffice.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$ONLYOFFICE_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$ONLYOFFICE_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --dbname=$ONLYOFFICE_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                                >> $RESTORE_SCRIPT
    echo '                          --file=$ONLYOFFICE_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  fi
  echo 'tar --extract \'                                                                         >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                            >> $RESTORE_SCRIPT
  echo '    --dereference \'                                                                     >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                                     >> $RESTORE_SCRIPT
  echo '    --file=onlyoffice.tar.gz'                                                            >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                                         >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                            >> $RESTORE_SCRIPT
  echo '    --dereference \'                                                                     >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                                     >> $RESTORE_SCRIPT
  echo '    --file=nginx.tar.gz'                                                                 >> $RESTORE_SCRIPT
  echo '# Service'                                                                               >> $RESTORE_SCRIPT
  echo 'systemctl start ds-converter \'                                                          >> $RESTORE_SCRIPT
  echo '                ds-docservice \'                                                         >> $RESTORE_SCRIPT
  echo '                ds-metrics \'                                                            >> $RESTORE_SCRIPT
  echo '                nginx \'                                                                 >> $RESTORE_SCRIPT
  echo '                rabbitmq-server'                                                         >> $RESTORE_SCRIPT
  echo ''                                                                                        >> $RESTORE_SCRIPT
  echo "$(date +'%H:%M:%S') ONLLOFFICE: add restore commands done"    >>$LOGTMP
else
  echo 'echo Restore ONLYOFFICE NOT POSSIBLE'                                                    >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                                                >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
