package SrvMngr::Controller::Yum;

#----------------------------------------------------------------------
# heading     : System
# description : Software installer
# navigation  : 4000 300
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session ip_number_or_blank);

use esmith::ConfigDB;

use esmith::util;
use File::Basename;

our $cdb = esmith::ConfigDB->open || die "Couldn't open config db";

#use File::stat;

our %dbs;

for ( qw(available installed updates) )
{
    $dbs{$_} = esmith::ConfigDB->open_ro("yum_$_") or
	die "Couldn't open yum_$_ DB\n";
}

for ( qw(repositories) )
{
    $dbs{$_} = esmith::ConfigDB->open("yum_$_") or
	die "Couldn't open yum_$_ DB\n";
}


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %yum_datas = ();
    my $title = $c->l('yum_FORM_TITLE');
    my $dest = 'yum';
    my $notif = '';

    $yum_datas{'trt'} = 'STAT';

    if ( -e "/var/run/yum.pid" ) {
	$yum_datas{'trt'} = 'LOGF';
	$dest = 'yumlogfile';
    } elsif ($cdb->get_prop('yum', 'LogFile')) {
	$yum_datas{'trt'} = 'PSTU';
	$yum_datas{'reconf'} = $cdb->get_value('UnsavedChanges', 'yes');
	$dest = 'yumpostupg';
    } else {
	# normal other trt
    }

    $c->stash( title => $title, notif => $notif, yum_datas => \%yum_datas );
    return $c->render( template => $dest );

}


sub do_display {

    my $c = shift;

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'STAT');

    my %yum_datas = ();
    my $title = $c->l('yum_FORM_TITLE');
    my ($notif, $dest) = '';

    $yum_datas{'trt'} = $trt;

    # force $trt if current logfile
    if ( -e "/var/run/yum.pid" ) {
	$trt = 'LOGF';
    } elsif ($cdb->get_prop('yum', 'LogFile')) {
	$trt = 'PSTU';
    }

        if ( $trt eq 'UPDT' ) {
	    $dest = 'yumupdate';
        }

        if ( $trt eq 'INST' ) {
	    $dest = 'yuminstall';
        }

        if ( $trt eq 'REMO' ) {
	    $dest = 'yumremove';
	}

        if ( $trt eq 'CONF' ) {
	    $dest = 'yumconfig';
	}

        if ( $trt eq 'LOGF' ) {
	    if (-e "/var/run/yum.pid") {
	    $dest = 'yumlogfile';
	    }
	}
	
        if ( $trt eq 'PSTU') {
	    if ($cdb->get_prop('yum', 'LogFile')) {
		$dest = 'yumpostupg';
		$yum_datas{'reconf'} = $cdb->get_value('UnsavedChanges', 'yes');
	    }
	}
	
	if ( ! $dest ) { $dest = 'yum'; }

    $c->stash( title => $title, notif => $notif, yum_datas => \%yum_datas );
    return $c->render( template => $dest );

};


sub do_update {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = $c->param('trt');

    my %yum_datas = ();
    $yum_datas{trt} = $trt;

    my $title = $c->l('yum_FORM_TITLE');

    my ($dest, $res, $result) = '';

    if ( $trt eq 'UPDT' ) {

	$dest = 'yumupdate';

	if ( ! $result ) {
	    $res = $c->do_yum('update');
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$yum_datas{trt} = 'SUC';
		#$result = $c->l('yum_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'INST' ) {

	$dest = 'yuminstall';

	if ( ! $result ) {
	    $res = $c->do_yum('install');
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$yum_datas{trt} = 'SUC';
		#$result = $c->l('yum_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'REMO' ) {

	$dest = 'yumremove';

	if ( ! $result ) {
	    $res = $c->do_yum('remove');
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$yum_datas{trt} = 'SUC';
		#$result = $c->l('yum_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'CONF' ) {

	$dest = 'yumconfig';

	if ( ! $result ) {
	    $res = $c->change_settings();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$yum_datas{trt} = 'SUC';
		$result = $c->l('yum_SUCCESS');
	    }
	}
    }


    if ( $trt eq 'PSTU') {

	my $reconf = $c->param('reconf') || 'yes';
	$dest = 'yumpostupg';

    # 	effective reconfigure and reboot required
	if ( $reconf eq 'yes' ) {
	    $res = $c->post_upgrade_reboot();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$yum_datas{trt} = 'SUC';
		$result = $c->l('yum_SYSTEM_BEING_RECONFIGURED');
	    }
	} else {
	    $yum_datas{trt} = 'SUC';
	    $result = $c->l('yum_UPDATE_SUCCESS');
	}
    }


    if ( $trt eq 'LOGF' ) {

    	$dest = 'yumlogfile';
        if ( ! -e "/var/run/yum.pid") {
	    $yum_datas{trt} = 'SUC';
	    $result = $c->l('yum_SUCCESS');
        }
    }

    # do_yum ended (no message) --> forced to LOGFile
    if ( ! $result ) { 
	$dest = 'yumlogfile';
	$yum_datas{trt} = 'LOGF';
    }


    $c->stash( title => $title, notif => $result, yum_datas => \%yum_datas );
    if ($yum_datas{trt} ne 'SUC') {
	return $c->render(template => $dest);
    }

    my $message = "'Yum' $trt update DONE";
    $c->app->log->info($message);
    $c->flash(success => $result) if $result;

    $c->redirect_to("/yum");

};


sub is_empty {

    my ($c, $yumdb) = @_;

    my $groups = $dbs{$yumdb}->get_all_by_prop(type => 'group') || 'none';
    my $packages = $dbs{$yumdb}->get_all_by_prop(type => 'package') || 'none';

    #Show no updates if both = none
    return 1 if ($packages eq $groups);

    #else return here
    return;
}


sub non_empty {

    my ($c, $yumdb, $type) = @_;

    $type ||= 'both';

    return 0 unless (exists $dbs{$yumdb});

    my $groups   = scalar $dbs{$yumdb}->get_all_by_prop(type => 'group');
    return $groups if ($type eq 'group');

    my $packages = scalar $dbs{$yumdb}->get_all_by_prop(type => 'package');
    if ($type eq 'package')
    {
	return $c->package_functions_enabled ? $packages : 0;
    }

    return ($c->package_functions_enabled or $yumdb eq 'updates') ?
		($groups || $packages) : $groups;
}


sub package_functions_enabled {

    my ($c) = @_;

    return ($cdb->get_prop("yum", "PackageFunctions") eq "enabled");

}


sub get_status {

    my ($c, $prop, $localise) = @_;

    my $status = $cdb->get_prop("yum", $prop) || 'disabled';

    return $status unless $localise;

    return $c->l($status eq 'enabled' ? 'ENABLED' : 'DISABLED');
}


sub get_options {

    my ($c, $yumdb, $type) = @_;

    my %options;

    for ($dbs{$yumdb}->get_all_by_prop(type => $type))
    {
        $options{$_->key} = $_->key . " " . $_->prop("Version") . " - " .
            $_->prop("Repo");
    }

    return \%options;
}


sub get_options2 {

    my ($c, $yumdb, $type) = @_;

    my @options;

    for ($dbs{$yumdb}->get_all_by_prop(type => $type))
    {
        push @options, [ $_->key . " " . $_->prop("Version") . " - " .
            $_->prop("Repo") => $_->key ];
    }

    return \@options;
}


sub get_names {

    return [ keys %{get_options(@_)} ];
}


sub get_names2 {

    my ($c, $yumdb, $type) = @_;
    my @selected;

    for ($dbs{$yumdb}->get_all_by_prop(type => $type)) {
        push @selected, $_->key;
    }

    return \@selected;
#    return [ values @{get_options2(@_)} ];
}


sub get_repository_options2 {

    my $c = shift;

    my @options;

    foreach my $repos (
	$dbs{repositories}->get_all_by_prop(type => "repository") )
    {
	next unless ($repos->prop('Visible') eq 'yes'
		or $repos->prop('status') eq 'enabled');

        push @options, [ $repos->prop('Name') => $repos->key ];
    }

    my @opts = sort { $a->[0] cmp $b->[0] } @options;

    return \@opts;
}


sub get_repository_current_options
{
    my $c = shift;

    my @selected;

    foreach my $repos ( 
	$dbs{repositories}->get_all_by_prop( type => "repository" ) )
    {
	next unless ($repos->prop('Visible') eq 'yes'
		or $repos->prop('status') eq 'enabled');

        push @selected, $repos->key if ($repos->prop('status') eq 'enabled');
    }

    return \@selected;
}


sub get_avail2 {

    my ($c, $yumdb, $type) = @_;

    return $c->get_options2("available", "package");
}


sub get_check_freq_opt {

    my ($c) = @_;

    return [[ $c->l('DISABLED') => 'disabled'],
	    [  $c->l('yum_1DAILY') => 'daily'],
	    [  $c->l('yum_2WEEKLY') => 'weekly'],
	    [  $c->l('yum_3MONTHLY') => 'monthly']];
}


sub print_skip_header {

    my ($c) = shift;

    return "<INPUT TYPE=\"hidden\" NAME=\"skip_header\" VALUE=\"1\">\n";
}


sub change_settings {

    my ($c) = @_;

    for my $param ( qw(
			PackageFunctions
            	) )
    {
	$cdb->set_prop('yum', $param, $c->param("yum_$param"));
    }

    my $check4updates = $c->param("yum_check4updates");
    my $status = 'disabled';

    if ($check4updates ne 'disabled') { $status = 'enabled'; }

    $cdb->set_prop('yum', 'check4updates', $check4updates);

    my $deltarpm = $c->param("yum_DeltaRpmProcess");
    $cdb->set_prop('yum', 'DeltaRpmProcess', $deltarpm);

    my $downloadonly = $c->param("yum_DownloadOnly");
    if ($downloadonly ne 'disabled') { $status = 'enabled'; }

    $cdb->set_prop('yum', 'DownloadOnly', $downloadonly);

    my $AutoInstallUpdates = $c->param("yum_AutoInstallUpdates");
    if ($AutoInstallUpdates ne 'disabled') { $status = 'enabled'; }

    $cdb->set_prop('yum', 'AutoInstallUpdates', $AutoInstallUpdates);
    $cdb->set_prop('yum', 'status', $status);

    my %selected = map {$_ => 1} @{$c->every_param('SelectedRepositories')};

    foreach my $repos (
	$dbs{repositories}->get_all_by_prop(type => "repository") )
    {
	$repos->set_prop("status", 
		exists $selected{$repos->key} ? 'enabled' : 'disabled');

    }

    $dbs{repositories}->reload;

    unless ( system( "/sbin/e-smith/signal-event", "yum-modify" ) == 0 )
    {
	return $c->l('yum_ERROR_UPDATING_CONFIGURATION');
    }

    return 'OK';
}


sub do_yum {

    my ($c, $function) = @_;

    for ( qw(SelectedGroups SelectedPackages) )
    {
	$cdb->set_prop("yum", $_, join(',', (@{$c->every_param($_)} )));
    }

    esmith::util::backgroundCommand(0,
        "/sbin/e-smith/signal-event", "yum-$function");

    for ( qw(available installed updates) ) {
	$dbs{$_}->reload;
    }

    return 'OK';
}


sub get_yum_status_page {

    my ($c) = @_;
    my $yum_status;

    open(YUM_STATUS, "</var/run/yum.status");
    $yum_status = <YUM_STATUS>;
    close(YUM_STATUS);

    return $yum_status;
}


sub format_yum_log {

    my $c = shift;

    $cdb->reload;

    my $filepage = $cdb->get_prop('yum', 'LogFile');
    return '' unless $filepage and ( -e "$filepage" );

    my $out = sprintf "<PRE>";
    open (FILE, "$filepage");
    while (<FILE>) {
	$out .= sprintf("%s", $_);
    }
    close FILE;
    $out .= sprintf "</PRE>";

    undef $filepage;
    return $out;
}


sub post_upgrade_reboot {

    my $c = shift;

    $cdb->get_prop_and_delete('yum', 'LogFile');
    $cdb->reload;

    if (fork == 0) {
        exec "/sbin/e-smith/signal-event post-upgrade; /sbin/e-smith/signal-event reboot";
        die "Exec failed";
    }

    return 'OK'
}


sub show_yum_log {
    my $c = shift;
    my $out = $c->format_yum_log();
    my $yum_log = $cdb->get_prop_and_delete('yum', 'LogFile');
    return $out;
}


1;
