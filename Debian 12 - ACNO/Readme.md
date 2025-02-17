Used in the context of [Notes > Instructions > Debian 12 - ACNO](https://github.com/dietriclX/Notes/tree/ebb679739c662fa7bc3f94251457c137d79347f7/Instructions/Debian%2012%20-%20ACNO)

# To be deployed

| directory | file | ACNO Server Machine | ACNO Remote Backup Unit |
| ---: | :--- | :---: | :---: |
| . | apply.sh | ✓ | ✓ |
| . | check_services.sh | ✓ |  |
| . | download.sh |  | ✓ |
| . | prepare_machine.sh | ✓¹ |  |
| . | check_os_updates.sh | ✓ | ✓ |
| . | maintenance.sh | ✓ |  |
| . | nightly_maintenance.sh | ✓ |  |
| . | services.sh | ✓ |  |
| . | update_nextcloud.sh | ✓ |  |
| data | parameter_value.*.map | ✓ | ✓ |
| data | services.list | ✓ |  |
| data | value_space.allowed | ✓ | ✓ |
| data | variables.ORG.sh | ✓ |  |
| data | variables.remote.ORG.sh |  | ✓ |
| modules | backup_*.sh
| modules | check4OSupdates.sh | ✓ | ✓ |
| modules | create_services_list.sh | ✓ |  |
| modules | defaults_*.sh | ✓ | ✓ |
| modules | remote_backup.sh | ✓ |  |
| modules | send_email.sh | ✓ | ✓ |
| modules | services_*.sh | ✓ |  |
| modules | standby_backup_device.sh | ✓ | ✓ |
| modules | webdav_backup.sh | ✓ |  |

¹ To setup a ACNO machine up from scratch ... just with the latest backup ...