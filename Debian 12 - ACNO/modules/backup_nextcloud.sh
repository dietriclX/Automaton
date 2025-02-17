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

echo "$(date +'%H:%M:%S') Nextcloud: backup database ..."                   >>$LOGTMP

# SQL-Scripts: prepare
#
if [ "$NEXTCLOUD_DB_HOST" == "localhost" ]; then
  sudo --user=postgres pg_dump --dbname=$NEXTCLOUD_DB_NAME \
                               --file=$NEXTCLOUD_DB_NAME.sql                >>$LOGTMP 2>&1
  EXIT_CODE+=$?
else 
  sudo --user=postgres pg_dump --host=$NEXTCLOUD_DB_HOST \
                               --port=$NEXTCLOUD_DB_PORT \
                               --username=$POSTGRESQL_ADM \
                               --dbname=$NEXTCLOUD_DB_NAME \
                               --file=$NEXTCLOUD_DB_NAME.sql                >>$LOGTMP 2>&1
  EXIT_CODE+=$?
fi
chown root:backup $NEXTCLOUD_DB_NAME.sql                                    >>$LOGTMP 2>&1
EXIT_CODE+=$?

# SQL-Scripts: files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/$NEXTCLOUD_DB_NAME.sql
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat /tmp/backup.topic.files >> backup.files

# SQL-Scripts: tar files
#
tar --create \
    --gzip \
    --file=nextcloud.sql.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                                    >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') Nextcloud: backup database done"                  >>$LOGTMP

echo "$(date +'%H:%M:%S') Nextcloud: backup files ..."                      >>$LOGTMP

# files for backup
#
cat << EOF > /tmp/backup.topic.files
etc/systemd/system/notify_push.service
etc/systemd/system/multi-user.target.wants/notify_push.service
${NEXTCLOUD_WEB_DIR:1}
${NEXTCLOUD_DATA_DIR:1}
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=nextcloud.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                                    >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') Nextcloud: backup done"                           >>$LOGTMP



echo "$(date +'%H:%M:%S') Nextcloud: add restore commands ..."              >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                                                       >> $RESTORE_SCRIPT
  echo ''                                                                                       >> $RESTORE_SCRIPT
  echo ''                                                                                       >> $RESTORE_SCRIPT
  echo '#'                                                                                      >> $RESTORE_SCRIPT
  echo '# Nextcloud'                                                                            >> $RESTORE_SCRIPT
  echo '#'                                                                                      >> $RESTORE_SCRIPT
  echo 'echo Restore Nextcloud'                                                                 >> $RESTORE_SCRIPT
  echo ''                                                                                       >> $RESTORE_SCRIPT
  echo 'cat << EOF > $DIR/data/create_db_nextcloud.sql'                                         >> $RESTORE_SCRIPT
  echo 'CREATE DATABASE $NEXTCLOUD_DB_NAME '                                                    >> $RESTORE_SCRIPT
  echo '                OWNER $NEXTCLOUD_DB_USER '                                              >> $RESTORE_SCRIPT
  echo '                TEMPLATE template0 '                                                    >> $RESTORE_SCRIPT
  echo '                ENCODING '$'\'UNICODE\' '                                               >> $RESTORE_SCRIPT
  echo '                LC_COLLATE '$'\'$POSTGRESQL_LOCALES\' '                                 >> $RESTORE_SCRIPT
  echo '                LC_CTYPE '$'\'$POSTGRESQL_LOCALES\';'                                   >> $RESTORE_SCRIPT
  echo 'GRANT ALL PRIVILEGES ON DATABASE $NEXTCLOUD_DB_NAME '                                   >> $RESTORE_SCRIPT
  echo '                     TO $NEXTCLOUD_DB_USER;'                                            >> $RESTORE_SCRIPT
  echo 'EOF'                                                                                    >> $RESTORE_SCRIPT
  echo 'chgrp backup $DIR/data/create_db_nextcloud.sql'                                         >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                                        >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                           >> $RESTORE_SCRIPT
  echo '    --file=nextcloud.sql.tar.gz'                                                        >> $RESTORE_SCRIPT
  echo ''                                                                                       >> $RESTORE_SCRIPT
  if [ "$NEXTCLOUD_DB_HOST" == "localhost" ]; then
    echo 'sudo --user=postgres psql --command="DROP DATABASE IF EXISTS $NEXTCLOUD_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --file=$DIR/data/create_db_nextcloud.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --dbname=$NEXTCLOUD_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --file=$NEXTCLOUD_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  else
    echo 'sudo --user=postgres psql --host=$NEXTCLOUD_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$NEXTCLOUD_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                               >> $RESTORE_SCRIPT
    echo '                          --command="DROP DATABASE IF EXISTS $NEXTCLOUD_DB_NAME;"'    >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$NEXTCLOUD_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$NEXTCLOUD_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                               >> $RESTORE_SCRIPT
    echo '                          --file=$DIR/data/create_db_nextcloud.sql'                   >> $RESTORE_SCRIPT
    echo 'sudo --user=postgres psql --host=$NEXTCLOUD_DB_HOST \'                                >> $RESTORE_SCRIPT
    echo '                          --port=$NEXTCLOUD_DB_PORT \'                                >> $RESTORE_SCRIPT
    echo '                          --dbname=$NEXTCLOUD_DB_NAME \'                              >> $RESTORE_SCRIPT
    echo '                          --username=$POSTGRESQL_ADM \'                               >> $RESTORE_SCRIPT
    echo '                          --file=$NEXTCLOUD_DB_NAME.sql'                              >> $RESTORE_SCRIPT
  fi
  echo 'tar --extract \'                                                                        >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                                           >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                                    >> $RESTORE_SCRIPT
  echo '    --file=nextcloud.tar.gz'                                                            >> $RESTORE_SCRIPT
  echo '# Service (notify_push)'                                                                >> $RESTORE_SCRIPT
  echo 'systemctl daemon-reload'                                                                >> $RESTORE_SCRIPT
  echo 'systemctl enable \'                                                                     >> $RESTORE_SCRIPT
  echo '          --now \'                                                                      >> $RESTORE_SCRIPT
  echo '          notify_push'                                                                  >> $RESTORE_SCRIPT
  echo ''                                                                                       >> $RESTORE_SCRIPT
else
  echo 'echo Restore Nextcloud NOT POSSIBLE'                                                    >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                                               >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
