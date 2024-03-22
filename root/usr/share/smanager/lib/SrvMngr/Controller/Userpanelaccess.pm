package SrvMngr::Controller::Userpanelaccess;

#----------------------------------------------------------------------
# heading     : User management
# description : User Panel Access
# navigation  : 2000 150
# menu        : 
#----------------------------------------------------------------------
# name   : userpanelaccess,    method : get,   url : /userpanelaccess,     ctlact : Userpanelaccess#main
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

    my $title = $c->l('User panel access');
    $c->stash( title => $title, modul => 'https://mailserver.bjsystems.co.uk/server-manager/cgi-bin/userpanelaccess', height => 600 );
    $c->render(template => 'embedded');

}


1;
