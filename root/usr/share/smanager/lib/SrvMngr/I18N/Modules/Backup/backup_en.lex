# 'bac_No suitable local devices found' => 'No suitable local devices found',
'bac_BACKUP_TITLE' => 'Backup or restore server data',
'bac_BACKUP_DESC_DAR' => '<P>Three ways are provided to back up and restore your 
server: using a tape drive, using a network share or a local 
removable disk, or using your local desktop.</P>
<P>Tape Backup. This method uses a software package called <I>[_1]</I>
to back up your entire hard disk to tape every night. This requires a
supported tape drive and a tape that is not write-protected. The backup
is performed automatically at the selected time every night (with a
reminder automatically e-mailed to the administrator during the day).
Currently your hard disk contains <b>[_2]</b> of data.</P>
<P>Workstation backup. This method uses a software package called <I>dar</I>
to back up your server configuration and data files to a network share 
or a local removable disk such as a USB disk. 
You can manage how many rotating sets of backups are kept,
and how many incremental backups to have in each set. 
The backup is performed automatically at the selected time every day. Currently 
configuration and data files total approximately <b>[_3]</b> uncompressed.
Twice the compressed data size must be available on the backup share.</P>
<P>Backup to Desktop. This method creates a copy of your server 
configuration and user data files, and downloads it to your 
local desktop via your web browser.
Currently your configuration and data files total approximately
<b>[_3]</b>. The backup file will be somewhat less than this,
depending on how much the data can be compressed. 
This file can be used to restore the server from the console if you 
copy it to a local removable disk such as a USB disk.</P>
<P>All backup methods allow you to restore your configuration and user
data files. Workstation backup provides individual file restore. <b>Ideally, 
full restore should be performed on a freshly installed server</b>.</P>',
'bac_BACKUP_CONFIG_STATUS' => 'Backup configuration and status',
'bac_BACKUPS_RUN_AT' => 'Regular tape backups will run at: ',
'bac_REMINDER_MESSAGE_AT' => 'Reminder messages will be sent at: ',
'bac_TAPE_BACKUPS' => 'Tape backups are ',
'bac_DESKTOP_BACKUP' => 'Backup to desktop',
# 'bac_DESKTOP_RESTORE' => 'Restore from desktop',
# 'bac_DESKTOP_VERIFY' => 'Verify desktop backup file',
'bac_TAPE_CONFIGURE' => 'Configure tape backup',
'bac_TAPE_RESTORE' => 'Restore from tape',
# 'bac_RESTORE_IN_PROGRESS_BEGAN_AT' => 'A system restore is in progress. It began at: ',
# 'bac_REFRESH_THIS_DISPLAY' => 'Refresh this display',
# 'bac_CONFIGURE_TAPE_BACKUP' => 'Configure tape backup',
# 'bac_RESTORE_COMPLETED' => 'A system restore has completed',
# 'bac_STARTED_AT' => 'It began at: ',
# 'bac_FINISHED_AT' => 'and finished at: ',
# 'bac_YOU_MUST_REBOOT' => 'You must reboot the server to activate any configuration changes that were
# made as a result of this restore.',
# 'bac_REBOOT' => 'Reboot',
'bac_SELECT_AN_ACTION' => 'Select an action',
# 'bac_X_BACKUP_OR_RESTORE' => 'X Backup or restore server data',
# 'bac_ERR_PRE_BACKUP' => 'Error occurred during pre-backup actions.',
'bac_ERR_PRE_RESTORE' => 'Error occurred during pre-restore actions.',
# 'bac_ERR_POST_BACKUP' => 'Error occurred during post-backup actions.',
# 'bac_RESTORE_SERVER_CONFIG' => 'Restore server configuration',
# 'bac_DESKTOP_RESTORE_DESC' => 'This process will upload a server backup file from your local desktop to your server and restore the configuration and user data files. <B>The restore should be performed on a freshly installed server</B>.',
# 'bac_FREE_SPACE' => 'You have approximately [_1] free space on the server.
# Check that desktop backup file is less than [_2] before
# commencing the restore.',
# 'bac_MUST_REBOOT_AFTER_RESTORE' => 'After the restore completes you must reboot the server.',
# 'bac_FILE_TO_RESTORE' => 'Backup file to restore from',
# 'bac_VERIFY_BACKUP_DESC' => '
# <p>This option will display the names of all files
# in a previously created desktop backup file. You
# can use this option to verify the contents of the
# backup file.</p> ',
# 'bac_SELECT_BACKUP_FILE' => 'Select backup file',
# 'bac_VERIFY' => 'Verify',
'bac_RESTORE_CANNOT_PROCEED' => 'Unable to proceed with restore of server configuration',
'bac_ANOTHER_RESTORE_IN_PROGRESS' => 'Another restore is in progress. Please try again later.',
# 'bac_RESTORE_IN_PROGRESS' => 'Restore in progress',
# 'bac_RESTORE_IN_PROGRESS_DESC' => 'After the restore completes you must reboot the server. Your restore is
# complete when the words "Restore complete" appear at the bottom of your screen.
# ',
'bac_FILES_HAVE_BEEN_RESTORED' => 'The following files and directories have been restored:',
'bac_RESTORE_FAILED_MSG' => 'Restore failed! There was an error in reading the backup file.',
'bac_RESTORE_COMPLETE' => 'Restore complete',
'bac_ERR_RESTORING_GID' => 'Error occurred while restoring gid of \'www\'',
'bac_ERR_RESTORING_INITIAL_GRP' => 'Error occurred while restoring initial group of \'www\'.',
'bac_RESTORE_FAILED' => 'Restore failed! The backup file was incomplete.',
# 'bac_COULD_NOT_EXEC_PIPELINE' => 'Could not execute backup pipeline: ',
# 'bac_COULD_NOT_DECODE' => 'Could not decode backup file: ',
'bac_FILES_IN_BACKUP' => 'The following files are considered in the backup :',
'bac_VERIFY_COMPLETE' => 'Verification is complete',
'bac_BACKUP_FILE_INCOMPLETE' => 'The backup file was incomplete',
# 'bac_ERR_READING_FILE' => 'There was an error in reading the backup file.',
# 'bac_ENABLE_DISABLE_TAPE' => 'Enable/Disable Nightly Tape Backup',
# 'bac_TAPE_CONFIG_DESC' => '<p>Select whether you wish to enable nightly backups. Then indicate the
# desired times for the backup and the load tape reminder.</p> <p>The tape
# backup requires a supported tape drive. A warning message will be sent to
# the administrator at the designated reminder time if the tape drive is
# empty.</p>',
# 'bac_ENABLE_TAPE_BACKUP' => 'Enable tape backup',
# 'bac_TAPE_BACKUP_TIME' => 'Tape backup time of day (hour/min)',
# 'bac_LOAD_TAPE_REMINDER_TIME' => 'Load tape reminder time of day (hour/min)',
# 'bac_AM/PM' => 'AM/PM',
# 'bac_AM' => 'AM',
# 'bac_PM' => 'PM',
# 'bac_UPDATE_CONF' => 'Update',
# 'bac_UPDATING_TAPE_CONF' => 'Updating tape backup configuration',
'bac_ERR_INVALID_HOUR' => 'Error: invalid backup hour: ',
'bac_BETWEEN_0_AND_12' => 'Please choose an hour between 0 and 12.',
'bac_ERR_INVALID_MINUTE' => 'Error: invalid backup minute: ',
'bac_BETWEEN_0_AND_59' => 'Please choose a minute between 0 and 59.',
'bac_ERR_INVALID_REMINDER_HOUR' => 'Error: invalid reminder hour: ',
'bac_ERR_INVALID_REMINDER_MINUTE' => 'Error: invalid reminder minute: ',
'bac_ERR_CONF_BACKUP' => 'Error occurred during conf-backup event.',
'bac_SUCCESSFULLY_ENABLED_TAPE' => 'Successfully enabled tape backups',
'bac_WITH_BACKUP_TIME' => 'with backup time: ',
'bac_WITH_REMINDER_TIME' => 'and load tape reminder time: ',
'bac_SUCCESSFULLY_DISABLED' => 'Successfully disabled tape backups',
# 'bac_RESTORE_CONF_FROM_TAPE' => 'Restore server configuration from tape backup',
# 'bac_RESTORE_CONF_FROM_TAPE_DESC' => '<P>This process will restore the configuration and user data files from a
# server tape backup. <B>The restore should be performed on a freshly installed server</B>.</P>
# <P>Ensure that you have loaded the desired backup tape into the tape drive
# before proceeding.</P>
# <P>After the restore completes you must reboot the server.</P>',
# 'bac_RESTORE_FROM_TAPE' => 'Restore From Tape',
'bac_UNABLE_TO_RESTORE_CONF' => 'Unable to restore server configuration',
# 'bac_RESTORING_FROM_TAPE' => 'Restoring From Tape',
# 'bac_NOW_RESTORING_FROM_TAPE' => 'Your server configuration and user data
# files are now being restored from tape.',
'bac_ERR_RESTORING_FROM_TAPE' => 'Error occurred restoring files from tape.',
'bac_ERR_UPDATING_CONF_AFTER_TAPE_RESTORE' => 'Error occurred while updating system configuration after tape 
restore.',
'bac_COULD_NOT_FORK' => 'Could not fork: ',
'bac_SERVER_REBOOT' => 'Server reboot',
'bac_SERVER_WILL_REBOOT' => 'Your server will now reboot.',
'bac_NO_UID_FOR_NAME' => 'Could not get uid for user named: ',
# 'bac_PAGE_REFRESH_IN' => 'This page will refresh to the status display in [_1] seconds, or
# click <a href="/server-manager/cgi-bin/backup">here</a>.',
'Backup or restore' => 'Backup or restore',
'bac_BACKUP_DESKTOP_TOO_BIG' => 'Your server has too much data for a reliable backup to desktop.',
'bac_WORKSTN_BACKUPS' => 'Workstation backups are ',
'bac_WKBACKUPS_RUN_AT' => 'Regular workstation backups will run at: ',
'bac_WORKSTN_CONFIGURE' => 'Configure workstation backup',
'bac_WORKSTN_VERIFY' => 'Verify workstation backup',
'bac_WORKSTN_RESTORE' => 'Restore from workstation',
# 'bac_CONFIGURE_WORKSTN_BACKUP' => 'Configure Workstation Backup',
# 'bac_ENABLE_DISABLE_WORKSTN' => 'Enable/Disable Daily Workstation Backup',
# 'bac_ENABLE_WORKSTN_BACKUP' => 'Enable Workstation Backup',
# 'bac_WORKSTN_BACKUP_TIME' => 'Workstation backup time of day (hour/min)',
# 'bac_UPDATING_WORKSTN_CONF' => 'Updating workstation backup configuration',
'bac_SUCCESSFULLY_ENABLED_WORKSTN' => 'Successfully enabled workstation backups',
'bac_SUCCESSFULLY_DISABLED_WORKSTN' => 'Successfully disabled workstation backups',
# 'bac_VERIFY_WORKSTN_BACKUP_FILE' => 'Verify workstation backup',
# 'bac_VERIFY_WORKSTN_BACKUP_DESC' => '<p>This option will display the names of all files
# in a previously created workstation daily backup. You
# can use this option to verify the contents of the
# backup.<b>You must choose the backup you want to verify</b></p>
# <p>Only files flagged with (Saved)  are contained in the backup.</p>
# <br/>Backup files are verified from shared folder :',
# 'bac_RESTORE_CONF_FROM_WORKSTN' => 'Restore server configuration from workstation backup',
# 'bac_RESTORE_CONF_FROM_WORKSTN_DESC' => '<p>This process will restore the configuration and user data files from a
# Server workstation backup. <b>The restore
# should be performed on a freshly installed Server</b>.</p>
# <p>Ensure that choose the right backup to restore below
# before proceeding.</p>
# <p>After the restore completes you must reboot the server.</p>
# Backup will be restored from : ',
# 'bac_RESTORE_FROM_WORKSTN' => 'Restore From Workstation',
# 'bac_RESTORING_FROM_WORKSTN' => 'Restoring From Workstation',
# 'bac_NOW_RESTORING_FROM_WORKSTN' => 'Your server configuration and user data
# files are now being restored from workstation shared folder.',
# 'bac_ERR_RESTORING_FROM_WORKSTN' => 'Error occurred restoring files from workstation.',
# 'bac_ERR_UPDATING_CONF_AFTER_WORKSTN_RESTORE' => 'Error occurred while updating system configuration after workstation 
# restore.',
# 'bac_WORKSTN_NAME' => 'Workstation IP or hostname',
# 'bac_WORKSTN_BACKUP_SETTINGS' => 'Workstation Backup Settings',
# 'bac_SHARED_FOLDER_NAME' => 'Backup share',
# 'bac_WORKSTN_LOGIN' => 'Login name',
# 'bac_WORKSTATION_BACKUP_DEST' => 'Backup workstation settings',
# 'bac_CONFIGURE_WORKSTN_BACKUP_DESC' => 'You can set the number of 
# successive backup sets to keep on the workstation, with automatic rotation. 
# Each set may contain saved data for several consecutive days.
# In this case first backup of the set is full backup, others daily backups are 
# incremental. You can also set a time limit for each backup session or for incremental 
# backups only. When this limit occurs, backup is cleanly stopped and the next 
# incremental backup will safely continue with unsaved and modified datas.',
'bac_ERR_INVALID_WORKSTN' => 'Invalid Workstation IP or Hostname ',
'bac_ERR_INVALID_FOLDER' => 'Invalid share name',
'bac_ERR_INVALID_LOGIN' => 'Invalid Login',
'bac_ERR_INVALID_PASSWORD' => 'Invalid Password',
'bac_ERR_ALREADY_MOUNTED' => 'Backup directory is already mounted',
'bac_ERR_MOUNTING_SMBSHARE' => 'Unable to mount workstation shared folder',
'bac_ERR_NOT_MOUNTED' => 'Backup directory is not mounted',
# 'bac_WORKSTN_NOT_SET' => 'You must first correctly configure your workstation backup',
# 'bac_NO_BACKUPS_TO_RESTORE' => 'There is no backup set on configured workstation shared folder. Verify your configuration settings.',
# 'bac_NUMBER_OF_SETS' => 'Number of rotating backup sets',
# 'bac_NUMBER_OF_FILES_IN_SET' => 'Daily backups in each set',
# 'bac_ERR_INVALID_SETS_NUMBER' => 'Sets number must be 1 or greater',
'bac_ERR_INVALID_FILES_IN_SET_NUMBER' => 'This number must be 1 or greater. First backup in set is <b>full</b> others are <b>incrementals</b>',
# 'bac_WORKSTN_TIMEOUT' => 'Optional backup session timeout (hours)',
# 'bac_INC_ONLY_TIMEOUT' => 'Don\'t timeout full backup sessions',
'bac_ERR_INVALID_TIMEOUT' => 'Maximum backup time must be set between 1 and 24 hours',
'bac_ERR_NO_HOST_DIR' => 'No directory for your host in shared folder. Maybe your host name is different from backup ones',
'bac_ERROR_READING_FILE' => 'Error while reading files from',
'bac_WORKSTN_SEL_RESTORE' => 'Selective file restore from workstation',
# 'bac_WORKSTN_SELECTIVE_RESTORE' => 'Workstation selective file restore',
'bac_ALL_BACKUPS' => 'All backups',
# 'bac_WORKSTN_SEL_REST_DESC' => 'This process will restore only specified files and directories. You must first choose 
# the backup from which the files will be restored. If you don\'t know in which backup 
# are the required files, you can select \'All backups\' option. <br/><br/>
# The next panel will display available files and directories\, 
# so you can choose the ones to restore. To restrict the number of files and directories 
# displayed in this panel, you have the option to give now a filtering expression, 
# applied as a regular expression to the displayed names.<br/><br/>
# You have the responsibility not to restore files which could break the
# functioning of your server.<br/> <br/>Currently, files will be restored from :',
# 'bac_BACKUP_CHOICE' => 'Selecting files to display',
# 'bac_SELECT_DATE_BEFORE' => 'Restore most recent before',
# 'bac_FILTER_EXPRESSION' => 'Names filtered by',
'bac_READ_COMPLETE' => 'You can choose all the directories and files you want to restore in the displayed list 
(use ctrl or shift for multiple selection). <br/> <b>Warning :</b> If you select a directory, 
all contained files and directories will be restored.<p/>
By default the most recent version of selected files is restored, but if you specify a date 
in the format <i>~[~[~[yyyy/~]mm/~]dd-~]hh:mm~[:ss~]</i> the process 
will restore only the most recent version modified <b>before the given date</b>.',
'bac_ERR_INVALID_SELDATE' => 'Date format is invalid, must be ~[~[~[yyyy/~]mm/~]dd-~]hh:mm~[:ss~]. ie: 2005/12/31-08:23:32 or 
10-08:32 or 08:32',
# 'bac_SELECT_FILES_TO_RESTORE' => 'Select files to restore',
'bac_ERR_WHILE_UNMOUNTING' => 'Error occurs when unmounting distant share',
# 'bac_ERR_DAR_CATALOG' => 'Error when using Dar catalog',
# 'bac_COMPRESSION_LEVEL' => 'Backup compression level ~[0-9~]',
# 'bac_FULL_ONLY_ON' => 'Full backup is allowed on',
'bac_ERR_INVALID_COMPRESSION' => 'Compression level must be set between 0 (no compression) and 9 (maximum compression)',
'bac_DOW' => 'Sunday Monday Tuesday Wednesday Thursday Friday Saturday Everyday',
# 'bac_CONFIGURATION_TO_BE_DONE' => 'Please configure the backup settings.',
# 'bac_WORKSTN_BACKUP_DESC' => '<p>This panel displays the present workstation backup configuration. You can 
# change it in this panel and the next one.</p><p/>',
'bac_WORKSTN_BACKUP_NOT_CONFIGURED' => '<p>Presently, workstation backup is not configured. You can set this configuration
with this panel and the next one.</p><p/>',
# 'bac_WORKSTN_BACKUP_ENABLED' => 'Backup is ',
'bac_WORKSTN_BACKUP_USB' => 'Backup is made on local removable disk',
'bac_WORKSTN_BACKUP_MNT' => 'Backup is made on mounted disk',
'bac_WORKSTN_BACKUP_HOST' => 'Backup is made on LAN workstation ',
'bac_WORKSTN_BACKUP_VFSTYPE' => ' via ',
'bac_WORKSTN_BACKUP_SHARE' => 'Destination backup share folder is ',
'bac_WORKSTN_BACKUP_TOD' => 'Daily backup occurs at ',
'bac_LOGIN' => 'Login is ',
# 'bac_PASSWORD' => 'Password is ',
'bac_WORKSTN_BACKUP_SETSNUM' => 'Number of rotating backup sets is ',
'bac_WORKSTN_BACKUP_DAYSINSET' => 'Number of daily backups contained in each set is ',
'bac_WORKSTN_BACKUP_COMPRESSION' => 'Compression level (0-9) of backup is ',
'bac_WORKSTN_BACKUP_TIMEOUT' => 'Each daily backup session is cleanly timed out after ',
'bac_WORKSTN_BACKUP_INCONLY_TIMEOUT' => 'except full backups which are cleanly timed out after 24 hours',
'bac_WORKSTN_FULL_BACKUP_EVERYDAY' => 'Full backup sessions (new backup set) are allowed everyday',
'bac_WORKSTN_FULL_BACKUP_DAY' => 'Full backup session (new backup sets) is allowed only on',
# 'bac_WORKSTATION_BACKUP_SETCONF' => 'Create or modify workstation backup configuration',
# 'bac_SELECT_VFS_TYPE' => 'Select the type of share for backup destination',
'bac_ERR_NO_USB_DISK' => 'Error : No removable disk available. Please connect a removable disk or select another type of workstation backup.',
'bac_ERR_NO_MOUNTED_DISK' => 'Error : No mounted disk available. Please mount a disk or select another type of workstation backup.',
'bac_HOURS' => 'hours.',
'bac_ERR_NO_FULL_BACKUP' => 'Aborting restore because needed full backup is missing or unreadable.',
'bac_ERR_NO_INC_BACKUP' => 'Aborting restore because the set has missing or unreadable incremental backup number',
# 'bac_CHECK_TO_VERIFY_FULL_RESTORE' => 'Check here to test integrity of all backups needed for a full restore with the selected backup ',
'bac_TESTING_NEEDED_BACKUPS_FOR_RESTORE' => 'Testing all backups needed for a full restore with selected backup',
'bac_TESTED_BACKUP' => 'Testing integrity of backup',
'bac_RESTORE_VERIFY_FAILED' => 'Verify integrity failed',
# 'bac_CHECK_INTEGRITY_WARNING' => 'Warning : For large backups, checking integrity may be a long task and should be made with daily workstation backup disabled.',
# 'bac_cifs' => 'cifs',
# 'bac_nfs' => 'nfs',
# 'bac_local removable disk' => 'Local removable disk',
# 'bac_Mounted disk' => 'Mounted disk',
'bac_ERROR_WHEN_TESTING_REMOTE_SERVER' => 'The parameters have been saved, however the remote host is not reachable, please check your settings.',
'bac_ERR_EXTRACT' => 'Error when extracting with Dar',
'bac_ERROR_UPDATING_CONFIGURATION' => 'Error updating configuration',
'bac_ERR_INVALID_SETS_NUMBERFOLDER' => 'Err invalid sets numberfolder',
'bac_INVALID_FUNCTION' => 'Invalid function',
'bac_OPERATION_STATUS_REPORT' => 'Operation status report',
'bac_SUCCESS' => 'Success',
