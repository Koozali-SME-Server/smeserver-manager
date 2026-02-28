package SrvMngr::Controller::Yum;

#----------------------------------------------------------------------
# heading     : System
# description : Software installer
# navigation  : 4000 500
#$if_admin->get('/yum')->to('yum#main')->name('yum');
#$if_admin->post('/yum')->to('yum#do_display')->name('yumd1');
#$if_admin->get('/yumd')->to('yum#do_display')->name('yumd');
#$if_admin->post('/yumd')->to('yum#do_update')->name('yumu');
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session ip_number_or_blank);

# dnf_* should remain ASCII; yum_repositories do not need to be UTF-8
use esmith::ConfigDB::UTF8;
use esmith::util;
use File::Basename;
our $cdb;
my $dnf_status_file = '/var/cache/dnf/dnf.status';
our %dbs;
my $dnf_update_db = '/home/e-smith/db/dnf_updates';
use Linux::Inotify2;
use POSIX qw(strftime);
my $inotify;
my $watch = undef;
my $file_to_watch;

sub setup_notify {
    my $c = shift;
    $file_to_watch = shift;
    $inotify       = Linux::Inotify2->new or die "Unable to create inotify object: $!";
    $watch         = $inotify->watch($file_to_watch, IN_MODIFY | IN_MOVE | IN_CLOSE_WRITE)
        or die "Unable to watch $file_to_watch: $!";
    #$c->app->log->info("Setup notify for $file_to_watch ");
    $c->app->log->info("Event details: " . join(', ', 
    "name=" . $watch->name,
    "fullname=" . $file_to_watch, 
    "mask=0x" . sprintf('%x', $watch->mask)
));

    return;
} ## end sub setup_notify

sub cancel_notify {
    my $c = shift;
    $watch->cancel if $watch;
    $watch = undef;
    return;
}

sub calculate_dnf_timeout {
    my $c = shift;
    my $dnf_update_db = shift;
    return 300 unless -r $dnf_update_db;
    my $pkg_count = 0;
    open my $count_fh, '<', $dnf_update_db or return 300;
    $pkg_count++ while <$count_fh>;    # Count lines
    close $count_fh;
    my $base_timeout = 120;
    my $per_pkg      = 75;
    my $timeout      = $base_timeout + ($pkg_count * $per_pkg);
    $timeout = 3600 if $timeout > 3600;
    return $timeout;
} ## end sub calculate_dnf_timeout

sub wait_for_event_with_timeout {
    my $c     = shift;
    my %check = (
        ACCESS        => 'IN_ACCESS',
        MODIFY        => 'IN_MODIFY',
        ATTRIB        => 'IN_ATTRIB',
        CLOSE_WRITE   => 'IN_CLOSE_WRITE',
        CLOSE_NOWRITE => 'IN_CLOSE_NOWRITE',
        OPEN          => 'IN_OPEN',
        MOVED_FROM    => 'IN_MOVED_FROM',
        MOVED_TO      => 'IN_MOVED_TO',
        CREATE        => 'IN_CREATE',
        DELETE        => 'IN_DELETE',
        DELETE_SELF   => 'IN_DELETE_SELF',
        MOVE_SELF     => 'IN_MOVE_SELF',
        IGNORED       => 'IN_IGNORED'
    );
    my $timeout = $c->calculate_dnf_timeout($dnf_update_db);

    #$c->app->log->info("dnf timeout: ${timeout}s for $dnf_update_db");
    my $start = time;
    my $res   = 'Timeout';
    if (!defined $watch) { return "undef"; }
    $c->app->log->info("Waiting for: $file_to_watch with timeout: $timeout");

    while (time - $start < $timeout) {
        my @events = $inotify->read;
        if (@events) {
            for my $event (@events) {
                # Read contents first, then log
                my $fullname = $event->fullname;
                my $contents_preview = '';
                if (open my $fh, '<', $fullname) {
                    local $/;
                    my $contents = <$fh>;
                    close $fh;
                    
                    # Preview first 100 chars or first line
                    $contents_preview = substr($contents, 0, 100);
                    $contents_preview =~ s/\n/\\n/g;  # Escape newlines for log
                    $contents_preview .= '...' if length $contents > 100;
                    
                    if ($contents =~ /sack/) {
                        $c->app->log->info("SUCCESS: sack found in $fullname");
                        $res = "Change with sack";
                        $c->cancel_notify();
                        return $res;
                    }
                } else {
                    $c->app->log->warn("Failed to read $fullname: $!");
                }
                 # Now log with contents
                my @types = grep { $event->${ \$check{$_} } } keys %check;  # Fixed double \\
                my $type_str = @types ? join(',', @types) : sprintf '0x%x', $event->mask;
                $c->app->log->info("Found change: $file_to_watch file=$fullname types=$type_str contents=[$contents_preview]");
              } ## end for my $event (@events)
        } ## end if (@events)
        sleep 1;
    } ## end while (time - $start < $timeout)
    $c->cancel_notify();
    return $res;
} ## end sub wait_for_event_with_timeout

sub refresh_dbs {
    for (qw(available installed updates)) {
        $dbs{$_} = esmith::ConfigDB::UTF8->open_ro("dnf_$_")
            or die "Couldn't open dnf_$_ DB\n";
    }

    for (qw(repositories)) {
        $dbs{$_} = esmith::ConfigDB::UTF8->open("yum_$_")
            or die "Couldn't open yum_$_ DB\n";
    }
}

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    $cdb = esmith::ConfigDB::UTF8->open || die "Couldn't open config db";

    $c->refresh_dbs();
    
    my %yum_datas = ();
    my $title     = $c->l('yum_FORM_TITLE');
    my $dest      = 'yum';
    my $notif     = '';
    $yum_datas{'trt'} = 'STAT';
    $cdb->reload;

    if ($c->is_dnf_running()) {
        $yum_datas{'trt'} = 'LOGF';
        $dest = 'yumlogfile';
    } elsif ($cdb->get_prop('dnf', 'LogFile')) {
        $yum_datas{'trt'} = 'PSTU';
        my $res = $c->wait_for_event_with_timeout();
        $c->app->log->info("Back from wait (1) event $res");
        $yum_datas{'reconf'} = $cdb->get_value('UnsavedChanges', 'yes');
        $dest = 'yumpostupg';
    } else {

        # normal other trt
    }
    $c->stash(title => $title, notif => $notif, yum_datas => \%yum_datas);
    return $c->render(template => $dest);
} ## end sub main

sub do_display {
    my $c   = shift;
    my $rt  = $c->current_route;
    my $trt = ($c->param('trt') || 'STAT');
    $cdb = esmith::ConfigDB::UTF8->open || die "Couldn't open config db";

    $c->refresh_dbs();

    my %yum_datas = ();
    my $title     = $c->l('yum_FORM_TITLE');
    my ($notif, $dest) = '';
    $yum_datas{'trt'} = $trt;
    $cdb->reload;

    # force $trt if current logfile
    if ($c->is_dnf_running()) {
        $trt = 'LOGF';
    } elsif ($cdb->get_prop('dnf', 'LogFile')) {
        $trt = 'PSTU';
    }

    if ($trt eq 'UPDT') {
        $dest = 'yumupdate';
    }

    if ($trt eq 'INST') {
        $dest = 'yuminstall';
    }

    if ($trt eq 'REMO') {
        $dest = 'yumremove';
    }

    if ($trt eq 'CONF') {
        $dest = 'yumconfig';
    }

    if ($trt eq 'LOGF') {
        if ($c->is_dnf_running()) {
            $dest = 'yumlogfile';
        }
    }

    if ($trt eq 'PSTU') {
        $cdb->reload();

        if ($cdb->get_prop('dnf', 'LogFile')) {
            my $res = $c->wait_for_event_with_timeout();
            $c->app->log->info("Back from wait (2) event $res");
            $dest = 'yumpostupg';
            $yum_datas{'reconf'} = $cdb->get_value('UnsavedChanges', 'yes');
        } ## end if ($cdb->get_prop('dnf'...))
    } ## end if ($trt eq 'PSTU')
    if (!$dest) { $dest = 'yum'; }
    $c->stash(title => $title, notif => $notif, yum_datas => \%yum_datas);
    return $c->render(template => $dest);
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt  = $c->current_route;
    my $trt = $c->param('trt');
    $cdb = esmith::ConfigDB::UTF8->open || die "Couldn't open config db";

    $c->refresh_dbs();

    my %yum_datas = ();
    $yum_datas{trt} = $trt;
    my $title = $c->l('yum_FORM_TITLE');
    my ($dest, $res, $result) = '';

    if ($trt eq 'UPDT') {
        $dest = 'yumupdate';

        if (!$result) {
            $res = $c->do_yum('update');
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $yum_datas{trt} = 'SUC';

                #$result = $c->l('yum_SUCCESS');
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'UPDT')

    if ($trt eq 'INST') {
        $dest = 'yuminstall';

        if (!$result) {
            $res = $c->do_yum('install');
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $yum_datas{trt} = 'SUC';

                #$result = $c->l('yum_SUCCESS');
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'INST')

    if ($trt eq 'REMO') {
        $dest = 'yumremove';

        if (!$result) {
            $res = $c->do_yum('remove');
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $yum_datas{trt} = 'SUC';

                #$result = $c->l('yum_SUCCESS');
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'REMO')

    if ($trt eq 'CONF') {
        $dest = 'yumconfig';

        if (!$result) {
            $res = $c->change_settings();
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $yum_datas{trt} = 'SUC';
                $result = $c->l('yum_SUCCESS');
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'CONF')

    if ($trt eq 'PSTU') {
        my $res = $c->wait_for_event_with_timeout();
        $c->app->log->info("Back from wait (3) event $res");
        my $reconf = $c->param('reconf') || 'yes';
        $dest = 'yumpostupg';

        # 	effective reconfigure and reboot required
        if ($reconf eq 'yes') {
            $res = $c->post_upgrade_reboot();
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $yum_datas{trt} = 'SUC';
                $result = $c->l('yum_SYSTEM_BEING_RECONFIGURED');
            }
        } else {
            $yum_datas{trt} = 'SUC';
            $result = $c->l('yum_UPDATE_SUCCESS');
        }
    } ## end if ($trt eq 'PSTU')

    if ($trt eq 'LOGF') {
        $dest = 'yumlogfile';

        if (!$c->is_dnf_running()) {
            $yum_datas{trt} = 'SUC';
            $result = $c->l('yum_SUCCESS');
        }
    } ## end if ($trt eq 'LOGF')

    # do_yum ended (no message) --> forced to LOGFile
    if (!$result) {
        $dest = 'yumlogfile';
        $yum_datas{trt} = 'LOGF';
    }
    $c->stash(title => $title, notif => $result, yum_datas => \%yum_datas);

    if ($yum_datas{trt} ne 'SUC') {
        return $c->render(template => $dest);
    }
    my $message = "'Yum' $trt update DONE";
    $c->app->log->info($message);
    $c->flash(success => $result) if $result;
    $c->redirect_to("/yum");
} ## end sub do_update

sub get_dnf_status {

    #interrogate status file created and maintained by smeserver.py plugin for dnf.
    my ($c)       = @_;
    my $file_name = $dnf_status_file;
    my $content   = "resolved";

    if (-e "$file_name") {
        open my $fh, '<', $file_name or die "Can't open file: $!";
        $content = <$fh>;
        close $fh;
    }
    return $content;
} ## end sub get_dnf_status

sub is_dnf_running {
    my ($c) = @_;
    my $dnf_status = $c->get_dnf_status();
    return $dnf_status ne "resolved" && $dnf_status ne "config" && $dnf_status ne "sack";
}

sub is_empty {
    my ($c, $yumdb) = @_;
    $c->refresh_dbs();
    my $groups   = $dbs{$yumdb}->get_all_by_prop(type => 'group')   || 'none';
    my $packages = $dbs{$yumdb}->get_all_by_prop(type => 'package') || 'none';

    #Show no updates if both = none
    return 1 if ($packages eq $groups);

    #else return here
    return;
} ## end sub is_empty

sub non_empty {

    # Called from template
    my ($c, $yumdb, $type) = @_;
    $c->refresh_dbs();
    $type ||= 'both';
    return 0 unless (exists $dbs{$yumdb});
    my $groups = scalar $dbs{$yumdb}->get_all_by_prop(type => 'group');
    return $groups if ($type eq 'group');
    my $packages = scalar $dbs{$yumdb}->get_all_by_prop(type => 'package');

    if ($type eq 'package') {
        return $c->package_functions_enabled ? $packages : 0;
    }
    return ($c->package_functions_enabled or $yumdb eq 'updates') ? ($groups || $packages) : $groups;
} ## end sub non_empty

sub package_functions_enabled {
    my ($c) = @_;
    return ($cdb->get_prop("dnf", "PackageFunctions") eq "enabled");
}

sub get_status {

    # called from template
    my ($c, $prop, $localise) = @_;
    $c->refresh_dbs();
    my $status = $cdb->get_prop("dnf", $prop) || 'disabled';
    return $status unless $localise;
    return $c->l($status eq 'enabled' ? 'ENABLED' : 'DISABLED');
} ## end sub get_status

sub get_options {

    # called from template
    my ($c, $yumdb, $type) = @_;
    $c->refresh_dbs();
    my %options;

    for ($dbs{$yumdb}->get_all_by_prop(type => $type)) {
        $options{ $_->key } = $_->key . " " . $_->prop("Version") . " - " . $_->prop("Repo");
    }
    return \%options;
} ## end sub get_options

sub get_options2 {
    my ($c, $yumdb, $type) = @_;
    $c->refresh_dbs();
    my @options;

    for ($dbs{$yumdb}->get_all_by_prop(type => $type)) {
        my $key     = $_->key             // '';
        my $version = $_->prop("Version") // '';
        my $repo    = $_->prop("Repo")    // '';
        push @options, [ "$key $version - $repo" => $key ];
    } ## end for ($dbs{$yumdb}->get_all_by_prop...)
    return \@options;
} ## end sub get_options2

sub get_names {
    return [ keys %{ get_options(@_) } ];
}

sub get_names2 {
    my ($c, $yumdb, $type) = @_;
    my @selected;
    $c->refresh_dbs();

    for ($dbs{$yumdb}->get_all_by_prop(type => $type)) {
        push @selected, $_->key;
    }
    return \@selected;

    #    return [ values @{get_options2(@_)} ];
} ## end sub get_names2

sub get_repository_options2 {
    my $c = shift;
    $c->refresh_dbs();

    my @options;

    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        next unless ($repos->prop('Visible') eq 'yes'
            or $repos->prop('status') eq 'enabled');
        push @options, [ $repos->prop('Name') => $repos->key ];
    }
    my @opts = sort { $a->[0] cmp $b->[0] } @options;
    return \@opts;
} ## end sub get_repository_options2

sub get_repository_current_options {

    # called from template
    my $c = shift;
    $c->refresh_dbs();
    my @selected;

    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        next unless ($repos->prop('Visible') eq 'yes'
            or $repos->prop('status') eq 'enabled');
        push @selected, $repos->key if ($repos->prop('status') eq 'enabled');
    }
    return \@selected;
} ## end sub get_repository_current_options

sub get_avail2 {
    my ($c, $yumdb, $type) = @_;
    return $c->get_options2("available", "package");
}

sub get_check_freq_opt {
    my ($c) = @_;
    return [
        [ $c->l('DISABLED')     => 'disabled' ],
        [ $c->l('yum_1DAILY')   => 'daily' ],
        [ $c->l('yum_2WEEKLY')  => 'weekly' ],
        [ $c->l('yum_3MONTHLY') => 'monthly' ]
    ];
} ## end sub get_check_freq_opt

sub print_skip_header {
    my ($c) = shift;
    return "<INPUT TYPE=\"hidden\" NAME=\"skip_header\" VALUE=\"1\">\n";
}

sub change_settings {
    my ($c) = @_;

    for my $param (
        qw(
        PackageFunctions
        )
        )
    {
        $cdb->set_prop("dnf", $param, $c->param("yum_$param"));
    } ## end for my $param (qw( PackageFunctions...))
    my $check4updates = $c->param("yum_check4updates");
    my $status        = 'disabled';
    if ($check4updates ne 'disabled') { $status = 'enabled'; }
    $cdb->set_prop("dnf", 'check4updates', $check4updates);
    my $deltarpm = $c->param("yum_DeltaRpmProcess");
    $cdb->set_prop("dnf", 'DeltaRpmProcess', $deltarpm);
    my $downloadonly = $c->param("yum_DownloadOnly");
    if ($downloadonly ne 'disabled') { $status = 'enabled'; }
    $cdb->set_prop("dnf", 'DownloadOnly', $downloadonly);
    my $AutoInstallUpdates = $c->param("yum_AutoInstallUpdates");
    if ($AutoInstallUpdates ne 'disabled') { $status = 'enabled'; }
    $cdb->set_prop("dnf", 'AutoInstallUpdates', $AutoInstallUpdates);
    $cdb->set_prop("dnf", 'status',             $status);
    $cdb->reload();
    my %selected = map { $_ => 1 } @{ $c->every_param('SelectedRepositories') };

    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        $repos->set_prop("status", exists $selected{ $repos->key } ? 'enabled' : 'disabled');
    }
    $dbs{repositories}->reload;

    unless (system("/sbin/e-smith/signal-event", "dnf-modify") == 0) {
        return $c->l('yum_ERROR_UPDATING_CONFIGURATION');
    }
    return 'OK';
} ## end sub change_settings

sub do_yum {
    my ($c, $function) = @_;

    # Copy selected items into dnf entry in config db for dnf action to pull out.
    for my $param (qw(SelectedGroups SelectedPackages)) {
        my $values = $c->every_param($param) || [];       
        if (@$values) {
            # Something selected - save comma-separated
            $cdb->set_prop("dnf", $param, join(',', @$values));
            $c->app->log->info("Saved $param: " . join(',', @$values));
        } else {
            # Nothing selected - clear property
            $cdb->set_prop("dnf", $param, '');
            $c->app->log->info("Cleared $param (none selected)");
        }
    }
    $cdb->reload();

    if ($function eq 'update') {

        #setup notify so that we know when update db has been updated
        $c->setup_notify($dnf_status_file);    #Set to sack when dnf done.
    }
    esmith::util::backgroundCommand(0, "/sbin/e-smith/signal-event", "dnf-$function");

    for (qw(available installed updates)) {
        $dbs{$_}->reload;
    }
    return 'OK';
} ## end sub do_yum

sub get_yum_status_page {
    my ($c) = @_;
    my $yum_status;
    open(YUM_STATUS, "</var/run/yum.status");
    $yum_status = <YUM_STATUS>;
    close(YUM_STATUS);
    return $yum_status;
} ## end sub get_yum_status_page

sub format_yum_log {
    my $c = shift;
    $cdb->reload;
    my $filepage = $cdb->get_prop('dnf', 'LogFile');
    return '' unless $filepage and (-e "$filepage");
    my $out = sprintf "<PRE>";
    open(FILE, "$filepage");

    while (<FILE>) {
        $out .= sprintf("%s", $_);
    }
    close FILE;
    $out .= sprintf "</PRE>";
    undef $filepage;
    return $out;
} ## end sub format_yum_log

sub post_upgrade_reboot {
    my $c = shift;
    $cdb->reload;
    $cdb->get_prop_and_delete('dnf', 'LogFile');
    $cdb->reload;

    if (fork == 0) {
        exec "/sbin/e-smith/signal-event post-upgrade; /sbin/e-smith/signal-event reboot";
        die "Exec failed";
    }
    return 'OK';
} ## end sub post_upgrade_reboot

sub show_yum_log {
    my $c   = shift;
    my $out = $c->format_yum_log();
    $cdb->reload;
    my $yum_log = $cdb->get_prop_and_delete('dnf', 'LogFile');
    return $out;
} ## end sub show_yum_log
1;
