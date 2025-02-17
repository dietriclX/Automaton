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

echo "$(date +'%H:%M:%S') Apache: backup files ..."                  >>$LOGTMP

# create an ACNO specific backup of crontab (www-data)
#
crontab -u www-data -l | \
  ( \
    echo '# --- START OF ACNO SPECIFIC DEFINITIONS --- #'; \
    sed --expression='1,/START OF ACNO SPECIFIC DEFINITIONS/d' \
  ) > crontab.www-data.ACNO
# store the list of enabled modules
# SPACE & "module" are used as a kind of end-marker
apachectl -M | \
  tail --lines=+2 | \
    grep --invert-match --regexp="(static)" | \
      sed --expression="s/^ //" \
          --expression="s/_module (shared)/ module/" | \
        sort > apache.mods-enabled.ORG
EXIT_CODE+=$?
# save the version of the installed php module
grep --no-filename \
     --regexp="LoadModule php_module" \
     /etc/apache2/mods-available/*.load \
  | sed --expression "s/.*\/libphp\(.*\).so$/php\1/" \
      > apache.php_module.name

# files for backup
#
cat << EOF > /tmp/backup.topic.files
${PWD:1}/crontab.www-data.ACNO
${PWD:1}/apache.mods-enabled.ORG
${PWD:1}/apache.php_module.name
EOF
cat /tmp/backup.topic.files >> /tmp/backup.temp.files
cat << EOF >> /tmp/backup.topic.files
etc/apache2/conf-enabled/security.conf
etc/apache2/sites-available
EOF
cat /tmp/backup.topic.files >> backup.files

# tar files
#
tar --create \
    --gzip \
    --file=apache2.tar.gz \
    --directory=/ \
    --files-from=/tmp/backup.topic.files                             >>$LOGTMP 2>&1
EXIT_CODE+=$?

echo "$(date +'%H:%M:%S') Apache: backup done"                       >>$LOGTMP



echo "$(date +'%H:%M:%S') Apache: add restore commands ..."    >>$LOGTMP

if [ $EXIT_CODE -eq 0 ]; then
  #
  # restore instructions
  #
  echo ''                                                                        >> $RESTORE_SCRIPT
  echo ''                                                                        >> $RESTORE_SCRIPT
  echo ''                                                                        >> $RESTORE_SCRIPT
  echo '#'                                                                       >> $RESTORE_SCRIPT
  echo '# Apache'                                                                >> $RESTORE_SCRIPT
  echo '#'                                                                       >> $RESTORE_SCRIPT
  echo 'echo Restore Apache'                                                     >> $RESTORE_SCRIPT
  echo '# html directory gets only an empty index.html'                          >> $RESTORE_SCRIPT
  echo 'rm /var/www/html/*'                                                      >> $RESTORE_SCRIPT
  echo 'touch /var/www/html/index.html'                                          >> $RESTORE_SCRIPT
  echo 'tar --extract \'                                                         >> $RESTORE_SCRIPT
  echo '    --gzip \'                                                            >> $RESTORE_SCRIPT
  echo '    --dereference \'                                                     >> $RESTORE_SCRIPT
  echo '    --directory=/ \'                                                     >> $RESTORE_SCRIPT
  echo '    --file=apache2.tar.gz'                                               >> $RESTORE_SCRIPT
  echo '# save crontab w/o the ACNO part'                                        >> $RESTORE_SCRIPT
  echo 'crontab -u www-data -l | \'                                              >> $RESTORE_SCRIPT
  echo '  sed --quiet \'                                                         >> $RESTORE_SCRIPT
  echo '      --expression="/START OF ACNO SPECIFIC DEFINITIONS/q;p" \'          >> $RESTORE_SCRIPT
  echo '  > crontab.www-data.woACNO'                                             >> $RESTORE_SCRIPT
  echo '# replace existing crontab by .woACNO + .ACNO'                           >> $RESTORE_SCRIPT
  echo 'cat crontab.www-data.woACNO \'                                           >> $RESTORE_SCRIPT
  echo '    crontab.www-data.ACNO \'                                             >> $RESTORE_SCRIPT
  echo '  > crontab.www-data'                                                    >> $RESTORE_SCRIPT
  echo 'crontab -u www-data -r'                                                  >> $RESTORE_SCRIPT
  echo 'crontab -u www-data crontab.www-data'                                    >> $RESTORE_SCRIPT
  echo 'usermod --append --groups redis www-data'                                >> $RESTORE_SCRIPT
  echo '# save list of enabled modules'                                          >> $RESTORE_SCRIPT
  echo 'apachectl -M | \'                                                        >> $RESTORE_SCRIPT
  echo '  tail --lines=+2 | \'                                                   >> $RESTORE_SCRIPT
  echo '    grep --invert-match --regexp="(static)" | \'                         >> $RESTORE_SCRIPT
  echo '      sed --expression="s/^ //" \'                                       >> $RESTORE_SCRIPT
  echo '          --expression="s/_module (shared)/ module/" | \'                >> $RESTORE_SCRIPT
  echo '        sort > apache.mods-enabled.NEW'                                  >> $RESTORE_SCRIPT
  echo '# take the list of modules and disable those'                            >> $RESTORE_SCRIPT
  echo '# which were NOT enabled on the original machine (backup)'               >> $RESTORE_SCRIPT
  echo 'cat apache.mods-enabled.NEW | while read sModule endMarker'              >> $RESTORE_SCRIPT
  echo 'do'                                                                      >> $RESTORE_SCRIPT
  echo '  grep --regexp="^$sModule $endMarker" \'                                >> $RESTORE_SCRIPT
  echo '       apache.mods-enabled.ORG > /dev/null'                              >> $RESTORE_SCRIPT
  echo '  if [ $? -ne 0 ]; then'                                                 >> $RESTORE_SCRIPT
  echo '    # is enabled, but that will be changed'                              >> $RESTORE_SCRIPT
  echo '    if [ "$sModule" == "php" ]; then'                                    >> $RESTORE_SCRIPT
  echo '      # php module is special as the version number is required'         >> $RESTORE_SCRIPT
  echo '      sModule=`cat apache.php_module.name`'                              >> $RESTORE_SCRIPT
  echo '    fi'                                                                  >> $RESTORE_SCRIPT
  echo '    a2dismod $sModule'                                                   >> $RESTORE_SCRIPT
  echo '  fi'                                                                    >> $RESTORE_SCRIPT
  echo 'done'                                                                    >> $RESTORE_SCRIPT
  echo '# take the list of modules from the original machine (backup)'           >> $RESTORE_SCRIPT
  echo '# and enabled those NOT enabled yet'                                     >> $RESTORE_SCRIPT
  echo 'cat apache.mods-enabled.ORG | while read sModule endMarker'              >> $RESTORE_SCRIPT
  echo 'do'                                                                      >> $RESTORE_SCRIPT
  echo '  grep --regexp="^$sModule $endMarker" \'                                >> $RESTORE_SCRIPT
  echo '       apache.mods-enabled.NEW > /dev/null'                              >> $RESTORE_SCRIPT
  echo '  if [ $? -ne 0 ]; then'                                                 >> $RESTORE_SCRIPT
  echo '    # is not yet enabled'                                                >> $RESTORE_SCRIPT
  echo '    if [ "$sModule" == "php" ]; then'                                    >> $RESTORE_SCRIPT
  echo '      # php module is special as the version number is required'         >> $RESTORE_SCRIPT
  echo '      sModule=`cat apache.php_module.name`'                              >> $RESTORE_SCRIPT
  echo '    fi'                                                                  >> $RESTORE_SCRIPT
  echo '    a2enmod $sModule'                                                    >> $RESTORE_SCRIPT
  echo '    if [ $? -ne 0 ]; then'                                               >> $RESTORE_SCRIPT
  echo '      echo "ERROR unable to enable $sModule'                             >> $RESTORE_SCRIPT
  echo '    fi'                                                                  >> $RESTORE_SCRIPT
  echo '  fi'                                                                    >> $RESTORE_SCRIPT
  echo 'done'                                                                    >> $RESTORE_SCRIPT
  echo '# disable the standard web site'                                         >> $RESTORE_SCRIPT
  echo 'a2dissite 000-default'                                                   >> $RESTORE_SCRIPT
  echo '# enable the ACNO site(s)'                                               >> $RESTORE_SCRIPT
  echo 'a2ensite any'                                                            >> $RESTORE_SCRIPT
  echo '# Service'                                                               >> $RESTORE_SCRIPT
  echo 'systemctl start \'                                                       >> $RESTORE_SCRIPT
  echo '          apache2 \'                                                     >> $RESTORE_SCRIPT
  echo '          php8.2-fpm'                                                    >> $RESTORE_SCRIPT
  echo ''                                                                        >> $RESTORE_SCRIPT
else
  echo 'echo Restore Apache NOT POSSIBLE'                                        >> $RESTORE_SCRIPT
  echo 'echo There had been an issue with Backup'                                >> $RESTORE_SCRIPT
fi
(exit $EXIT_CODE)
