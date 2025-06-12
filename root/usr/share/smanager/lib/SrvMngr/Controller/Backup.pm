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
my $es_backup = new esmith::Backup or die "Couldn't create Backup object\n";
my @directories = $es_backup->restore_list;
@directories = grep { -e "/$_" } @directories;
my @backup_excludes = $es_backup->excludes;

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
    my ($backup_status, $backupwk_status) = 'disabled';

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
    my ($res, $result) = '';
    my $function = $c->param('Function');
   $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open config db";
   $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
   $rdb = esmith::ConfigDB::UTF8->open('/etc/e-smith/restore');

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
            $bac_datas{function} = $function;
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
    my ($dest, $res, $result) = '';

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
        ##$result .= ' ** Blocked for testing ** !';
        $res = 'NOK';

        if (!$result) {
            $res = $c->workstnRestore();

            if (($result = $res) =~ s|^#OK#||) {
                $bac_datas{restore_log} = $result;
                $res = 'OK';
            } else {
                $c->stash(error => $result);
            }
            $bac_datas{function} = 'workstn_restore1';
            $res = 'NEXT';
        } ## end if (!$result)
    } ## end if ($function eq 'workstn_restore')

    if ($function eq 'workstn_restore1') {
        my $state = 'unknown';
        my $rec   = $rdb->get('restore');

        if ($rec) {
            $state = $rec->prop('state') || 'unknown';
        }
        $result .= "Restore state unexpected: $state" if ($state ne 'complete');
        $res = 'NOK';

        if (!$result) {
            $res = $c->performReboot();

            if (($result = $res) =~ s|^#OK#||) {
                $res = 'OK';
            } else {
                $c->stash(error => $result);
            }
        } ## end if (!$result)
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
    my $enabledIncOnlyTimeout = "";
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

sub workstnRestore {
    my ($c) = @_;
    my $out = '';
    my $restoreref = $c->param('Backupset');
    my $set        = $restoreref;
    $set =~ s/\/[^\/]*$//;
    my %backupsetfiles = ();
    my @restorefiles;
    my $backupsetlist = sub {

        if ($_ =~ /\.dar/) {
            my $backupref = $File::Find::name;
            $backupref =~ s/\.[0-9]+\.dar//;
            $_ =~ s/\..*\.dar//;
            $_ =~ s/.*-//;
            $backupsetfiles{$_} = $backupref;
        } ## end if ($_ =~ /\.dar/)
    };
    my $lock_file   = "/var/lock/subsys/e-smith-restore";
    my $file_handle = &esmith::lockfile::LockFileOrReturn($lock_file);

    unless ($file_handle) {
        return "$c->l('bac_RESTORE_CANNOT_PROCEED') <br> ($c->l('bac_ANOTHER_RESTORE_IN_PROGRESS')";
    }
    my $backupwkrec = $cdb->get('backupwk');
    my $id          = $backupwkrec->prop('Id')
        || $cdb->get('SystemName')->value . "." . $cdb->get('DomainName')->value;
    my $mntdir  = $backupwkrec->prop('Mount')   || '/mnt/smb';
    my $VFSType = $backupwkrec->prop('VFSType') || 'cifs';
    my $smbhost = $backupwkrec->prop('SmbHost');
    my $smbshare = $backupwkrec->prop('SmbShare');
    $mntdir = "/$smbshare" if ($VFSType eq 'usb');
    my $err;
    my $error_message;

    # Mounting backup shared folder
    $error_message = $c->bmount($mntdir, $smbhost, $smbshare, $VFSType);

    if ($error_message) {
        return "$c->l('bac_RESTORE_CANNOT_PROCEED') $error_message : $id";
    }

    # Test if backup subdirectory for our server
    my $mntbkdir = $mntdir . "/$id";

    unless (-d $mntbkdir) {
        $error_message = $c->l('bac_ERR_NO_HOST_DIR') . "\n";
        $error_message .= $c->bunmount($mntdir, $VFSType);
        return "$c->l('bac_RESTORE_CANNOT_PROCEED') $error_message : $id";
    } ## end unless (-d $mntbkdir)

    # finding list of available backups
    # and verifying all needed backup files are available
    find { wanted => \&$backupsetlist, untaint => 1, untaint_pattern => qr|^([-+@\w\s./]+)$| }, $set;
    my $key;
    my $num = 0;

    foreach $key (sort keys %backupsetfiles) {
        push @restorefiles, $backupsetfiles{$key};

        if ($num == 0) {
            unless ($backupsetfiles{$key} =~ /\/full-/) {
                return "$c->l('bac_RESTORE_CANNOT_PROCEED') $c->l('bac_ERR_NO_FULL_BACKUP')";
            }
        } else {
            my $numf = sprintf("%03d", $num);

            unless ($backupsetfiles{$key} =~ /\/inc-$numf-/) {
                return "$c->l('bac_RESTORE_CANNOT_PROCEED') $c->l('bac_ERR_NO_INC_BACKUP') . $numf";
            }
        } ## end else [ if ($num == 0) ]
        $num++;
        last if ($backupsetfiles{$key} eq $restoreref);
    } ## end foreach $key (sort keys %backupsetfiles)

    # backup is online, restoring now
    my $rec = $rdb->get('restore');
    $rec->set_prop('state', 'running');
    $rec->set_prop('start', time);
    $cdb->get('bootstrap-console')->set_prop('Run', 'yes');

    unless (system("/sbin/e-smith/signal-event", "pre-restore") == 0) {
        return "$c->l('bac_OPERATION_STATUS_REPORT') $c->l('bac_ERR_PRE_RESTORE')";
    }
    $| = 1;
    my $RD;

    if (open(RD, "-|")) {

        #-----------------------------------------------------
        # restore system from uploaded workstation backup file
        #-----------------------------------------------------
        $out .= $c->l('bac_FILES_HAVE_BEEN_RESTORED') . "\n";
        $out .= '<UL>';
        my $complete = 0;

        while (<RD>) {
            $complete++ if /etc\/samba\/smbpasswd$/;
            $out .= "<li>$_</li>\n";
        }
        $out .= '</UL>';
        my $message;

        if (!close RD) {
            $message = $c->l('bac_RESTORE_FAILED_MSG');
        } else {

            #-----------------------------------------------------
            # if restore completed, regenerate configuration files
            #-----------------------------------------------------
            if ($complete) {
                $out .= $c->l('bac_RESTORE_COMPLETE');
                system("/usr/sbin/groupmod", "-g", "$www_gid", "www") == 0
                    or warn($c->l('bac_ERR_RESTORING_GID') . "\n");
                system("/usr/sbin/usermod", "-g", "$www_gid", "www") == 0
                    or warn($c->l('bac_ERR_RESTORING_INITIAL_GRP') . "\n");
                esmith::util::backgroundCommand(0, "/sbin/e-smith/signal-event", "post-upgrade");

                	#system("/sbin/e-smith/signal-event", "post-upgrade") == 0 
                	#    or die ($c->l('bac_ERROR_UPDATING_CONFIGURATION')."\n");
            } else {
                $message = $c->l('bac_RESTORE_FAILED');
            }
        } ## end else [ if (!close RD) ]
        return $message if $message;
        $rec->set_prop('state',  'complete');
        $rec->set_prop('finish', time);
        &esmith::lockfile::UnlockFile($file_handle);
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
            system("/usr/bin/dar", "-Q", "-x", "$file", "-v", "-N", "-R", "/", "-wa");
        } ## end foreach $file (@restorefiles)
        $error_message = $c->bunmount($mntdir, $VFSType);
        die($error_message) if $error_message;
        exit(0);
    } ## end else [ if (open(RD, "-|")) ]
    
	#my $RD;

	## Fork-safe open with explicit error handling
	#unless (open($RD, "-|")) {
		## Child process
		#local $SIG{__DIE__} = sub { exit 255 };
		#$| = 1;  # Autoflush

		#eval {
			#foreach my $file (@restorefiles) {
				## Security: strict filename validation
				#unless ($file =~ m{^[\w\/.-]+$}) {
					#die "Invalid filename: $file";
				#}
				
				## Check file existence
				#unless (-e $file) {
					#die "Backup file $file does not exist";
				#}

				## Execute dar with error checking
				#system("/usr/bin/dar", "-Q", "-x", $file, "-v", "-N", "-R", "/", "-wa");
				#if ($? == -1) {
					#die "Failed to execute dar: $!";
				#} elsif ($? & 127) {
					#die sprintf("dar died with signal %d, %s coredump",
						#($? & 127), ($? & 128) ? 'with' : 'without');
				#} elsif ($? >> 8 != 0) {
					#die "dar exited with error code " . ($? >> 8);
				#}
			#}

			## Unmount with error checking
			#if (my $unmount_err = $c->bunmount($mntdir, $VFSType)) {
				#die "Unmount failed: $unmount_err";
			#}
		#};

		#if (my $child_err = $@) {
			#print STDERR "CHILD ERROR: $child_err";
			#exit 254;
		#}
		#exit 0;
	#} 
	#else {
		## Parent process
		#eval {
			## Verify fork succeeded
			#unless (defined $RD) {
				#die "Fork failed: $!";
			#}

			#$out .= $c->l('bac_FILES_HAVE_BEEN_RESTORED') . "\n<UL>";
			#my $complete = 0;

			## Read from child process
			#while (<$RD>) {
				#$complete++ if /etc\/samba\/smbpasswd$/;
				#$out .= "<li>$_</li>\n";
			#}
			#$out .= "</UL>";

			## Close pipe and check status
			#unless (close $RD) {
				#die "Pipe close failed: $!";
			#}

			#my $child_status = $?;
			#if ($child_status != 0) {
				#die "Child process failed with status " . ($child_status >> 8);
			#}

			## Post-restore actions
			#if ($complete) {
				#system("/usr/sbin/groupmod", "-g", $www_gid, "www");
				#if ($? != 0) {
					#die $c->l('bac_ERR_RESTORING_GID') . ": $! (status $?)";
				#}

				#system("/usr/sbin/usermod", "-g", $www_gid, "www");
				#if ($? != 0) {
					#die $c->l('bac_ERR_RESTORING_INITIAL_GRP') . ": $! (status $?)";
				#}

				#my $bg_result = esmith::util::backgroundCommand(0, "/sbin/e-smith/signal-event", "post-upgrade");
				#unless ($bg_result) {
					#die "Failed to schedule post-upgrade event";
				#}
			#} else {
				#die $c->l('bac_RESTORE_FAILED');
			#}
		#};

		## Error handling
		#if (my $err = $@) {
			#$rec->set_prop('state', 'failed');
			#$rec->set_prop('error', "$err");
			#esmith::lockfile::UnlockFile($file_handle);
			#return $c->l('bac_RESTORE_FAILED_MSG') . ": $err";
		#}
	#}       
	$rdb->reload;
	$error_message .= $c->bunmount($mntdir, $VFSType);
	return '#OK#' . $out;
} ## end sub workstnRestore

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
    my $seldatebf;
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

    #------------------------------------------------------------
    # figure out the size of the tar file.
    #------------------------------------------------------------
    my $tarsize = 0;

    # It takes way too much time to do a du on /home/e-smith. So we'll
    # estimate the current size.
    # We do this by checking the quota used by each user on the system.
    # Get a $dev value appropriate for use in Quota::query call.
    my $dev = Quota::getqcarg("/home/e-smith/files");

    foreach my $user ($adb->users()) {
        my $name = $user->key;
        my $uid  = getpwnam($name);

        unless ($uid) {
            warn($c->l('bac_NO_UID_FOR_NAME') . $name . "\n");

            # We shouldn't ever get here. If we do, we can't get
            # the quota value for this user, so we just skip to
            # the next one.
            next;
        } ## end unless ($uid)

        # Get current quota settings.
        my ($blocks) = Quota::query($dev, $uid, 0);
        $tarsize += $blocks;
    } ## end foreach my $user ($adb->users...)

    # We add to this the size of root owned firectories, estimated using du.
    # If this takes too long, then the admin only has his or
    # herself to blame!
    # Remove /home/e-smith from backup list, and make paths absolute
    my @list = map {"/$_"} grep { !/home\/e-smith/ } @directories;
    open(DU, "-|")
        or exec '/usr/bin/du', '-s', @list;

    while (<DU>) {
        my ($du) = split(/\s+/);
        $tarsize += $du;
    }
    close DU;
    $tarsize = showSize($tarsize);

    #------------------------------------------------------------
    # figure out the size of the dump files
    #------------------------------------------------------------
    my $dumpsize = 0;
    open(DF, "-|")
        or exec '/bin/df', '-P', '-t', 'ext4', '-t', 'xfs';

    while (<DF>) {
        next unless (/^\//);
        (undef, undef, my $s, undef) = split(/\s+/, $_);
        $dumpsize += $s;
    } ## end while (<DF>)

    # increase size by 10% to cope with dump overhead.
    $dumpsize *= 1.1;
    close DF;
    $dumpsize = showSize($dumpsize);

    #------------------------------------------------------------
    # how much free space is in /tmp
    #------------------------------------------------------------
    my $tmpfree  = 0;
    my $halffree = 0;
    open(DF, "-|")
        or exec '/bin/df', '-P', '-t', 'ext4', '-t', 'xfs', '/tmp';

    while (<DF>) {
        next unless (/^\//);
        (undef, undef, undef, my $s) = split(/\s+/, $_);
        $tmpfree += $s;
    } ## end while (<DF>)
    close DF;
    $halffree = $tmpfree / 2;
    $tmpfree  = showSize($tmpfree);
    $halffree = showSize($halffree);
    return ($tarsize, $dumpsize, $tmpfree, $halffree);
} ## end sub CalculateSizes

sub showSize {

    # convert size to Mb or Gb or Tb :) Remember, df reports in kb.
    my $size = shift;
    my $Mb   = 1024;
    my $Gb   = $Mb * $Mb;
    my $Tb   = $Mb * $Mb * $Mb;

    if ($size >= $Tb) {
        $size /= $Tb;
        $size = int($size) . "Tb";
    } elsif ($size >= $Gb) {
        $size /= $Gb;
        $size = int($size) . "Gb";
    } elsif ($size >= $Mb) {
        $size /= $Mb;
        $size = int($size) . "Mb";
    } else {
        $size .= "kb";
    }
    return $size;
} ## end sub showSize

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
