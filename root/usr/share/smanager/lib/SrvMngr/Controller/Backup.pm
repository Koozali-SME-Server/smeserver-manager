package SrvMngr::Controller::Backup;

#----------------------------------------------------------------------
# heading     : System
# description : Backup or restore
# navigation  : 4000 100
# Copyright (C) 2002 Mitel Networks Corporation
#----------------------------------------------------------------------
# routes : end
# for information - routes
#    $if_admin->get('/backup')->to('backup#main')->name('backup');
#    $if_admin->post('/backup')->to('backup#do_display')->name('backupd');
#    $if_admin->get('/backupd')->to('backup#do_display')->name('backupc');
#    $if_admin->post('/backupd')->to('backup#do_update')->name('backupu');
use strict;
use warnings;
use JSON::PP ();
use Fcntl qw(LOCK_EX LOCK_NB O_WRONLY O_CREAT O_EXCL);
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session ip_number_or_blank);
use Quota;
use esmith::ConfigDB::UTF8;
use esmith::AccountsDB::UTF8;
use esmith::util;
use File::Basename;
use File::Find;
# Set to avoid using link counts as it may not work for cifs shares.
$File::Find::dont_use_nlink = 1;
use File::Path qw(make_path remove_tree);
use esmith::Backup;
use esmith::BackupHistoryDB; #no UTF8 and not in use 
use esmith::util;
use esmith::lockfile;
use esmith::BlockDevices;
use constant DEBUG => $ENV{MOJO_SMANAGER_DEBUG} || 0;

use constant FALSE => 0;
use constant TRUE  => 1;

my ($cdb,$adb,$rdb);

# Unbuffer standard output so that files and directories are listed as
# they are restored
$| = 1;

# Store away current gid of 'www' group.
my $www_gid = getgrnam("www");

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %bac_datas = ();
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open config db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $rdb = esmith::ConfigDB::UTF8->open('/etc/e-smith/restore');
    my $title     = $c->l('bac_BACKUP_TITLE');
    my $notif;
    $bac_datas{'function'} = 'desktop_backup';
    my ($tarsize, $dumpsize, undef, undef) = $c->CalculateSizes();
    my $module = $cdb->get('backup');

    if ($module) {
        $module = $module->prop('Program');
    }

    # The default e-smith backup program is flexbackup.
    unless (defined $module) {
        $module = "flexbackup";
    } elsif ($module eq '') {
        $module = "flexbackup";
    }
    $bac_datas{'tarsize'}  = $tarsize;
    $bac_datas{'dumpsize'} = $dumpsize;
    $bac_datas{'module'}   = $module;

    if ($tarsize =~ /Tb/ or $tarsize =~ /(\d+)Gb/ and $1 >= 2) {
        $notif = $c->l("bac_BACKUP_DESKTOP_TOO_BIG") . ' : ' . $tarsize;
    }
    my $rec = $cdb->get('backup');
    my ($backup_status, $backupwk_status) = ('disabled') x 2;

    if ($rec) {
        $backup_status = $rec->prop('status') || 'disabled';
    }

    if ($backup_status eq "enabled") {
        $bac_datas{'backupTime'}   = $rec->prop('backupTime');
        $bac_datas{'reminderTime'} = $rec->prop('reminderTime');
    }
    $rec = $cdb->get('backupwk');

    if ($rec) {
        $backupwk_status = $rec->prop('status') || 'disabled';
    }

    if ($backupwk_status eq "enabled") {
        $bac_datas{'backupwkTime'} = $rec->prop('BackupTime');
    }
    $bac_datas{'backupStatus'}   = $backup_status;
    $bac_datas{'backupwkStatus'} = $backupwk_status;
    $c->stash(warning => $notif) if ($notif);
    $c->stash(title => $title, bac_datas => \%bac_datas);
    $c->render(template => 'backup');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt = $c->current_route;
    my ($res, $result) = ('') x 2;
    my $function = $c->param('Function');
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open config db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $rdb = esmith::ConfigDB::UTF8->open('/etc/e-smith/restore');
    my $es_backup = new esmith::Backup or die "Couldn't create Backup object\n";
    my @directories = $es_backup->restore_list;
    @directories = grep { -e "/$_" } @directories;
    my @backup_excludes = $es_backup->excludes;


    if ($function =~ /^(\S+)$/) {
        $function = $1;
    } elsif ($function =~ /^\s*$/) {
        $function = "zoverall";
    } else {
        $result   = $c->l('bac_INVALID_FUNCTION') . $function;
        $function = undef;
    }
    DEBUG && warn("do_display $function");
    my %bac_datas = ();
    $bac_datas{'function'} = $function;
    my $title = $c->l('bac_BACKUP_TITLE');
    my $dest  = '';

    if ($function eq 'desktop_backup') {
        my $CompressionLevel = $cdb->get_prop("backupconsole", "CompressionLevel") || "-6";
        my @exclude = map (" --exclude=$_", @backup_excludes);
        $c->stash(compressionlevel => $CompressionLevel, exclude => \@exclude, directories => \@directories);

        # streaming download in template
        $c->render(template=>"backdown");
        #sleep(30);
        # Redirect to the front page
        #$c->redirect_to('/backup');
        return ""
    } ## end if ($function eq 'desktop_backup')

    if ($function eq 'tape_configure') {
        $bac_datas{'status'} = 'unchecked';
        my $backupTime = "2:00";
        my $rec        = $cdb->get('backup');

        if ($rec) {
            $backupTime = $rec->prop('backupTime') || "2:00";
            my $backup_status = $rec->prop('status');

            if (defined $backup_status && $backup_status eq "enabled") {
                $bac_datas{'status'} = "checked";
            }
        } ## end if ($rec)
        ($bac_datas{backupAMPM}, $bac_datas{reminderAMPM}) = 'AM';
        ($bac_datas{backupHour}, $bac_datas{backupMin}) = split(":", $backupTime, -1);

        if ($bac_datas{backupHour} > 11) {
            if ($bac_datas{backupHour} > 12) {
                $bac_datas{backupHour} -= 12;
            }
            $bac_datas{backupAMPM} = 'PM';
        } ## end if ($bac_datas{backupHour...})

        # Obtain time for reminder notice from the backup cron template
        my $reminderTime = "14:00";

        if ($rec) {
            $reminderTime = $rec->prop('reminderTime') || "14:00";
        }
        ($bac_datas{reminderHour}, $bac_datas{reminderMin}) = split(":", $reminderTime, -1);

        if ($bac_datas{reminderHour} > 12) {
            $bac_datas{reminderHour} -= 12;
            $bac_datas{reminderAMPM} = 'PM';
        }
    } ## end if ($function eq 'tape_configure')

    if ($function eq 'workstn_configure') {
        my $rec = $cdb->get('backupwk');
        $bac_datas{vfstype} = $rec->prop('VFSType') || 'cifs';
        $bac_datas{status} = $rec->prop('status');
    } ## end if ($function eq 'workstn_configure')

    if ($function eq 'workstn_configure1') {
        $bac_datas{vfstype}        = $c->param('VFSType');
        $bac_datas{'status'}       = '';
        $bac_datas{ampm}           = 'AM';
        $bac_datas{min}            = '';
        $bac_datas{hour}           = '';
        $bac_datas{login}          = 'backup';
        $bac_datas{password}       = 'backup';
        $bac_datas{station}        = 'host';
        $bac_datas{folder}         = 'share';
        $bac_datas{mount}          = '';
        $bac_datas{setsNumber}     = '';
        $bac_datas{filesinset}     = '';
        $bac_datas{timeout}        = '';
        $bac_datas{incOnlyTimeout} = '';
        $bac_datas{compression}    = '';
        $bac_datas{dof}            = '';

        # Obtain backup informations from configuration
        my $rec  = $cdb->get('backupwk');
        my $Time = '2:00';

        if ($rec) {
            $Time                      = $rec->prop('BackupTime')     || '2:00';
            $bac_datas{login}          = $rec->prop('Login')          || 'backup';
            $bac_datas{password}       = $rec->prop('Password')       || 'backup';
            $bac_datas{station}        = $rec->prop('SmbHost')        || 'host';
            $bac_datas{folder}         = $rec->prop('SmbShare')       || 'share';
            $bac_datas{mount}          = $rec->prop('Mount')          || '';
            $bac_datas{setsNumber}     = $rec->prop('SetsMax')        || '1';
            $bac_datas{filesinset}     = $rec->prop('DaysInSet')      || '1';
            $bac_datas{timeout}        = $rec->prop('Timeout')        || '12';
            $bac_datas{incOnlyTimeout} = $rec->prop('IncOnlyTimeout') || 'yes';
            $bac_datas{compression}    = $rec->prop('Compression')    || '0';
            $bac_datas{dof} = (defined $rec->prop('FullDay')) ? $rec->prop('FullDay') : '7';
        } ## end if ($rec)
        ($bac_datas{hour}, $bac_datas{min}) = split(':', $Time, -1);

        if ($bac_datas{hour} > 12) {
            $bac_datas{hour} -= 12;
            $bac_datas{ampm} = 'PM';
        }
        my $backupwk_status;

        if ($rec) {
            $backupwk_status = $rec->prop('status');
        }

        if (defined $backupwk_status && $backupwk_status eq 'enabled') {
            $bac_datas{status} = 'checked';
        }

        if (defined $bac_datas{incOnlyTimeout} && $bac_datas{incOnlyTimeout} eq 'yes') {
            $bac_datas{incOnlyTimeout} = 'checked';
        }
    } ## end if ($function eq 'workstn_configure1')

    if ($function eq 'workstn_verify') {
        my $rec = $cdb->get('backupwk');

        if ($rec) {
            $bac_datas{status} = $rec->prop('status') || 'disabled';
        }
    } ## end if ($function eq 'workstn_verify')

    if ($function eq 'workstn_verify1') {
        $res = '';

        if (!$result) {
            my ($job_id, $start_error) = $c->startWorkstnVerify();
            if ($start_error) {
                $result = $start_error;
            } else {
                $c->stash(verify_job_id => $job_id);
                $bac_datas{function} = $function;
            }
        }
    } ## end if ($function eq 'workstn_verify1')

    if ($function eq 'workstn_restore') {
        my $rec = $cdb->get('backupwk');

        if ($rec) {
            $bac_datas{status} = $rec->prop('status') || 'disabled';
        }
    } ## end if ($function eq 'workstn_restore')
    $dest = "back_$function";
    $c->stash(error => $result);
    $c->stash(title => $title, bac_datas => \%bac_datas);
    return $c->render(template => $dest);
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt       = $c->current_route;
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open config db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $rdb = esmith::ConfigDB::UTF8->open('/etc/e-smith/restore');
    my $function = $c->param('Function');
    DEBUG && warn("do_update $function");
    my %bac_datas = ();
    $bac_datas{function} = $function;
    my $title = $c->l('bac_BACKUP_TITLE');
    my ($dest, $res, $result) = ('') x 3;

    if ($function eq 'desktop_backup') {

        # should not happen !! no desktop_backup template !!
        $result .= ' ** Function error for desktop backup ** !';
    } ## end if ($function eq 'desktop_backup')

    if ($function eq 'tape_configure') {
        my $status       = $c->param('Tapebackup');
        my $backupHour   = $c->param('BackupHour');
        my $backupMin    = $c->param('BackupMin');
        my $bampm        = $c->param('BackupAMPM');
        my $reminderHour = $c->param('ReminderHour');
        my $reminderMin  = $c->param('ReminderMin');
        my $rampm        = $c->param('ReminderAMPM');

        if (defined $status && $status eq "on") {
            if ($backupHour =~ /^(.*)$/) {
                $backupHour = $1;
            } else {
                $backupHour = "12";
            }

            if (($backupHour < 1) || ($backupHour > 12)) {
                $result .= $c->l('bac_ERR_INVALID_HOUR') . $backupHour . ' ' . $c->l('bac_BETWEEN_0_AND_12') . ' ';
            }

            if ($backupMin =~ /^(.*)$/) {
                $backupMin = $1;
            } else {
                $backupMin = "0";
            }

            if (($backupMin < 0) || ($backupMin > 59)) {
                $result .= $c->l('bac_ERR_INVALID_MINUTE') . $backupMin . ' ' . $c->l('bac_BETWEEN_0_AND_59') . ' ';
            }

            if ($reminderHour =~ /^(.*)$/) {
                $reminderHour = $1;
            } else {
                $reminderHour = "12";
            }

            if (($reminderHour < 1) || ($reminderHour > 12)) {
                $result
                    .= $c->l('bac_ERR_INVALID_REMINDER_HOUR')
                    . $reminderHour . ' '
                    . $c->l('bac_BETWEEN_0_AND_12') . ' ';
            } ## end if (($reminderHour < 1...))

            if ($reminderMin =~ /^(.*)$/) {
                $reminderMin = $1;
            } else {
                $reminderMin = "0";
            }

            if (($reminderMin < 0) || ($reminderMin > 59)) {
                $result
                    .= $c->l('bac_ERR_INVALID_REMINDER_MINUTE')
                    . $reminderMin . ' '
                    . $c->l('bac_BETWEEN_0_AND_59') . ' ';
            } ## end if (($reminderMin < 0)...)
        } else {

            #  service disabled no controls
        }
        ##$result .= ' ** Blocked for testing ** !';
        $res = '';

        if (!$result) {
            $res = $c->tapeBackupConfig($status, $backupHour, $backupMin, $bampm, $reminderHour, $reminderMin, $rampm);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                if (defined $status && $status eq "on") {
                    $result
                        .= (  $c->l('bac_SUCCESSFULLY_ENABLED_TAPE') . ' '
                            . $c->l('bac_WITH_BACKUP_TIME')
                            . "$backupHour:$backupMin" . ' '
                            . $c->l('bac_WITH_REMINDER_TIME')
                            . "$reminderHour:$reminderMin");
                } else {
                    $result .= $c->l('bac_SUCCESSFULLY_DISABLED');
                }
                $cdb->reload;
            } ## end if (!$result)
        } ## end if (!$result)
    } ## end if ($function eq 'tape_configure')

    if ($function eq 'tape_restore') {
        my $lock_file   = "/var/lock/subsys/e-smith-restore";
        my $file_handle = &esmith::lockfile::LockFileOrReturn($lock_file);

        unless ($file_handle) {
            $result .= $c->l('bac_UNABLE_TO_RESTORE_CONF') . ' ' . $c->l('bac_ANOTHER_RESTORE_IN_PROGRESS');
        }
        ##$result .= ' ** Blocked for testing ** !';
        $res = '';

        if (!$result) {
            $res = $c->tapeRestore($lock_file, $file_handle);
            $result .= $res unless $res eq 'OK';

            #if ( ! $result ) {
            #$result = $c->l('bac_SUCCESS');
            #}
        } ## end if (!$result)
    } ## end if ($function eq 'tape_restore')

    if ($function eq 'workstn_configure') {

        # should not happen !!
        $result .= ' ** Function error for workstation configure *** !';
    } ## end if ($function eq 'workstn_configure')

    if ($function eq 'workstn_configure1') {

        #$result .= ' ** Blocked for testing ** !';
        $res = '';

        if (!$result) {
            $res = $c->updateWorkstnBackupConfig();

            if (($result = $res) =~ s|^#OK#||) {
                $res = 'OK';
                $cdb->reload;
            }
        } ## end if (!$result)
    } ## end if ($function eq 'workstn_configure1')

    if ($function eq 'workstn_verify') {

        # should not happen !!
        $result .= ' ** Function error for workstation verify *** !';
    } ## end if ($function eq 'workstn_verify')

    if ($function eq 'workstn_verify1') {
        ##$result .= ' ** Blocked for testing ** !';
        $res    = 'OK';
        $result = '';
    } ## end if ($function eq 'workstn_verify1')

    if ($function eq 'workstn_restore') {
        $res = 'NOK';

        if (!$result && length($c->param('Backupset') // '')) {
            my ($job_id, $start_error) = $c->startWorkstnRestore();

            if ($start_error) {
                $result = $start_error;
                $c->stash(error => $start_error);
                $res = 'NOK';
            } else {
                $bac_datas{restore_job_id} = $job_id;
                $bac_datas{activity_limit} = _workstn_activity_limit($c->param('ActivityLimit'));
                $bac_datas{function} = 'workstn_restore1';
                $res = 'NEXT';
            }
        }
    } ## end if ($function eq 'workstn_restore')

    if ($function eq 'workstn_restore1') {
        my $job_id = $c->param('restore_job_id') // '';
        my $job = $c->readWorkstnRestoreStatus($job_id);
        $rdb->reload;
        my $rec = $rdb->get('restore');
        my $record_job_id = $rec ? ($rec->prop('job_id') || '') : '';
        my $record_state = $rec ? ($rec->prop('state') || '') : '';
        my $confirmed = $job && ($job->{job_id} || '') eq $job_id
            && ($job->{state} || '') eq 'complete'
            && $record_job_id eq $job_id && $record_state eq 'complete';
        unless ($confirmed) {
            $result .= 'Restore job is not confirmed successful; reboot is disabled.';
        }
        $res = 'NOK';
        if (!$result) {
            $res = $c->performReboot();
            if (($result = $res) =~ s|^#OK#||) { $res = 'OK'; }
            else { $c->stash(error => $result); }
        }
    } ## end if ($function eq 'workstn_restore1')

    if ($function eq 'workstn_sel_restore') {
        my $backupset = $c->param('Backupset');
        my $filterexp = $c->param('Filterexp');

        if ($filterexp =~ /^(.*)$/) {
            $filterexp = $1;
        } else {
            $filterexp = '';
        }

        #$result .= ' ** Blocked for testing 1 ** !';
        $res = '';

        if (!$result) {
            $bac_datas{function}  = 'workstn_sel_restore1';
            $bac_datas{backupset} = $backupset;
            $bac_datas{filterexp} = $filterexp;
            $res                  = 'NEXT';
        } ## end if (!$result)
    } ## end if ($function eq 'workstn_sel_restore')

    if ($function eq 'workstn_sel_restore1') {
        $bac_datas{backupset} = $c->param('Backupset');
        $bac_datas{filterexp} = $c->param('Filterexp');
        my @restorefiles  = @{ $c->every_param('Restorefiles') };
        my $seldatebefore = $c->param('Seldatebefore');

        if ($seldatebefore =~ /^(.*)$/) {
            $seldatebefore = $1;
        } else {
            $result .= 'Unsecure data : ' . $seldatebefore;
        }
        my $tymd = qr/((19|20)\d\d\/(?=\d\d\/\d\d-))?((0?[1-9]|1[0-2])\/(?=\d\d-))?((31|[123]0|[012]?[1-9])-)?/;
        my $thms = qr/([01]?[0-9]|2[0-3]):([0-5][0-9])(:[0-5][0-9])?/;
        $result .= " $seldatebefore : " . $c->l('bac_ERR_INVALID_SELDATE')
            unless (($seldatebefore =~ m/^$tymd$thms$/) || ($seldatebefore eq ""));
        ##$result .= ' ** Blocked for testing 2 ** !';
        $res = '';

        if (!$result) {
            $res = $c->performWorkstnSelRestore($seldatebefore, \@restorefiles);    # restore log returned

            if (($result = $res) =~ s|^#OK#||) {
                $bac_datas{restore_log} = $result;
                $res = 'OK';
            } else {
                $c->stash(error => $result);
            }
            $bac_datas{function} = 'workstn_sel_restore2';
            $res = 'NEXT';
        } ## end if (!$result)
    } ## end if ($function eq 'workstn_sel_restore1')

    if ($function eq 'workstn_sel_restore2') {
        ##$result .= ' ** Blocked for testing 3 ** !';
        $res    = 'OK';
        $result = '';
    } ## end if ($function eq 'workstn_sel_restore2')

    # common part for all functions
    if ($res ne 'OK') {
        if ($res eq 'NEXT') {
            $dest = 'back_' . $bac_datas{"function"};
        } else {
            $c->stash(error => $result);
            $dest = "back_$function";
        }
        $bac_datas{vfstype}        = $c->param('VFSType');
        $c->stash(title => $title, bac_datas => \%bac_datas);
        return $c->render($dest);
    } ## end if ($res ne 'OK')
    my $message = "'Backup' $function updates DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('backup');
} ## end sub do_update

sub tapeBackupConfig {
    my ($c, $status, $backupHour, $backupMin, $bampm, $reminderHour, $reminderMin, $rampm) = @_;

    if (defined $status && $status eq "on") {
        $backupMin = sprintf("%02d", $backupMin);

        if ($bampm =~ /^(.*)$/) {
            $bampm = $1;
        } else {
            $bampm = "AM";
        }

        # convert to 24 hour time
        $backupHour = $backupHour % 12;

        if ($bampm eq "PM") {
            $backupHour = $backupHour + 12;
        }
        $reminderMin = sprintf("%02d", $reminderMin);

        if ($rampm =~ /^(.*)$/) {
            $rampm = $1;
        } else {
            $rampm = "AM";
        }

        # convert to 24 hour time
        $reminderHour = $reminderHour % 12;

        if ($rampm eq "PM") {
            $reminderHour = $reminderHour + 12;
        }

        # variables passed validity checks, set configuration database values
        my $oldUnsav = $cdb->get('UnsavedChanges')->value;
        my $rec      = $cdb->get('backup');

        unless (defined $rec) {
            $rec = $cdb->new_record('backup', { type => 'service' });
        }
        $rec->set_prop('status', 'enabled');
        my $module = $rec->prop('Program');

        # The default e-smith backup program is flexbackup.
        unless (defined $module) {
            $module = "flexbackup";
        } elsif ($module eq '') {
            $module = "flexbackup";
        }
        $rec->set_prop('Program',      $module);
        $rec->set_prop('backupTime',   "$backupHour:$backupMin");
        $rec->set_prop('reminderTime', "$reminderHour:$reminderMin");
        $cdb->get('UnsavedChanges')->set_value($oldUnsav);
        system("/sbin/e-smith/signal-event", "conf-backup") == 0
            or return ($c->l('bac_ERR_CONF_BACKUP'), "\n");
        return 'OK';
    } else {

        # set service to disabled
        my $oldUnsav = $cdb->get('UnsavedChanges')->value;
        my $rec      = $cdb->get('backup');

        unless ($rec) {
            $rec = $cdb->new_record('backup', { type => 'service' });
        }
        $rec->set_prop('status', 'disabled');
        $cdb->get('UnsavedChanges')->set_value($oldUnsav);
        system("/sbin/e-smith/signal-event", "conf-backup") == 0
            or return ($c->l('bac_ERR_CONF_BACKUP') . "\n");
        return 'OK';
    } ## end else [ if (defined $status &&...)]
    return undef;
} ## end sub tapeBackupConfig

sub tapeRestore {
    my ($c, $lock_file, $file_handle) = @_;
    my $rec = $rdb->get('restore');
    $rec->set_prop('state', 'running');
    $rec->set_prop('start', time);
    my $child;

    if ($child = fork) {

        # Parent
        $SIG{'CHLD'} = 'IGNORE';
        &esmith::lockfile::UnlockFile($file_handle);
        return 'OK';
    } elsif (defined $child) {

        # Child
        # Re-establish the lock. Wait till it is relinquished by the parent.
        $file_handle = &esmith::lockfile::LockFileOrWait($lock_file);

        # Close STDOUT so that the web server connection is closed.
        close STDOUT;

        # Now reopen STDOUT for the child. Redirect it to STDERR.
        open(STDOUT, ">&STDERR");

        unless (system("/sbin/e-smith/signal-event", "pre-restore") == 0) {
            $rec->set_prop('errmsg', $c->l('bac_ERR_PRE_RESTORE'));
            $rec->delete_prop('state');
            die($c->l('bac_ERR_PRE_RESTORE'), "\n");
        } ## end unless (system("/sbin/e-smith/signal-event"...))

        unless (system("/sbin/e-smith/signal-event", "restore-tape") == 0) {
            $rec->set_prop('errmsg', $c->l('bac_ERR_RESTORING_FROM_TAPE'));
            $rec->delete_prop('state');
            die($c->l('bac_ERR_RESTORING_FROM_TAPE') . "\n");
        } ## end unless (system("/sbin/e-smith/signal-event"...))

        #----------------------------------------
        # regenerate configuration files
        #----------------------------------------
        unless (system("/usr/sbin/groupmod", "-g", "$www_gid", "www") == 0) {
            $rec->set_prop('errmsg', $rec->prop('errmsg') . ', ' . $c->l('bac_ERR_RESTORING_GID'));
            warn($c->l('bac_ERR_RESTORING_GID') . "\n");
        }

        unless (system("/usr/sbin/usermod", "-g", "$www_gid", "www") == 0) {
            $rec->set_prop('errmsg', $rec->prop('errmsg') . ', ' . $c->l('bac_ERR_RESTORING_INITIAL_GRP'));
            warn($c->l('bac_ERR_RESTORING_INITIAL_GRP') . "\n");
        }
        esmith::util::backgroundCommand(0, "/sbin/e-smith/signal-event", "post-upgrade");

        #unless(system("/sbin/e-smith/signal-event", "post-upgrade") == 0) {
        #	$rec->set_prop('errmsg', $rec->prop('errmsg').', '.
        #		$c->l('bac_ERR_UPDATING_CONF_AFTER_TAPE_RESTORE'));
        #	$rec->delete_prop('state');
        #    die ($c->l('bac_ERR_UPDATING_CONF_AFTER_TAPE_RESTORE'));
        #}
        my $finish = time;
        $rec->set_prop('state',  'complete');
        $rec->set_prop('finish', $finish);
        my $start = $rec->prop('start');
        $start  = scalar localtime($start);
        $finish = scalar localtime($finish);
        &esmith::lockfile::UnlockFile($file_handle);
        exit;
    } else {

        # Error
        $rec->delete_prop('state');
        $rec->set_prop('errmsg', $c->l('bac_COULD_NOT_FORK'));
        die($c->l("bac_COULD_NOT_FORK") . " $!\n");
    } ## end else [ if ($child = fork) ]
} ## end sub tapeRestore

sub workstnBackupConfig {

    # called by template
    my ($c) = @_;
    my $out;
    my $backupwk_status;
    # my $enabledIncOnlyTimeout = ""; Not used anywhere
    my $backupwkLogin         = 'backup';
    my $backupwkPassword      = 'backup';
    my $backupwkStation       = 'host';
    my $backupwkFolder        = 'share';
    my $backupwkMount         = '/mnt/smb';
    my $setsNumber;
    my $filesinset;
    my $backupwkTime;
    my $backupwkTimeout;
    my $backupwkIncOnlyTimeout;
    my $VFSType;
    my $compression;
    my $dof;
    my @dlabels = split(' ', $c->l('bac_DOW'));

    # Obtain backup informations from configuration
    my $rec = $cdb->get('backupwk');

    if ($rec) {
        $backupwkTime           = $rec->prop('BackupTime')     || '2:00';
        $backupwkLogin          = $rec->prop('Login')          || 'backup';
        $backupwkPassword       = $rec->prop('Password')       || 'backup';
        $backupwkStation        = $rec->prop('SmbHost')        || 'host';
        $backupwkFolder         = $rec->prop('SmbShare')       || 'share';
        $backupwkMount          = $rec->prop('Mount')          || '/mnt/smb';
        $VFSType                = $rec->prop('VFSType')        || 'cifs';
        $setsNumber             = $rec->prop('SetsMax')        || '1';
        $filesinset             = $rec->prop('DaysInSet')      || '1';
        $backupwkTimeout        = $rec->prop('Timeout')        || '12';
        $backupwkIncOnlyTimeout = $rec->prop('IncOnlyTimeout') || 'yes';
        $compression            = $rec->prop('Compression')    || '0';
        $dof = (defined $rec->prop('FullDay')) ? $rec->prop('FullDay') : '7';
        $backupwk_status = $rec->prop('status');
    } ## end if ($rec)

    if ($rec) {
        if ($VFSType eq 'usb') {
            $out .= $c->l('bac_WORKSTN_BACKUP_USB') . ' ' . $backupwkFolder . '<br/>';
        } elsif ($VFSType eq 'mnt') {
            $out .= $c->l('bac_WORKSTN_BACKUP_MNT') . ' ' . $backupwkMount . '<br/>';
        } else {
            $out .= $c->l('bac_WORKSTN_BACKUP_HOST') . ' ' . $backupwkStation . ' ';
            $out .= $c->l('bac_WORKSTN_BACKUP_VFSTYPE') . ' ' . $VFSType . '<br/>';
            $out .= $c->l('bac_WORKSTN_BACKUP_SHARE') . ' ' . $backupwkFolder . '<br/>';
        }

        if ($VFSType eq 'cifs') {
            $out .= $c->l('bac_LOGIN') . ' ' . $backupwkLogin . '<br/>';
            $out .= $c->l('PASSWORD') . ' ********<br/>';
        }
        $out .= $c->l('bac_WORKSTN_BACKUP_SETSNUM') . ' ' . $setsNumber . '<br/>';
        $out .= $c->l('bac_WORKSTN_BACKUP_DAYSINSET') . ' ' . $filesinset . '<br/>';
        $out .= $c->l('bac_WORKSTN_BACKUP_COMPRESSION') . ' ' . $compression . '<br/>';
        $out .= $c->l('bac_WORKSTN_BACKUP_TOD') . ' ' . $backupwkTime . '<br/>';
        $out .= $c->l('bac_WORKSTN_BACKUP_TIMEOUT') . ' ' . $backupwkTimeout . ' ' . $c->l('bac_HOURS');

        if ($backupwkIncOnlyTimeout eq 'yes') {
            $out .= $c->l('bac_WORKSTN_BACKUP_INCONLY_TIMEOUT');
        }
        $out .= '<br/>';

        if ($dof eq '7') {
            $out .= $c->l('bac_WORKSTN_FULL_BACKUP_EVERYDAY') . '<br/>';
        } else {
            $out .= $c->l('bac_WORKSTN_FULL_BACKUP_DAY') . ' ' . $dlabels[$dof] . '<br/>';
        }
    } else {
        $out = $c->l('bac_WORKSTN_BACKUP_NOT_CONFIGURED');
    }
    return $out;
} ## end sub workstnBackupConfig

sub _workstn_activity_limit {
    my ($value) = @_;
    return 'all' if defined $value && $value eq 'all';
    return 1800 unless defined $value && $value =~ /\A[0-9]{1,6}\z/;
    return ($value >= 1800 && $value <= 100000) ? 0 + $value : 1800;
}

sub startWorkstnVerify {
    my ($c) = @_;
    my $rec = $cdb->get('backupwk');
    return (undef, 'Workstation backup is not configured.') unless $rec;

    my $mount = $rec->prop('Mount') || '/mnt/smb';
    my $share = $rec->prop('SmbShare') || '';
    my $vfstype = $rec->prop('VFSType') || 'cifs';
    my $id = $rec->prop('Id')
        || $cdb->get('SystemName')->value . '.' . $cdb->get('DomainName')->value;
    $mount = "/$share" if $vfstype eq 'usb';
    return (undef, 'Invalid backup host directory configuration.')
        unless $id =~ /\A[-+@\w.]+\z/;
    my $hostdir = "$mount/$id";
    my $selected = $c->param('Backupset') // '';
    my $prefix = "$hostdir/";
    return (undef, 'Please select a backup archive.')
        unless length $selected && index($selected, $prefix) == 0;
    my $relative = substr($selected, length($prefix));
    return (undef, 'Invalid backup archive path.')
        unless $relative =~ /\A[-+@\w\s.\/]+\z/
            && $relative !~ m{(?:\A|/)\.\.?(?:/|\z)}
            && $relative !~ m{//}
            && $relative !~ m{/\z};

    my $jobdir = '/var/lib/smanager/backup-verify';
    return (undef, 'Verification job directory is missing or not writable.')
        unless -d $jobdir && -w $jobdir;
    return (undef, 'The privileged verification worker is not installed.')
        unless -x '/usr/local/sbin/smanager-backup-verify-worker';
    return (undef, 'Cannot start the privileged verification worker. Check /etc/sudoers.d/smanager-backup-verify.')
        unless system('/usr/bin/sudo', '-n', '/usr/local/sbin/smanager-backup-verify-worker', '--check') == 0;

    my $job_id = time() . '-' . $$ . '-' . sprintf('%08x', int(rand(0xffffffff)));
    my $activity_limit = _workstn_activity_limit($c->param('ActivityLimit'));
    my $request = {
        archive => $relative,
        fullverify => (($c->param('Verifyall') // '') eq 'on') ? 1 : 0,
        activity_limit => $activity_limit,
    };
    my $json = JSON::PP->new->utf8->canonical;
    my $reqpath = "$jobdir/$job_id.request";
    my $statuspath = "$jobdir/$job_id.status";
    my $rfh;
    return (undef, 'Could not create verification request.')
        unless sysopen($rfh, $reqpath, O_WRONLY | O_CREAT | O_EXCL, 0600);
    my $written = print {$rfh} $json->encode($request);
    my $closed = close $rfh;
    unless ($written && $closed) {
        unlink $reqpath;
        return (undef, 'Could not save verification request.');
    }

    my $sfh;
    unless (sysopen($sfh, $statuspath, O_WRONLY | O_CREAT | O_EXCL, 0600)) {
        unlink $reqpath;
        return (undef, 'Could not create verification status.');
    }
    my $initial = {
        job_id => $job_id, state => 'queued',
        message => 'Verification queued; waiting for the worker.',
        current => '', completed => 0, archives => [], archive_status => {},
        output => [], activity_limit => $activity_limit, started => time(),
    };
    $written = print {$sfh} $json->encode($initial);
    $closed = close $sfh;
    unless ($written && $closed) {
        unlink $reqpath;
        unlink $statuspath;
        return (undef, 'Could not initialise verification status.');
    }

    eval {
        esmith::util::backgroundCommand(
            0, '/usr/bin/sudo', '-n',
            '/usr/local/sbin/smanager-backup-verify-worker', $job_id
        );
        1;
    } or do {
        my $error = $@ || 'could not start background worker';
        unlink $reqpath;
        unlink $statuspath;
        return (undef, "Could not start verification worker: $error");
    };
    return ($job_id, undef);
}

# Status endpoint is protected by the existing admin-only route group.

sub verify_status {
    my ($c) = @_;
    my $job_id = $c->stash('job_id') // $c->param('job_id') // '';
    return $c->render(json => { error => 'Invalid job ID' }, status => 400)
        unless $job_id =~ /\A[0-9]{10,}-[0-9]{1,8}-[a-f0-9]{8}\z/;
    my $path = "/var/lib/smanager/backup-verify/$job_id.status";
    return $c->render(json => { error => 'Verification job not found' }, status => 404)
        unless -f $path && !-l $path;
    open my $fh, '<', $path
        or return $c->render(json => { error => 'Could not read verification status' }, status => 500);
    my $data = eval { JSON::PP->new->utf8->decode(do { local $/; <$fh> }) };
    close $fh;
    return $c->render(json => { error => 'Invalid verification status data' }, status => 500)
        unless ref($data) eq 'HASH';
    $c->res->headers->header('Cache-Control' => 'no-store, no-cache, must-revalidate');
    return $c->render(json => $data);
}

sub startWorkstnRestore {
    my ($c) = @_;
    my $restoreref = $c->param('Backupset') // '';
    return (undef, 'Missing backup selection.')
        unless length $restoreref;
    my $activity_limit = _workstn_activity_limit($c->param('ActivityLimit'));

    my $jobdir = '/var/lib/smanager/workstation-restore';
    return (undef, 'Restore status directory is missing or not writable.')
        unless -d $jobdir && -w $jobdir;

    # Hold this admission lock from before the shared restore record is changed
    # until the background child exits. The child inherits the descriptor; the
    # parent closes its copy immediately after fork. A second request is refused.
    my $admission_path = "$jobdir/active.lock";
    open my $admission_fh, '>>', $admission_path
        or return (undef, 'Could not open the restore admission lock.');
    unless (flock($admission_fh, LOCK_EX | LOCK_NB)) {
        close $admission_fh;
        return (undef, 'A workstation restore is already queued or running.');
    }

    my $job_id = time() . '-' . $$ . '-' . sprintf('%08x', int(rand(0xffffffff)));
    # Create a private output log for this restore job.
    my $output_path = "$jobdir/$job_id.log";
    sysopen(my $output_fh, $output_path, O_WRONLY | O_CREAT | O_EXCL, 0600)
        or do {
            close $admission_fh;
            return (undef, 'Could not create the restore output log.');
        };
    close $output_fh
        or do {
            unlink $output_path;
            close $admission_fh;
            return (undef, 'Could not close the restore output log.');
        };

    my $initial = {
        job_id => $job_id,
        state => 'queued',
        message => 'Restore queued; preparing the workstation restore.',
        activity_limit => $activity_limit,
        started => time(),
        finished => undef,
    };
    eval { $c->writeWorkstnRestoreStatus($job_id, $initial); 1 }
        or do { close $admission_fh; return (undef, 'Could not initialise restore status.'); };

    my $rec = $rdb->get('restore');
    unless ($rec) {
        unlink "$jobdir/$job_id.status";
        close $admission_fh;
        return (undef, 'The SME restore status record is missing.');
    }
    my $record_init_ok = eval {
        $rec->set_prop('job_id', $job_id);
        $rec->set_prop('state', 'queued');
        $rec->set_prop('start', time());
        1;
    };
    unless ($record_init_ok) {
        my $why = $@ || 'Could not initialise the SME restore record.';
        close $admission_fh;
        unlink "$jobdir/$job_id.status";
        return (undef, "Could not initialise the SME restore record: $why");
    }

    my $pid = fork();
    unless (defined $pid) {
        close $admission_fh;
        $rec->set_prop('state', 'failed');
        $rec->set_prop('finish', time());
        $c->writeWorkstnRestoreStatus($job_id, {
            %{$initial}, state => 'failed',
            message => "Could not start background restore: $!",
            finished => time(),
        });
        return (undef, "Could not start background restore: $!");
    }

    # Parent returns immediately and drops its copy. The child keeps the flock
    # for the full restore lifetime, preventing job-ID replacement races.
    if ($pid) {
        close $admission_fh;
        return ($job_id, undef);
    }

    # Detach the child from the browser request and keep diagnostics off the
    # inherited HTTP/server streams. The parent's connection is unaffected.
    open STDIN, '<', '/dev/null';
    open STDOUT, '>', '/dev/null';
    open STDERR, '>>', '/var/log/smanager-workstation-restore.log'
        or open STDERR, '>', '/dev/null';
    eval { $c->tx->connection->close; 1 };

    my $final_state = 'failed';
    my $final_message = 'Restore failed before completion.';
    eval {
        $c->writeWorkstnRestoreStatus($job_id, {
            %{$initial}, state => 'running',
            message => 'Workstation restore is running. Do not reboot or close the server.',
        });
        my $restore_result = $c->workstnRestore($restoreref, $job_id);
        if (defined $restore_result && $restore_result =~ s/^#OK#//) {
            $rdb->reload;
            my $current = $rdb->get('restore');
            my $current_id = $current ? ($current->prop('job_id') || '') : '';
            my $current_state = $current ? ($current->prop('state') || '') : '';
            if ($current_id eq $job_id && $current_state eq 'complete') {
                $final_state = 'complete';
                $final_message = 'Workstation restore completed successfully. A REBOOT IS REQUIRED to complete the restore. Use the Reboot button now.';
            } else {
                $final_message = 'Restore did not reach the required complete state; reboot remains disabled.';
            }
        } else {
            $restore_result = 'No details were returned by the restore routine.'
                unless defined $restore_result && length $restore_result;
            $final_message = "Workstation restore failed: $restore_result";
        }
        1;
    } or do {
        my $exception = $@ || 'unknown background restore error';
        $final_state = 'failed';
        $final_message = "Workstation restore failed: $exception";
    };

    eval {
        $rdb->reload;
        my $current = $rdb->get('restore');
        die 'Restore record is missing or belongs to another job.'
            unless $current && ($current->prop('job_id') || '') eq $job_id;
        $current->set_prop('state', $final_state eq 'complete' ? 'complete' : 'failed');
        $current->set_prop('finish', time());
        1;
    } or do {
        my $finalise_error = $@ || 'Could not finalise restore record';
        $final_state = 'failed';
        $final_message = "Workstation restore failed during final status update: $finalise_error";
    };
    eval {
        $c->writeWorkstnRestoreStatus($job_id, {
            job_id => $job_id,
            state => $final_state,
            message => $final_message,
            started => $initial->{started},
            finished => time(),
        });
        1;
    } or do {
        warn "Could not publish final workstation restore status: $@";
        # Do not change the DB record to complete on a publication error. The
        # browser and reboot gate both fail closed if status cannot be confirmed.
        if ($final_state eq 'complete') {
            eval {
                $rdb->reload;
                my $current = $rdb->get('restore');
                if ($current && ($current->prop('job_id') || '') eq $job_id) {
                    $current->set_prop('state', 'failed');
                    $current->set_prop('finish', time());
                }
            };
        }
    };
    exit 0;
}

sub writeWorkstnRestoreStatus {
    my ($c, $job_id, $data) = @_;
    die 'Invalid restore job ID' unless $job_id =~ /\A[0-9]{10,}-[0-9]{1,8}-[a-f0-9]{8}\z/;
    my $path = "/var/lib/smanager/workstation-restore/$job_id.status";
    my $tmp = "$path.tmp.$$";
    open my $fh, '>', $tmp or die "Cannot write restore status: $!";
    print {$fh} JSON::PP->new->utf8->canonical->encode($data)
        or die "Cannot save restore status: $!";
    close $fh or die "Cannot close restore status: $!";
    chmod 0600, $tmp or die "Cannot secure restore status: $!";
    rename $tmp, $path or die "Cannot publish restore status: $!";
    return 1;
}

sub readWorkstnRestoreStatus {
    my ($c, $job_id) = @_;
    return undef unless defined $job_id
        && $job_id =~ /\A[0-9]{10,}-[0-9]{1,8}-[a-f0-9]{8}\z/;
    my $path = "/var/lib/smanager/workstation-restore/$job_id.status";
    return undef unless -f $path && !-l $path;
    open my $fh, '<', $path or return undef;
    my $data = eval { JSON::PP->new->utf8->decode(do { local $/; <$fh> }) };
    close $fh;
    return undef unless ref($data) eq 'HASH' && ($data->{job_id} || '') eq $job_id;
    return $data;
}

sub restore_status {
    my ($c) = @_;
    my $job_id = $c->stash('job_id') // $c->param('job_id') // '';
    my $data = $c->readWorkstnRestoreStatus($job_id);
    return $c->render(json => { error => 'Restore job not found' }, status => 404)
        unless $data;

    # RESTORE_STATUS_INCREMENTAL_OUTPUT
    # Return at most 32 KB of new plain-text DAR output for this job.
    my $offset = $c->param('offset') // 0;
    return $c->render(
        json => { error => 'Invalid output offset' },
        status => 400
    ) unless $offset =~ /\A[0-9]{1,12}\z/;
    $offset = 0 + $offset;

    my $output = '';
    my $next_offset = $offset;
    my $more_output = 0;
    my $output_path = "/var/lib/smanager/workstation-restore/$job_id.log";
    if (-f $output_path && !-l $output_path) {
        if (open my $output_fh, '<', $output_path) {
            binmode $output_fh;
            my $file_size = -s $output_fh;
            if (defined $file_size && $offset <= $file_size) {
                unless (seek($output_fh, $offset, 0)) {
                    close $output_fh;
                    return $c->render(
                        json => { error => 'Could not seek restore output log' },
                        status => 500
                    );
                }
                my $read_length = $file_size - $offset;
                $read_length = 32768 if $read_length > 32768;
                my $bytes_read = read($output_fh, $output, $read_length);
                unless (defined $bytes_read) {
                    close $output_fh;
                    return $c->render(
                        json => { error => 'Could not read restore output log' },
                        status => 500
                    );
                }
                $output = '' unless $bytes_read;
                $next_offset = $offset + $bytes_read;
                # RESTORE_STATUS_MORE_OUTPUT_FLAG
                # Check the current size after reading, so growth during this
                # request is also picked up by the next browser poll.
                my $current_size = -s $output_fh;
                $more_output = 1
                    if defined $current_size && $next_offset < $current_size;
            } else {
                # Do not allow a client to seek beyond the current log end.
                $next_offset = $file_size if defined $file_size;
            }
            close $output_fh;
        } else {
            # RESTORE_STATUS_MISSING_LOG_FAIL_CLOSED: do not report an empty successful drain.
            return $c->render(
                json => { error => 'Could not open restore output log' },
                status => 500
            );
        }
    } else {
        # Missing, non-regular, or symlink output logs are retrieval failures.
        return $c->render(
            json => { error => 'Restore output log is missing or is not a regular file' },
            status => 500
        );
    }
    $data->{output} = $output;
    $data->{next_offset} = $next_offset;
    $data->{more_output} = $more_output ? 1 : 0;

    # Do not tell the browser that restore succeeded unless the shared SME
    # restore record confirms the same job ID and complete state as the status file.
        if (($data->{state} || '') eq 'complete') {
        my $restore_db = esmith::ConfigDB::UTF8->open('/etc/e-smith/restore')
            or return $c->render(
                json => {
                    job_id => $job_id,
                    state => 'unknown',
                    message => 'Could not open the SME restore status database.'
                }
            );

        my $rec = $restore_db->get('restore');
        my $record_job_id = $rec ? ($rec->prop('job_id') || '') : '';
        my $record_state = $rec ? ($rec->prop('state') || '') : '';
        unless ($record_job_id eq $job_id && $record_state eq 'complete') {
            $data->{state} = 'unknown';
            $data->{message} = 'Restore success could not be confirmed by the SME restore record.';
        }
    }
    $c->res->headers->header('Cache-Control' => 'no-store, no-cache, must-revalidate');
    return $c->render(json => $data);
}


sub workstnVerify {
    my ($c) = @_;
    my $out;
    my $backupwkrec = $cdb->get('backupwk');
    my $smbhost     = $backupwkrec->prop('SmbHost');
    my $smbshare    = $backupwkrec->prop('SmbShare');
    my $mntdir      = $backupwkrec->prop('Mount') || '/mnt/smb';
    my $key;
    my $error_message;
    my $id = $backupwkrec->prop('Id')
        || $cdb->get('SystemName')->value . '.' . $cdb->get('DomainName')->value;
    my $err;
    my $VFSType = $backupwkrec->prop('VFSType') || 'cifs';
    my $verifyref = $c->param('Backupset');
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');

    # Mounting backup shared folder
    $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);

    if ($error_message) {
        return $error_message . ' ' . $id;
    }

    # Test if backup subdirectory for our server
    my $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message = $c->l('bac_ERR_NO_HOST_DIR') . "\n";
        $error_message .= $c->bunmount($mntdir, $VFSType);
        return $error_message . ' ' . $id;
    } ## end unless (-d $mntbkdir)
    my $fullverify = $c->param('Verifyall') || '';

    if ($fullverify eq "on") {

        # Test all backups needed to full restore
        my %backupsetfiles = ();
        my @restorefiles;
        my $set = $verifyref;
        $set =~ s/\/[^\/]*$//;
        my $backupsetlist = sub {

            if ($_ =~ /\.dar/) {
                my $backupref = $File::Find::name;
                $backupref =~ s/\.[0-9]+\.dar//;
                $_ =~ s/\..*\.dar//;
                $_ =~ s/.*-//;
                $backupsetfiles{$_} = $backupref;
            } ## end if ($_ =~ /\.dar/)
        };

        # find list of available backups and verify
        # it contains all backups needed for full restore
        find { wanted => \&$backupsetlist, untaint => 1, untaint_pattern => qr|^([-+@\w\s./]+)$| }, $set;
        my $key;
        my $num = 0;

        foreach $key (sort keys %backupsetfiles) {
            push @restorefiles, $backupsetfiles{$key};

            if ($num == 0) {
                unless ($backupsetfiles{$key} =~ /\/full-/) {
                    $out .= $c->l('bac_ERR_NO_FULL_BACKUP');
                    return $out;
                }
            } else {
                my $numf = sprintf("%03d", $num);

                unless ($backupsetfiles{$key} =~ /\/inc-$numf-/) {
                    $out .= $c->l('bac_ERR_NO_INC_BACKUP') . " " . $numf;
                    return $out;
                }
            } ## end else [ if ($num == 0) ]
            $num++;
            last if ($backupsetfiles{$key} eq $verifyref);
        } ## end foreach $key (sort keys %backupsetfiles)

        if (open(RD, "-|")) {
            $out .= '<b>' . $c->l('bac_TESTING_NEEDED_BACKUPS_FOR_RESTORE') . '</b><UL>';

            while (<RD>) {
                $out .= "<li>$_</li>";
            }
            $out .= '</UL>';
            my $message;
            $out .= '<b>';

            if (!close RD) {
                $out .= $c->l('bac_RESTORE_VERIFY_FAILED');
            } else {
                $out .= $c->l('bac_VERIFY_COMPLETE');
            }
            $out .= '</b>';
        } else {
            select(STDOUT);
            $| = 1;
            my $file;

            foreach $file (@restorefiles) {
                if ($file =~ /^(.*)$/) {
                    $file = $1;
                } else {
                    $error_message = "Unsecure data :  $file\n";
                    $error_message .= $c->bunmount($mntdir, $VFSType);
                    die($error_message);
                }
                print $c->l('bac_TESTED_BACKUP') . ' ' . $file;
                system("/usr/bin/dar", "-Q", "--test", "$file", "--noconf");
            } ## end foreach $file (@restorefiles)
            $error_message = $c->bunmount($mntdir, $VFSType);
            die($error_message) if $error_message;
            exit(0);
        } ## end else [ if (open(RD, "-|")) ]

        #return;
    } else {

        # verify selected backup only
        # and display files saved in the backup
        my $backupkey = $verifyref;

        if ($backupkey =~ /^(.*)$/) {
            $backupkey = $1;
        } else {
            $error_message = "Unsecure data :  $backupkey\n";
            $error_message .= $c->bunmount($mntdir, $VFSType);
            die($error_message);
        }

        if (open(RD, "-|")) {
            $out .= '<b>' . $c->l('bac_FILES_IN_BACKUP') . '</b><UL>';
            my $complete = 0;

            while (<RD>) {
                $complete++ if /etc\/samba\/smbpasswd$/;
                $out .= "<li>$_</li>";
            }
            $out .= '</UL>';
            my $status
                = close RD
                ? (
                  $complete
                ? $c->l('bac_VERIFY_COMPLETE')
                : $c->l('bac_BACKUP_FILE_INCOMPLETE')
                )
                : ($c->l('bac_ERROR_READING_FILE') . ' : ' . $backupkey);
            $out .= "<b> $status </b>";
        } else {
            select(STDOUT);
            $| = 1;
            system("/usr/bin/dar", "-Q", "--list", "$backupkey", "--noconf") == 0
                or die($c->l('bac_ERR_EXTRACT') . " : " . $!);
            $error_message = $c->bunmount($mntdir, $VFSType);
            die($error_message) if $error_message;
            exit(0);
        } ## end else [ if (open(RD, "-|")) ]
    } ## end else [ if ($fullverify eq "on")]
    $error_message .= $c->bunmount($mntdir, $VFSType);
    return $out;
} ## end sub workstnVerify

sub workstnRestore { # SME11_RESTORE_CLEANUP_TEST_HELPER
    my ($c, $restoreref, $job_id) = @_;
    my $out = '';
    return $c->l('bac_RESTORE_CANNOT_PROCEED') . ' Missing backup selection.'
        unless defined $restoreref && length $restoreref;

    my $set = $restoreref;
    $set =~ s{/[^/]*$}{};
    my %backupsetfiles;
    my @restorefiles;
    my $backupsetlist = sub {
        if ($_ =~ /\.dar\z/) {
            my $backupref = $File::Find::name;
            $backupref =~ s/\.[0-9]+\.dar\z//;
            $_ =~ s/\..*\.dar\z//;
            $_ =~ s/.*-//;
            $backupsetfiles{$_} = $backupref;
        }
    };

    my $lock_file = '/var/lock/subsys/e-smith-restore';
    my $file_handle = &esmith::lockfile::LockFileOrReturn($lock_file);
    return $c->l('bac_RESTORE_CANNOT_PROCEED') . ' <br> (' . $c->l('bac_ANOTHER_RESTORE_IN_PROGRESS') . ')'
        unless $file_handle;

    # Initialize cleanup state before reading configuration so even a config
    # lookup exception can release the restore lock through finish_failure.
    my ($backupwkrec, $id, $smbhost, $smbshare, $mntbkdir);
    my $mntdir = '/mnt/smb';
    my $VFSType = 'cifs';
    my $mounted = 0;
    my $unmount_attempted = 0;
    my $unmount_error;
    my $lock_release_attempted = 0;

    # This is the only place that calls bunmount. Both normal completion and
    # failure cleanup use it; a failed unmount is never retried implicitly.
    my $unmount_backup = sub {
        return undef unless $mounted;
        return $unmount_error if $unmount_attempted;
        $unmount_attempted = 1;

        my ($unmount_result, $unmount_exception);
        my $unmount_call_ok = eval {
            $unmount_result = $c->bunmount($mntdir, $VFSType);
            1;
        };
        $unmount_exception = $@ unless $unmount_call_ok;
        if (!$unmount_call_ok) {
            $unmount_error = "Unmount raised an exception: $unmount_exception";
        } elsif (defined $unmount_result && length $unmount_result) {
            $unmount_error = "Unmount failed: $unmount_result";
        } else {
            $mounted = 0;
        }
        return $unmount_error;
    };

    # UnlockFile() in SME's esmith::lockfile does not return a success value.
    # Treat a non-throwing call as success; never infer failure from undef.
    # Attempt at most once, because a second call may close an already-closed FH.
    my $release_restore_lock = sub {
        return undef unless $file_handle;
        return 'Restore lock release was already attempted.' if $lock_release_attempted;
        $lock_release_attempted = 1;
        my $unlock_ok = eval { &esmith::lockfile::UnlockFile($file_handle); 1; };
        my $unlock_exception = $@ unless $unlock_ok;
        $file_handle = undef;
        return $unlock_ok ? undef : "Could not release restore lock: $unlock_exception";
    };

    # All post-lock failures pass through this cleanup path. A failed unmount
    # is itself a restore failure and therefore can never produce #OK#.
    my $finish_failure = sub {
        my ($reason) = @_;
        my @cleanup_errors;

        if ($mounted && !$unmount_attempted) {
            my $unmount_problem = $unmount_backup->();
            push @cleanup_errors, $unmount_problem if defined $unmount_problem && length $unmount_problem;
        }

        if ($file_handle) {
            my $unlock_problem = $release_restore_lock->();
            push @cleanup_errors, $unlock_problem if defined $unlock_problem && length $unlock_problem;
        }

        my $message = defined $reason && length $reason ? $reason : 'Restore failed.';
        $message .= ' ' . join(' ', @cleanup_errors) if @cleanup_errors;
        eval {
            my $restore_rec = $rdb->get('restore');
            if ($restore_rec) {
                $restore_rec->set_prop('state', 'failed');
                $restore_rec->set_prop('finish', time);
            }
            1;
        } or warn "Could not record failed workstation restore state: $@";
        return $message;
    };

    my $config_ok = eval {
        $backupwkrec = $cdb->get('backupwk');
        die "backupwk configuration record is missing\n" unless $backupwkrec;
        $id = $backupwkrec->prop('Id')
            || $cdb->get('SystemName')->value . '.' . $cdb->get('DomainName')->value;
        $mntdir = $backupwkrec->prop('Mount') || '/mnt/smb';
        $VFSType = $backupwkrec->prop('VFSType') || 'cifs';
        $smbhost = $backupwkrec->prop('SmbHost');
        $smbshare = $backupwkrec->prop('SmbShare');
        $mntdir = "/$smbshare" if $VFSType eq 'usb';
        $mntbkdir = "$mntdir/$id";
        1;
    };
    unless ($config_ok) {
        return $finish_failure->("Could not read workstation backup configuration: $@");
    }

    # Mount the configured backup source. If bmount throws, it may have
    # partially mounted the source, so route that case through unmount cleanup.
    my ($error_message, $mount_call_ok);
    $mount_call_ok = eval {
        $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);
        1;
    };
    unless ($mount_call_ok) {
        # bmount may have partially mounted before throwing. Determine the
        # actual mount state instead of assuming either mounted or unmounted.
        if ($VFSType ne 'mnt') {
            my $mount_check_ok = eval { $mounted = $c->checkMount($mntdir) ? 0 : 1; 1; };
            $mounted = 0 unless $mount_check_ok;
        }
        return $finish_failure->("Mount operation raised an exception: $@");
    }
    if (defined $error_message && length $error_message) {
        if ($VFSType ne 'mnt') {
            my $mount_check_ok = eval { $mounted = $c->checkMount($mntdir) ? 0 : 1; 1; };
            $mounted = 0 unless $mount_check_ok;
        }
        return $finish_failure->($c->l('bac_RESTORE_CANNOT_PROCEED') . " $error_message : $id");
    }
    $mounted = ($VFSType eq 'mnt') ? 0 : 1;

    unless (-d $mntbkdir) {
        return $finish_failure->(
            $c->l('bac_RESTORE_CANNOT_PROCEED') . ' '
            . $c->l('bac_ERR_NO_HOST_DIR') . " : $id"
        );
    }

    # Find the selected backup set and verify its full/incremental sequence.
    my $find_ok = eval {
        find {
            wanted => $backupsetlist,
            untaint => 1,
            untaint_pattern => qr|^([-+@\w\s./]+)$|,
        }, $set;
        1;
    };
    unless ($find_ok) {
        return $finish_failure->("Could not enumerate backup set: $@");
    }

    my $num = 0;
    my $selected_found = 0;
    for my $key (sort keys %backupsetfiles) {
        push @restorefiles, $backupsetfiles{$key};
        if ($num == 0) {
            unless ($backupsetfiles{$key} =~ m{/full-}) {
                return $finish_failure->(
                    $c->l('bac_RESTORE_CANNOT_PROCEED') . ' ' . $c->l('bac_ERR_NO_FULL_BACKUP')
                );
            }
        } else {
            my $numf = sprintf('%03d', $num);
            unless ($backupsetfiles{$key} =~ m{/inc-\Q$numf\E-}) {
                return $finish_failure->(
                    $c->l('bac_RESTORE_CANNOT_PROCEED') . ' '
                    . $c->l('bac_ERR_NO_INC_BACKUP') . " $numf"
                );
            }
        }
        $num++;
        if ($backupsetfiles{$key} eq $restoreref) {
            $selected_found = 1;
            last;
        }
    }

    unless (@restorefiles && $selected_found) {
        return $finish_failure->($c->l('bac_RESTORE_CANNOT_PROCEED') . ' Selected backup was not found or the set is empty.');
    }

    my ($rec, $status_init_ok);
    $status_init_ok = eval {
        $rec = $rdb->get('restore');
        die "restore status record is missing\n" unless $rec;
        $rec->set_prop('state', 'running');
        $rec->set_prop('start', time);
        my $bootstrap = $cdb->get('bootstrap-console');
        die "bootstrap-console configuration record is missing\n" unless $bootstrap;
        $bootstrap->set_prop('Run', 'yes');
        1;
    };
    unless ($status_init_ok) {
        return $finish_failure->("Could not initialize restore status: $@");
    }

    unless (system('/sbin/e-smith/signal-event', 'pre-restore') == 0) {
        my $status = $?;
        my $detail = $status == -1 ? "could not execute pre-restore: $!"
            : ($status & 127) ? sprintf('pre-restore died from signal %d', $status & 127)
            : 'pre-restore exited with status ' . ($status >> 8);
        return $finish_failure->($c->l('bac_OPERATION_STATUS_REPORT') . ' ' . $c->l('bac_ERR_PRE_RESTORE') . " ($detail)");
    }

    $| = 1;
    my $RD;
    my $pid = open($RD, '-|');

    # Important: open(..., '-|') returns undef on fork/pipe failure, zero in
    # the child, and the child PID in the parent. Only a defined zero means
    # we are in the child; an undef must never enter the DAR branch.
    unless (defined $pid) {
        my $open_error = $! || 'unknown pipe/fork error';
        return $finish_failure->("Could not start DAR restore child: $open_error");
    }

    if ($pid) {
        # Parent: consume output and wait for the child. close() on a pipe
        # reports the child status; capture $? immediately after close.
        # Append plain DAR output to the private log created for this job.
        my $output_path = '/var/lib/smanager/workstation-restore/' . $job_id . '.log';
        my $output_fh;
        my $output_error;
        if (!defined $job_id || $job_id !~ /\A[0-9]{10,}-[0-9]{1,8}-[a-f0-9]{8}\z/) {
            $output_error = 'Invalid restore job ID for output log.';
        } else {
            require Fcntl;
            if (!sysopen($output_fh, $output_path, O_WRONLY | Fcntl::O_APPEND())) {
                $output_error = "Could not open restore output log: $!";
            }
            else {
                # RESTORE_OUTPUT_LOG_AUTOFLUSH: make each DAR line visible to status polling.
                require IO::Handle;
                $output_fh->autoflush(1);
            }
        }
        $out .= $c->l('bac_FILES_HAVE_BEEN_RESTORED') . "\n<UL>";
        my $complete = 0;
        my $pipe_read_error;
        while (1) {
            # Clear errno before each read so only an errno from this read is
            # interpreted as a pipe read failure rather than stale $! at EOF.
            $! = 0;
            my $line = <$RD>;
            if (defined $line) {
                $complete++ if $line =~ m{etc/samba/smbpasswd\s*\z};
                $out .= '<li>' . $line . "</li>\n";
                if ($output_fh) {
                    print {$output_fh} $line
                        or $output_error ||= "Could not write restore output log: $!";
                }
                next;
            }
            $pipe_read_error = "$!" if $!;
            last;
        }

        # Always close/reap the child even when a read error was observed.
        my $pipe_closed = close($RD);
        my $child_status = $?;  # capture immediately; close() waits for child
        my $pipe_close_error = "$!" unless $pipe_closed;
        $out .= '</UL>';

        if ($output_fh) {
            close($output_fh)
                or $output_error ||= "Could not close restore output log: $!";
        }
        if ($output_error) {
            return $finish_failure->($output_error);
        }

        if ($pipe_read_error) {
            return $finish_failure->("Could not read DAR output pipe: $pipe_read_error");
        }
        unless ($pipe_closed) {
            return $finish_failure->("Could not close DAR output pipe: " . ($pipe_close_error || 'unknown error'))
                if $child_status == 0;
        }
        unless ($pipe_closed && $child_status == 0) {
            my $detail = $child_status == -1 ? "could not obtain child status: $!"
                : ($child_status & 127) ? sprintf('DAR restore child died from signal %d', $child_status & 127)
                : 'DAR restore child exited with status ' . ($child_status >> 8);
            return $finish_failure->($c->l('bac_RESTORE_FAILED_MSG') . " ($detail)");
        }
        unless ($complete) {
            return $finish_failure->($c->l('bac_RESTORE_FAILED') . ' Restore completion marker was not found in DAR output.');
        }

        # The parent owns cleanup. Completion requires the one central unmount
        # operation to succeed; a failed attempt is not repeated by cleanup.
        # SME11_SUCCESS_UNMOUNT_GATE: completion is not possible before this succeeds.
        my $unmount_problem = $unmount_backup->();
        if (defined $unmount_problem && length $unmount_problem) {
            return $finish_failure->($unmount_problem);
        }

        # Preserve the existing post-restore behavior; this helper's changes
        # are limited to restore failure cleanup, DAR status, and unmount order.
        my $post_setup_ok = eval {
            system('/usr/sbin/groupmod', '-g', "$www_gid", 'www') == 0
                or warn($c->l('bac_ERR_RESTORING_GID') . "\n");
            system('/usr/sbin/usermod', '-g', "$www_gid", 'www') == 0
                or warn($c->l('bac_ERR_RESTORING_INITIAL_GRP') . "\n");
            esmith::util::backgroundCommand(0, '/sbin/e-smith/signal-event', 'post-upgrade');
            1;
        };
        unless ($post_setup_ok) {
            return $finish_failure->("Post-restore configuration setup raised an exception: $@");
        }

        my $unlock_problem = $release_restore_lock->();
        return $finish_failure->($unlock_problem)
            if defined $unlock_problem && length $unlock_problem;

        # Publish complete only after DAR succeeded, the completion marker was
        # observed, the backup source unmounted, and the lock was released.
        my $status_ok = eval {
            $rec->set_prop('state', 'complete');
            $rec->set_prop('finish', time);
            1;
        };
        unless ($status_ok) {
            return $finish_failure->('Could not record restore completion: ' . ($@ || 'unknown error'));
        }
        return '#OK#' . $out . $c->l('bac_RESTORE_COMPLETE');
    }

    # Child: perform DAR only. Never unmount or unlock here; the parent owns
    # cleanup and will use this exit code to decide whether completion is safe.
    select(STDOUT);
    $| = 1;
    for my $file (@restorefiles) {
        # Preserve the existing source's untainting behavior; archive names may
        # include whitespace allowed by the existing File::Find pattern.
        if (defined $file && $file =~ /^(.*)$/) {
            $file = $1;
        } else {
            print STDERR "Unsecure data in backup archive name\n";
            exit 2;
        }
        system('/usr/bin/dar', '-Q', '-x', $file, '-v', '-N', '-R', '/', '-wa');
        my $dar_status = $?;
        if ($dar_status == -1) {
            print STDERR "Failed to execute DAR for $file: $!\n";
            exit 3;
        } elsif ($dar_status & 127) {
            print STDERR sprintf("DAR for %s died from signal %d\n", $file, $dar_status & 127);
            exit 4;
        } elsif (($dar_status >> 8) != 0) {
            print STDERR sprintf("DAR for %s exited with status %d\n", $file, $dar_status >> 8);
            exit($dar_status >> 8 || 5);
        }
    }
    exit 0;
}

sub workstnSelRestore() {
    my $c           = shift;
    my $rec         = $cdb->get('backupwk');
    my %backupfiles = ();
    my $mntdir      = $rec->prop('Mount') || '/mnt/smb';
    my $mntbkdir;
    my $key;
    my $id = $rec->prop('Id')
        || $cdb->get('SystemName')->value . '.' . $cdb->get('DomainName')->value;
    my %blabels = ();
    my @blabels;
    my $backups = 0;
    my $filterexp;
    my $VFSType  = $rec->prop('VFSType') || 'cifs';
    my $smbhost  = $rec->prop('SmbHost');
    my $smbshare = $rec->prop('SmbShare');
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');
    my $err;
    my $error_message;
    my $setbackuplist = sub {

        if ($_ =~ /\.dar/) {
            my $dir = $File::Find::dir;
            my $backupref;
            $dir =~ s/$mntbkdir\///;
            $_ =~ s/\..*\.dar//;
            $backupref = $_;
            $_ =~ s/.*-//;
            @{ $backupfiles{$_} }[0] = $dir;
            @{ $backupfiles{$_} }[1] = $backupref;
        } ## end if ($_ =~ /\.dar/)
    };

    # Mounting backup shared folder
    $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);

    if ($error_message) {
        return ($error_message, $id);
    }

    # Test if backup subdirectory for our server
    $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message = $c->l('bac_ERR_NO_HOST_DIR') . "\n";
        $error_message .= $c->bunmount($mntdir, $VFSType);
        return ($error_message, $id);
    } ## end unless (-d $mntbkdir)
    my $catalog = "$mntbkdir/dar-catalog";
    my $i       = 0;
    my $j       = 0;
    my @bknum;
    my @setd;
    my @bkname;

    # update backups list from current catalog
    open(DAR_LIST, "/usr/bin/dar_manager -B $catalog -l |");
    $i = 0;

    while (<DAR_LIST>) {
        next unless m/set/;
        chomp;
        ($bknum[$i], $setd[$i], $bkname[$i]) = split(' ', $_, 3);
        $i++;
    } ## end while (<DAR_LIST>)
    close(DAR_LIST);

    # set drop down list of backups
    push @blabels, "0";
    $blabels{"0"} = $c->l('ALL_BACKUPS');
    $j = 0;

    while ($j < $i) {
        push @blabels, $bknum[$j];
        $blabels{ $bknum[$j] } = $bkname[$j];
        $j++;
    } ## end while ($j < $i)
} ## end sub workstnSelRestore

sub updateWorkstnBackupConfig {
    my ($c) = @_;
    my $status  = $c->param('Workstnbackup') || "";
    my $inconly = $c->param('IncOnlyTimeout');
    my $dof     = $c->param('Dof');
    my $ampm;
    my $incOnlyTimeout;
    my $rec = $cdb->get('backupwk');

    unless (defined $rec) {
        $rec = $cdb->new_record('backupwk', { type => 'service' });
    }
    my $backupwkMount = $rec->prop('Mount') || '/mnt/smb';

    unless ($status eq 'on') {

        # set service to disabled
        my $old = $cdb->get('UnsavedChanges')->value;
        $rec->set_prop('status', 'disabled');
        $cdb->get('UnsavedChanges')->set_value($old);
        system("/sbin/e-smith/signal-event", "conf-backup") == 0
            or die($c->l('bac_ERR_CONF_BACKUP') . "\n");
        return '#OK#' . $c->l('bac_SUCCESSFULLY_DISABLED_WORKSTN');
    } ## end unless ($status eq 'on')

    #--------------------------------------------------
    # Untaint parameters and check for validity
    #--------------------------------------------------
    my $VFSType = $c->param('VFSType');

    if ($VFSType eq 'nousb') {
        return $c->l('bac_ERR_NO_USB_DISK');
    }

    if ($VFSType eq 'nomnt') {
        return $c->l('bac_ERR_NO_MOUNTED_DISK');
    }
    my $backupwkStation = $c->param('BackupwkStation');
    if ($VFSType =~ m/usb|mnt/s) { $backupwkStation = 'localhost' }

    if ($backupwkStation =~ /^\s*(\S+)\s*$/) {
        $backupwkStation = $1;
    } else {
        $backupwkStation = "";
    }

    if ($backupwkStation eq "") {
        return $c->l('bac_ERR_INVALID_WORKSTN');
    }
    my $backupwkFolder = $c->param('BackupwkFolder');

    if ($backupwkFolder =~ /^(.*)$/) {
        $backupwkFolder = $1;
    } else {
        $backupwkFolder = '';
    }

    if ($VFSType eq 'usb') {
        $backupwkFolder = 'media/' . $backupwkFolder;
    }

    if ($VFSType eq 'mnt') {
        $backupwkMount = $backupwkFolder;
        if (checkMount($backupwkMount)) { $backupwkFolder = ''; }
    } else {
        $backupwkFolder =~ s/^\///;    # remove leading /
    }

    if ($backupwkFolder eq '') {
        return $c->l('bac_ERR_INVALID_FOLDER');
    }
    my $backupwkLogin = $c->param('BackupwkLogin') || '';

    if ($backupwkLogin =~ /^(.*)$/) {
        $backupwkLogin = $1;
    } else {
        $backupwkLogin = "";
    }

    if (($backupwkLogin eq "") && ($VFSType eq 'cifs')) {
        return $c->l('bac_ERR_INVALID_LOGIN');
    }
    my $backupwkPassword = $c->param('BackupwkPassword') || '';

    if ($backupwkPassword =~ /^(.*)$/) {
        $backupwkPassword = $1;
    } else {
        $backupwkPassword = "";
    }

    if (($backupwkPassword eq "") && ($VFSType eq 'cifs')) {
        return $c->l('bac_ERR_INVALID_PASSWORD');
    }
    my $setsNumber = $c->param('SetsNumber');

    unless ($setsNumber > 0) {
        return $c->l('bac_ERR_INVALID_SETS_NUMBERFOLDER');
    }
    my $filesinset = $c->param('Filesinset');

    unless ($filesinset > 0) {
        return $c->l('bac_ERR_INVALID_FILES_IN_SET_NUMBER');
    }
    my $timeout = $c->param('BackupwkTimeout');
    if (($timeout eq '') || ($timeout == 0)) { $timeout = 24 }

    if (($timeout < 1) || ($timeout > 24)) {
        return $c->l('bac_ERR_INVALID_TIMEOUT');
    }

    if (defined $inconly && $inconly eq 'on') {
        $incOnlyTimeout = 'yes';
    } else {
        $incOnlyTimeout = 'no';
    }
    my $compression = $c->param('Compression');

    if (($compression < 0) || ($compression > 9)) {
        return $c->l('bac_ERR_INVALID_COMPRESSION');
    }
    $rec->set_prop('SmbHost',        $backupwkStation);
    $rec->set_prop('SmbShare',       $backupwkFolder);
    $rec->set_prop('Mount',          $backupwkMount);
    $rec->set_prop('Login',          $backupwkLogin);
    $rec->set_prop('Password',       $backupwkPassword);
    $rec->set_prop('SetsMax',        $setsNumber);
    $rec->set_prop('DaysInSet',      $filesinset);
    $rec->set_prop('Timeout',        $timeout);
    $rec->set_prop('IncOnlyTimeout', $incOnlyTimeout);
    $rec->set_prop('Compression',    $compression);
    $rec->set_prop('FullDay',        $dof);
    $rec->set_prop('VFSType',        $VFSType);
    my $module = $rec->prop('Program');

    # The default workstation backup program is dar.
    unless (defined $module) {
        $module = 'dar';
    } elsif ($module eq '') {
        $module = 'dar';
    }
    $rec->set_prop('Program', $module);
    my $backupwkHour = $c->param('BackupwkHour');

    if ($backupwkHour =~ /^(.*)$/) {
        $backupwkHour = $1;
    } else {
        $backupwkHour = '12';
    }

    if (($backupwkHour < 0) || ($backupwkHour > 12)) {
        return $c->l('bac_ERR_INVALID_HOUR') . $backupwkHour . $c->l('bac_BETWEEN_0_AND_12');
    }
    my $backupwkMin = $c->param('BackupwkMin');

    if ($backupwkMin =~ /^(.*)$/) {
        $backupwkMin = $1;
    } else {
        $backupwkMin = '0';
    }

    if (($backupwkMin < 0) || ($backupwkMin > 59)) {
        return $c->l('bac_ERR_INVALID_MINUTE') . $backupwkMin . $c->l('bac_BETWEEN_0_AND_59');
    }
    $backupwkMin = sprintf("%02d", $backupwkMin);
    $ampm = $c->param('BackupwkAMPM');

    if ($ampm =~ /^(.*)$/) {
        $ampm = $1;
    } else {
        $ampm = 'AM';
    }

    # convert to 24 hour time
    $backupwkHour = $backupwkHour % 12;

    if ($ampm eq 'PM') {
        $backupwkHour = $backupwkHour + 12;
    }

    # variables passed validity checks, set configuration database values
    my $old = $cdb->get('UnsavedChanges')->value;
    $rec->set_prop('status',     'enabled');
    $rec->set_prop('BackupTime', "$backupwkHour:$backupwkMin");
    $cdb->get('UnsavedChanges')->set_value($old);
    system("/sbin/e-smith/signal-event", "conf-backup") == 0
        or die($c->l('bac_ERR_CONF_BACKUP'), "\n");

    # we test if the remote host is reachable, else we simply display a warning
    if ($VFSType =~ m/cifs|nfs/s) {
        my $error_message = vmount($backupwkStation, $backupwkFolder, $backupwkMount, $VFSType);

        if (!$error_message) {
            $c->bunmount($backupwkMount, $VFSType);
        } elsif ($error_message) {
            return $c->l('bac_ERROR_WHEN_TESTING_REMOTE_SERVER') . "<br>$error_message";
        }
    } ## end if ($VFSType =~ m/cifs|nfs/s)
    return
          '#OK#'
        . $c->l('bac_SUCCESSFULLY_ENABLED_WORKSTN') . '<br>'
        . $c->l('bac_WITH_BACKUP_TIME')
        . " $backupwkHour:$backupwkMin";
} ## end sub updateWorkstnBackupConfig

sub performWorkstnSelRestore {
    my ($c, $seldatebefore, $restorefiles) = @_;
    my $out;
    my @restorelist;

    foreach (@{$restorefiles}) {
        push @restorelist, "\"" . $1 . "\"" if ($_ =~ /^(.*)$/);
    }
    my $backupwkrec = $cdb->get('backupwk');
    my $id          = $backupwkrec->prop('Id')
        || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my $mntdir  = $backupwkrec->prop('Mount')   || '/mnt/smb';
    my $VFSType = $backupwkrec->prop('VFSType') || 'cifs';
    my $smbhost = $backupwkrec->prop('SmbHost');
    my $smbshare = $backupwkrec->prop('SmbShare');
    my $err;
    my $error_message;
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');

    # Mounting backup shared folder
    $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);

    if ($error_message) {
        $error_message .= " : $id";
        return $error_message;
    }

    # Test if backup subdirectory for our server
    my $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message = $c->l('bac_ERR_NO_HOST_DIR') . "\n";
        $error_message .= $c->bunmount($mntdir, $VFSType);
        $error_message .= " : $id";
        return $error_message;
    } ## end unless (-d $mntbkdir)

    # backup is online, restoring now
    $| = 1;
    my $restorerr;

    if (open(RD, "-|")) {

        #-----------------------------------------------------
        # restore system from uploaded workstation backup file
        #-----------------------------------------------------
        $out .= "<b>" . $c->l('bac_FILES_HAVE_BEEN_RESTORED') . "</b> \n";
        $out .= '<UL>';

        while (<RD>) {
            $out .= "<li>$_</li>\n";
        }
        $out .= '</UL>';
        my $message;

        if (!close RD) {
            $message = $c->l('bac_RESTORE_FAILED_MSG');
        } else {

            if ($restorerr) {
                $message = $c->l('bac_RESTORE_FAILED');
            } else {
                $message = $c->l('bac_RESTORE_COMPLETE');
            }
        } ## end else [ if (!close RD) ]
        $out .= "<b>$message </b>\n";
    } else {
        select(STDOUT);
        $| = 1;

        if ($seldatebefore) {
            $restorerr
                = system(
                "/usr/bin/dar_manager -B \"$mntbkdir/dar-catalog\" -Q -w $seldatebefore -e '-v -N -R / -w' -r @restorelist"
                );
        } else {
            $restorerr
                = system("/usr/bin/dar_manager -B \"$mntbkdir/dar-catalog\" -Q -k -e '-v -N -R / -w' -r @restorelist");
        }
        $error_message = $c->bunmount($mntdir, $VFSType);
        die($error_message) if $error_message;
        exit(0);
    } ## end else [ if (open(RD, "-|")) ]
    return "#OK#" . $out;
} ## end sub performWorkstnSelRestore

sub performReboot {
    my ($c) = @_;

    #print "$c->l('bac_SERVER_REBOOT')";
    #print "$c->l('bac_SERVER_WILL_REBOOT')";
    warn "reboot coming";
    esmith::util::backgroundCommand(2, "/sbin/e-smith/signal-event", "reboot");
    return "#OK#" . $c->l('bac_SERVER_WILL_REBOOT');
} ## end sub performReboot

sub get_VFSType_options {
    my $c = shift;
    return [
        [ $c->l('cifs')                 => 'cifs' ],
        [ $c->l('nfs')                  => 'nfs' ],
        [ $c->l('local removable disk') => 'usb' ],
        [ $c->l('Mounted disk')         => 'mnt' ]
    ];
} ## end sub get_VFSType_options

sub get_dow_list {
    my $c       = shift;
    my @list    = ();
    my @dlabels = split(' ', $c->l('bac_DOW'));
    my $i       = 0;

    foreach (@dlabels) {
        push @list, [ "$_" => "$i" ];
        $i++;
    }

    # put 'everyday' first
    my $lastr = pop @list;
    unshift @list, $lastr;
    return \@list;
} ## end sub get_dow_list

sub get_BackupwkDest_options {
    my ($c, $VFSType) = @_;
    my @usbdisks = ();

    if ($VFSType eq 'usb') {
        my $devices = esmith::BlockDevices->new('allowmount' => 'disabled');
        my ($valid, $invalid) = $devices->checkBackupDrives(0);

        if (${$valid}[0]) {
            foreach (@{$valid}) {
                push @usbdisks, $devices->label($_);
            }
        } ## end if (${$valid}[0])

        if (!$usbdisks[0]) {
            push(@usbdisks, $c->l('bac_No suitable local devices found'));
        }
        $devices->destroy;

        #foreach my $udi (qx(hal-find-by-property --key volume.fsusage --string filesystem)) {
        #$udi =~ m/^(\S+)/;
        #my $is_mounted = qx(hal-get-property --udi $1 --key volume.is_mounted);
        #if ($is_mounted eq "false\n") {
        #my $vollbl = qx(hal-get-property --udi $1 --key volume.label);
        #$vollbl =~ m/^(\S+)/;
        #if ($vollbl =~ /^\s/) {$vollbl = 'nolabel';}
        #chomp $vollbl;
        #push @usbdisks, $vollbl;
        #}
        #}
        #    return undef unless ($usbdisks[0]);
    } ## end if ($VFSType eq 'usb')

    if ($VFSType eq 'mnt') {
        @usbdisks = findmnt();

        #    return undef unless ($usbdisks[0]);
    } ## end if ($VFSType eq 'mnt')
    return \@usbdisks;
} ## end sub get_BackupwkDest_options

sub get_function_options {
    my $c = shift;
    return [
        [ $c->l('bac_DESKTOP_BACKUP')      => 'desktop_backup' ],
        [ $c->l('bac_TAPE_CONFIGURE')      => 'tape_configure' ],
        [ $c->l('bac_TAPE_RESTORE')        => 'tape_restore' ],
        [ $c->l('bac_WORKSTN_CONFIGURE')   => 'workstn_configure' ],
        [ $c->l('bac_WORKSTN_VERIFY')      => 'workstn_verify' ],
        [ $c->l('bac_WORKSTN_RESTORE')     => 'workstn_restore' ],
        [ $c->l('bac_WORKSTN_SEL_RESTORE') => 'workstn_sel_restore' ]
    ];
} ## end sub get_function_options

sub get_shared_folder_to_verify () {
    my ($c) = @_;
    my $rec = $cdb->get('backupwk');
    return undef unless $rec;
    my $id       = $rec->prop('Id') || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my $smbhost  = $rec->prop('SmbHost');
    my $smbshare = $rec->prop('SmbShare');
    return "$smbhost/$smbshare/$id";
} ## end sub get_shared_folder_to_verify

sub get_Backupset_options () {
    my ($c) = @_;
    my $rec = $cdb->get('backupwk');
    return undef unless $rec;
    my %backupfiles = ();
    my $mntdir      = $rec->prop('Mount') || '/mnt/smb';
    my $id          = $rec->prop('Id') || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my $smbhost     = $rec->prop('SmbHost');
    my $smbshare    = $rec->prop('SmbShare');
    my $mntbkdir;
    my $key;
    my $VFSType = $rec->prop('VFSType') || 'cifs';
    my $err;
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');
    my $setbackuplist = sub {
		$c->app->log->info("File presented: $_");
        if ($_ =~ /\.dar/) {
            my $dir = $File::Find::dir;
            my $backupref;
            $dir =~ s/$mntbkdir\///;
            $_ =~ s/\..*\.dar//;
            $backupref = $_;
            $_ =~ s/.*-//;
            @{ $backupfiles{$_} }[0] = $dir;
            @{ $backupfiles{$_} }[1] = $backupref;
        } ## end if ($_ =~ /\.dar/)
    };

    # Mounting backup shared folder
    my $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);
    return [] if $error_message;

    # Test if backup subdirectory for our server
    $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message .= $c->bunmount($mntdir, $VFSType);
        return [];
    }

    # Finding existing backups
    
    find { wanted => \&$setbackuplist, untaint => 1, untaint_pattern => qr|^([-+@\w\s./]+)$| }, $mntbkdir;
    my %blabels = ();
    my @list;

    foreach $key (sort keys %backupfiles) {
        my $labkey = $mntbkdir . '/' . $backupfiles{$key}[0] . '/' . $backupfiles{$key}[1];
        $blabels{$labkey} = $backupfiles{$key}[1] . " (" . $backupfiles{$key}[0] . ")";
        $c->app->log->info("Pushing $blabels{$labkey} to $labkey");
        push @list, [ "$blabels{$labkey}" => "$labkey" ];
    } ## end foreach $key (sort keys %backupfiles)
    $error_message .= $c->bunmount($mntdir, $VFSType);
    return \@list;
} ## end sub get_Backupset_options

sub get_Restoreset_options () {
    my ($c) = @_;
    my $rec = $cdb->get('backupwk');
    return [] unless $rec;
    my %backupfiles = ();
    my $mntdir      = $rec->prop('Mount') || '/mnt/smb';
    my $id          = $rec->prop('Id') || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my $smbhost     = $rec->prop('SmbHost');
    my $smbshare    = $rec->prop('SmbShare');
    my $mntbkdir;
    my $key;
    my $VFSType = $rec->prop('VFSType') || 'cifs';
    my $err;
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');
    my $setbackuplist = sub {

        if ($_ =~ /\.dar/) {
            my $dir = $File::Find::dir;
            my $backupref;
            $dir =~ s/$mntbkdir\///;
            $_ =~ s/\..*\.dar//;
            $backupref = $_;
            $_ =~ s/.*-//;
            @{ $backupfiles{$_} }[0] = $dir;
            @{ $backupfiles{$_} }[1] = $backupref;
        } ## end if ($_ =~ /\.dar/)
    };

    # Mounting backup shared folder
    my $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);
    return [] if $error_message;

    # Test if backup subdirectory for our server
    $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message .= $c->bunmount($mntdir, $VFSType);
        return [];
    }
    my $catalog = "$mntbkdir/dar-catalog";
    my $i       = 0;
    my $j       = 0;
    my @bknum;
    my @setd;
    my @bkname;

    # update backups list from current catalog
    open(DAR_LIST, "/usr/bin/dar_manager -B $catalog -l |");
    $i = 0;

    while (<DAR_LIST>) {
        next unless m/set/;
        chomp;
        ($bknum[$i], $setd[$i], $bkname[$i]) = split(' ', $_, 3);
        $i++;
    } ## end while (<DAR_LIST>)
    close(DAR_LIST);
    my @list;

    # set drop down list of backups
    push @list, [ $c->l('bac_ALL_BACKUPS') => "0" ];
    $j = 0;

    while ($j < $i) {
        push @list, [ $bkname[$j] => "$bknum[$j]" ];
        $j++;
    }
    $error_message .= $c->bunmount($mntdir, $VFSType);
    return \@list;
} ## end sub get_Restoreset_options

sub get_Restorefiles_options {
    my ($c, $filterexp, $backupkey) = @_;
    my $rgfilter;

    if ($filterexp =~ /^(.*)$/) {
        $filterexp = $1;
        $rgfilter  = qr/$filterexp/;
    } else {
        $filterexp = "";
    }

    if ($backupkey =~ /^(.*)$/) {
        $backupkey = $1;
    } else {
        die('Unsecure data : ' . $backupkey);
    }
    #my $seldatebf; - Not used anywhere
    my $backupwkrec = $cdb->get('backupwk');
    my $smbhost     = $backupwkrec->prop('SmbHost');
    my $smbshare    = $backupwkrec->prop('SmbShare');
    my $mntdir      = $backupwkrec->prop('Mount') || '/mnt/smb';
    my $key;
    my $id = $backupwkrec->prop('Id')
        || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my @flabels;
    my %flabels = ();
    my $VFSType = $backupwkrec->prop('VFSType') || 'cifs';
    my $err;
    my $error_message;
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');

    # Mounting backup shared folder
    $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);

    if ($error_message) {
        warn "Backup - restore files: $error_message, $id \n";
        return undef;
    }

    # Test if backup subdirectory for our server
    my $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message = $c->l('bac_ERR_NO_HOST_DIR') . "\n";
        $error_message .= $c->bunmount($mntdir, $VFSType);
        warn "Backup - restore files: $error_message, $id \n";
        return undef;
    } ## end unless (-d $mntbkdir)

    # Read wanted file list from selected backup
    if (open(RD, "-|")) {
        my $regex = qr/\[.*\] */;

        while (<RD>) {
            chomp;
            $_ =~ s/$regex//;
            if ($filterexp) { next unless m/$rgfilter/ }
            push @flabels, $_;
        } ## end while (<RD>)
        my $status
            = close RD
            ? $c->l('bac_READ_COMPLETE')
            : ($c->l('bac_ERROR_READING_FILE') . ' : ' . $backupkey);
    } else {
        select(STDOUT);
        $| = 1;
        system("/usr/bin/dar_manager", "-B", "$mntbkdir/dar-catalog", "-u", "$backupkey") == 0
            or die($c->l('bac_ERR_EXTRACT') . " : " . $!);
        $error_message = $c->bunmount($mntdir, $VFSType);
        die($error_message) if $error_message;
        exit(0);
    } ## end else [ if (open(RD, "-|")) ]
    $error_message .= $c->bunmount($mntdir, $VFSType);
    return \@flabels;
} ## end sub get_Restorefiles_options

sub CalculateSizes () {
    my $c = shift;

    my $es_backup = new esmith::Backup or die "Couldn't create Backup object\n";
    my @directories = $es_backup->restore_list;
    @directories = grep { -e "/$_" } @directories;
    my @backup_excludes = $es_backup->excludes;

    #------------------------------------------------------------
    # figure out the size of the tar file.
    #------------------------------------------------------------
    my $tarsize = 0;

    # Estimate /home/e-smith using user quotas.
    my $dev = Quota::getqcarg("/home/e-smith/files");

    foreach my $user ($adb->users()) {
        my $name = $user->key;
        my $uid  = getpwnam($name);

        unless (defined $uid) {
            warn($c->l('bac_NO_UID_FOR_NAME') . $name . "\n");
            next;
        }

        my ($blocks) = Quota::query($dev, $uid, 0);
		#$c->app->log->info("Users:$name($uid) $blocks");
        $tarsize += $blocks;
    }
    #$c->app->log->info("tarsize:$tarsize");
    
    # Check Admin separately (backups)
	my $admin_uid = getpwnam('admin');
	if (defined $admin_uid) {
		my ($admin_blocks) = Quota::query($dev, $admin_uid, 0);
        $tarsize += $admin_blocks;
		#$c->app->log->info("Admin($admin_uid) backups: $admin_blocks blocks");
	} else {
		$c->app->log->info("Admin UID not found");
	}

    # Add root-owned directories (excluding /home/e-smith) using du -s.
    my @list = map { "/$_" } grep { !m{^home/e-smith(?:/|$)} } @directories;

    if (@list) {
        my $pid = open(my $DU, "-|");
        if (!defined $pid) {
            warn "Unable to fork for du: $!";
        } elsif ($pid == 0) {
            exec '/usr/bin/du', '-s', @list
              or do {
                  warn "exec du failed: $!";
                  exit 1;
              };
        } else {
            while (<$DU>) {
                my ($du) = split(/\s+/, $_);
                $tarsize += $du if defined $du;
            }
            close $DU;
            waitpid($pid, 0);
        }
    }

    #$c->app->log->info("tarsize:$tarsize");
    $tarsize = showSize($tarsize);
    #$c->app->log->info("tarsize:$tarsize");

    #------------------------------------------------------------
    # figure out the size of the dump files
    #------------------------------------------------------------
    my $dumpsize = 0;

    ## Example: estimate DB dump size using mysqldump piped to wc -c.
    ## Adjust the database list or credentials to your environment.
    #my $dump_pid = open(my $DUMP, "-|");
    #if (!defined $dump_pid) {
        #warn "Unable to fork for mysqldump size check: $!";
    #} elsif ($dump_pid == 0) {
        ## Child: write combined dump to stdout, then exit.
        #exec '/usr/bin/mariadb-dump', '--all-databases', '--single-transaction',
             #'--quick', '--no-tablespaces'
          #or do {
              #warn "exec mysqldump failed: $!";
              #exit 1;
          #};
    #} else {
        ## Parent: measure bytes read from mysqldump.
        #my $bytes = 0;
        #my $buf;
        #while (read($DUMP, $buf, 65536)) {
            #$bytes += length($buf);
        #}
        #close $DUMP;
        #waitpid($dump_pid, 0);

        ## Convert bytes to 1K blocks to be in line with du/df units.
        ## 1024-byte blocks:
        #my $blocks = int(($bytes + 1023) / 1024);
        #$dumpsize = $blocks;
    #}

	open(DF, "-|")
       or exec '/bin/df', '-P', '-t', 'ext4', '-t', 'xfs';
    while (<DF>) {
        next unless (/^\//);
        (undef, undef, my $s, undef) = split(/\s+/, $_);
        $dumpsize += $s;
    } ## end while (<DF>)


    # Increase size by 10% to cope with dump overhead (indexes, metadata).
    $dumpsize = int($dumpsize * 1.1);
    $dumpsize = showSize($dumpsize);

    #------------------------------------------------------------
    # how much free space is in /tmp
    #------------------------------------------------------------
    my $tmp_total  = 0;
    my $tmp_avail  = 0;

    my $df_pid = open(my $DF, "-|");
    if (!defined $df_pid) {
        warn "Unable to fork for df /tmp: $!";
    } elsif ($df_pid == 0) {
        exec '/bin/df', '-P', '-t', 'ext4', '-t', 'xfs', '/tmp'
          or do {
              warn "exec df failed: $!";
              exit 1;
          };
    } else {
        while (<$DF>) {
            next if /^Filesystem\b/;
            next unless /^\//;

            my (undef, $blocks, undef, $avail) = split(/\s+/, $_);
            $tmp_total += $blocks if defined $blocks;
            $tmp_avail += $avail  if defined $avail;
        }
        close $DF;
        waitpid($df_pid, 0);
    }

    # For sizing, many GUIs compare against available space;
    # "half free" is based on available blocks.
    my $tmpfree_blocks  = $tmp_avail;
    my $halffree_blocks = int($tmp_avail / 2);

    my $tmpfree  = showSize($tmpfree_blocks);
    my $halffree = showSize($halffree_blocks);

    return ($tarsize, $dumpsize, $tmpfree, $halffree);
}


sub showSize {
    my $size = shift;
    my $Mb = 1024;
    my $Gb = $Mb * $Mb;
    my $Tb = $Gb * $Mb;

    if ($size >= $Tb) {
        return int($size / $Tb) . "Tb";
    } elsif ($size >= $Gb) {
        return int($size / $Gb) . "Gb";
    } elsif ($size >= $Mb) {
        return int($size / $Mb) . "Mb";
    } else {
        return int($size) . "kb";  # Fixed!
    }
}

sub desktopBackupRecordStatus {
    my ($c,$backup, $phase, $status) = @_;
    my $now = time();
    warn("Backup terminated: $phase failed - status: $status\n");
    $backup->set_prop('EndEpochTime', "$now");
    $backup->set_prop('Result',       "$phase:$status");
} ## end sub desktopBackupRecordStatus

sub dmount {

    # mount dar unit according to dar-workstation configuration
    # return nothing if mount successfull
    my ($host, $share, $mountdir, $login, $password, $VFSType) = @_;

    if ($VFSType eq 'cifs') {
        return (qx(/bin/mount -t cifs "//$host/$share" $mountdir -o credentials=/etc/dar/CIFScredentials,nounix 2>&1));
    } elsif ($VFSType eq 'nfs') {
        return (qx(/bin/mount -t nfs -o nolock "$host:/$share" $mountdir 2>&1));
    } elsif ($VFSType eq 'usb') {
        my $device  = "";
        my $vollbl  = "";
        my $devices = esmith::BlockDevices->new('allowmount' => 'disabled');
        my ($valid, $invalid) = $devices->checkBackupDrives(0);

        if (${$valid}[0]) {
            foreach (@{$valid}) {
                $vollbl = $devices->label($_);

                if ($share eq "media/$vollbl") {
                    $device = "/dev/$_";
                }
            } ## end foreach (@{$valid})
        } ## end if (${$valid}[0])
        $devices->destroy;
        return (qx (mount $device /$share 2>&1));

        #-------------------------------------------------------------------------------------------------------
        #my $device = "";
        #my $blkdev = "";
        #my $vollbl = "";
        #foreach my $udi (qx(hal-find-by-property --key volume.fsusage --string filesystem)) {
        #$udi =~ m/^(\S+)/;
        #my $is_mounted = qx(hal-get-property --udi $1 --key volume.is_mounted);
        #if ($is_mounted eq "false\n") {
        #$blkdev = qx(hal-get-property --udi $1 --key block.device);
        #if ($blkdev =~ m/^(\S+)/) {$blkdev = $1;}
        #}
        #if ($is_mounted eq "false\n") {
        #$vollbl = qx(hal-get-property --udi $1 --key volume.label);
        #$vollbl =~ m/^(\S+)/;
        #if ($vollbl =~ /^\s/) {$vollbl = 'nolabel';}
        #}
        #chomp $vollbl;
        #chomp $blkdev;
        #$vollbl = "media/$vollbl";
        #if  ($vollbl eq $share) {
        #$device = $blkdev;
        #}
        #}
        #return ( qx(/bin/mount $device "/$share" 2>&1) );
        #-------------------------------------------------------------------------------------------------------
    } else {
        return ("Error while mounting $host/$share : $VFSType not supported.\n");
    }
} ## end sub dmount

sub checkMount {

    # check if $mountdir is mounted
    my $mountdir = shift;
    $| = 1;    # Auto-flush

    # copy STDOUT to another filehandle
    open(my $STDOLD, '>&', STDOUT);
    open(STDOUT, ">/dev/null");
    if (open(MOUNTDIR, "|-", "/bin/findmnt", $mountdir)) {;}

    # restore STDOUT
    open(STDOUT, '>&', $STDOLD);
    return (!close(MOUNTDIR));
} ## end sub checkMount

sub bmount {
    my ($c, $mntdir, $host, $share, $VFSType) = @_;

    # verify backup directory not already mounted
    if (!checkMount($mntdir)) {
        return if ($VFSType eq 'mnt');
        return ($c->l('bac_ERR_ALREADY_MOUNTED'));
    } else {

        if ($VFSType eq 'mnt') {
            return ($c->l('bac_ERR_NOT_MOUNTED'));
        }
    } ## end else [ if (!checkMount($mntdir...))]

    # create the directory mount point if it does not exist
    my $err = createTree($mntdir);
    return ($c->l('bac_ERR_MOUNTING_SMBSHARE') . "<//$host/$share>\n" . $err) if $err;

    # mount the backup directory
    $err = dmount($host, $share, $mntdir, '', '', $VFSType);
    return ($c->l('bac_ERR_MOUNTING_SMBSHARE') . "<//$host/$share>\n" . $err) if $err;

    # verify $mntdir is mounted
    if (checkMount($mntdir)) {

        # The mount should have suceeded, but sometimes it needs more time,
        # so sleep and then check again.
        sleep 5;

        if (checkMount($mntdir)) {
            return ($c->l('bac_ERR_NOT_MOUNTED'));
        }
    } ## end if (checkMount($mntdir...))
    return;
} ## end sub bmount

sub bunmount {
    my ($c, $mount, $type) = @_;
    return if ($type eq 'mnt');    # Don't unmount for type 'mnt'

    if (!checkMount($mount)) {
        system('/bin/umount', '-f', $mount) == 0
            or return ($c->l('bac_ERR_WHILE_UNMOUNTING'));
    }
    return "";
} ## end sub bunmount

sub findmnt {
    my @mntin = qx( findmnt -n -l -o TARGET );
    my @mntout;

    foreach my $mount (@mntin) {
        next if ($mount =~ m/^\/proc|^\/dev|^\/sys|^\/boot/s);
        chomp $mount;
        next if ($mount eq '/');
        push @mntout, $mount;
    } ## end foreach my $mount (@mntin)
    return @mntout;
} ## end sub findmnt

sub createTree {
    my $tree = shift;

    if (!-d "$tree") {
        eval { make_path("$tree") };
        return ("Error while creating $tree : $@. Maybe insufficient rights directory.\n") if $@;
    }
    return;
} ## end sub createTree

sub vmount {

    #Used to test if the remote share is mountable when you save settings in database
    # mount dar unit according to dar-workstation configuration in order to test the remote host
    # return nothing if mount successfull
    my ($host, $share, $mountdir, $VFSType) = @_;

    if ($VFSType eq 'cifs') {
        return (qx(/bin/mount -t cifs "//$host/$share" $mountdir -o credentials=/etc/dar/CIFScredentials,nounix 2>&1));
    } elsif ($VFSType eq 'nfs') {
        return (qx(/bin/mount -t nfs -o nolock,timeo=30,retrans=1,retry=0 "$host:/$share" $mountdir 2>&1));
    }
} ## end sub vmount
1;
