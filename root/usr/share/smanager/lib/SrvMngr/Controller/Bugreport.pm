package SrvMngr::Controller::Bugreport;

#----------------------------------------------------------------------
# heading     : Investigation
# description : Report a bug
# navigation  : 7000 500

# routes : end
#------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

use Text::Template;
use File::Basename;
use esmith::FormMagick qw( gen_locale_date_string );

our $cdb = esmith::ConfigDB->open or die "Couldn't open ConfigDB\n";

# Get some basic info on the current SME install
our $sysconfig = $cdb->get('sysconfig');
our $systemmode = $cdb->get('SystemMode')->value;
our $previoussystemmode = $sysconfig->prop('PreviousSystemMode');
our $releaseversion = $sysconfig->prop('ReleaseVersion');

# Prepare some filehandles for templates and reports
our $templatefile = '/tmp/bugreport_template.txt';
our $configreportfile = '/tmp/configreport.txt';


sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my %bugr_datas = ();

    my $title = $c->l('bugr_FORM_TITLE');
    my $modul = $c->render_to_string( inline => $c->l('bugr_DESCRIPTION'));

    $bugr_datas{'trt'} = 'SHOW';

    $c->stash(title => $title, modul => $modul, bugr_datas => \%bugr_datas);
    $c->render(template => 'bugreport');
};


sub do_report {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('bugr_FORM_TITLE');

    my $trt = $c->param('trt') || 'SHOW';

    my %bugr_datas = ();
    $bugr_datas{'trt'} = $trt;

    if ( $trt eq 'SHOW' ) {
	create_configuration_report();

        my $out = $c->render_to_string(inline => show_config_report());

	$bugr_datas{'trt'} = 'DOWN';

	$c->stash(title => $title, modul => $out, bugr_datas => \%bugr_datas);
	$c->render(template => 'bugreport2');
    }

    if ( $trt eq 'DOWN' ) {

	my $modul = 'Bug report download';
	
#	$c->render_file(
#	    'filepath' => "$configreportfile",
#	    'format' => 'x-download',
#	    'content_disposition' => 'attachment',
#	    'cleanup' => 1,
#	);

    # the following in this sub will not be used !!!
#	$bugr_datas{'trt'} = 'DOWN';

#	$c->stash(title => $title, modul => $modul, bugr_datas => \%bugr_datas);
#	$c->render(template => 'bugreport');
    }
};


sub create_configuration_report {

    my $c = shift;

    # TBD: possibly check $q for a boolean value eg. from a checkbox
    # indicating the user has read privacy warning etc.

    # create the reporting template
    my $configreport_template = Text::Template->new(TYPE => 'FILE', SOURCE => '/etc/e-smith/web/common/configuration_report.tmpl', UNTAINT => 1);
    my $report_creation_time = gen_locale_date_string;

    # curent kernel
    my $curkernel = `uname -r`;
    
    # get additional RPMs
    my @newrpms = `/sbin/e-smith/audittools/newrpms`;
    
    # get additional Repositories
    my @repositories = `/sbin/e-smith/audittools/repositories`;
    #print @repositories; 

    # get templates
    my @templates = `/sbin/e-smith/audittools/templates`;

    # get events
    my @events = `/sbin/e-smith/audittools/events`;
    
    
    # set template variables
    my %vars = (report_creation_time => \$report_creation_time,
               releaseversion => \$releaseversion,
               curkernel => \$curkernel,
               systemmode => \$systemmode,
               previoussystemmode => \$previoussystemmode,
               newrpms => \@newrpms,
	       templates => \@templates,
	       events => \@events,
               repositories => \@repositories,
               ); 

    # prcess template
    my $result = $configreport_template->fill_in(HASH => \%vars);

    # write processed template to file
    open (my $cfgrep, '>', $configreportfile) or die "Could not create temporary file for config report!"; 
    print $cfgrep $result;
    close $cfgrep;
}


sub show_config_report {
    my $c = shift;

    my $out = '';
    $out .= sprintf "<PRE>";

    open (my $cfgrep, '<', $configreportfile) or die "Could not find temporary config report file!";

    while (<$cfgrep>) {
	$out .= sprintf("%s", $_);
    }

    $out .= sprintf "</PRE>";

    return $out;

}


sub download_config_report {
    my $c = shift;

    $c->render_file(
	    'filepath' => "$configreportfile",
	    'format' => 'x-download',
	    'content_disposition' => 'attachment',
	    'cleanup' => 1,
    );
}


1;

