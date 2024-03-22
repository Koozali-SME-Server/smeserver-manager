package SrvMngr::Controller::Reboot;

#----------------------------------------------------------------------
# heading     : System 
# description : Reboot or shutdown
# navigation  : 4000 700 
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('rbo_FORM_TITLE');
    my $modul = '';

    $c->stash( title => $title, modul => $modul );
    $c->render(template => 'reboot');

};


sub do_action {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('rbo_FORM_TITLE');
    my $result = "";

    my $function = $c->param ('function');

    my $debug = $c->param('debug');

    if ($function eq "reboot") {
	$result = $c->l('rbo_REBOOT_SUCCEEDED') . '<br>' . $c->l('rbo_DESC_REBOOT');
        unless ($debug) {
	    esmith::util::backgroundCommand( 1, "/sbin/e-smith/signal-event", "reboot" );
    #       system( "/sbin/e-smith/signal-event", "reboot" ) == 0
    #             or die ("Error occurred while rebooting.\n");
                 }
    } elsif ($function eq 'shutdown') {
	$result = $c->l('rbo_SHUTDOWN_SUCCEEDED') . '<br>' . $c->l('rbo_DESC_SHUTDOWN');
        unless ($debug) {
	    esmith::util::backgroundCommand( 1, "/sbin/e-smith/signal-event", "halt" );
    #       system( "/sbin/e-smith/signal-event", "halt" ) == 0
    #             or die ("Error occurred while halting.\n");
           }
    } elsif ($function eq 'reconfigure') {
	$result = $c->l('rbo_RECONFIGURE_SUCCEEDED') . '<br>' . $c->l('rbo_DESC_RECONFIGURE');
        unless ($debug) {
	#    esmith::util::backgroundCommand( 1, "/sbin/e-smith/signal-event", "post-upgrade",
	#	    "; ", "/sbin/e-smith/signal-event", "reboot" );
           system( "/sbin/e-smith/signal-event", "post-upgrade" ) == 0
                 or die ("Error occurred while running post-upgrade.\n");
           system( "/sbin/e-smith/signal-event", "reboot" ) == 0
                 or die ("Error occurred while rebooting.\n");
           }
    }

    $c->stash( title => $title, modul => $result );
    $c->render(template => 'module');

};


sub rebootFunction_list {

    my $c = shift;
    return [[ $c->l('rbo_REBOOT') => 'reboot' ],
	    [ $c->l('RECONFIGURE') => 'reconfigure' ],
	    [ $c->l('SHUTDOWN') => 'shutdown' ]];
}


1;
