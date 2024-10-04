package SrvMngr::Controller::Roundcubepanel;

#----------------------------------------------------------------------
# heading     : System
# description : Roundcube webmail
# navigation  : 99999 9999
#----------------------------------------------------------------------
#----------------------------------------------------------------------
# name   : roundcubepanel,    method : get,   url : /roundcubepanel,     ctlact : Roundcubepanel#main
#
# routes : end
#----------------------------------------------------------------------

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

#use SrvMngr::Model::Main;


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('Roundcube Webmail');
    my $roundcube_url = $c->param('url');
    my $roundcube_height = $c->param('height') | 600;
    $c->stash( title => $title, modul => $roundcube_url, height => $roundcube_height );
    $c->render(template => 'roundcube');

}

sub getroundcubeurl {
	my $c = shift;
	my $url = shift;
	return "/smanager/roundcube?url=$url";
}


1;
