package SrvMngr::Controller::Roundcubepanel;

#----------------------------------------------------------------------
# heading     : System
# description : Webmail
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
    my $title            = $c->l('Webmail');
    my $roundcube_url    = $c->param('url');
    $c->stash(title => $title, modul => $roundcube_url);
    $c->render(template => 'roundcube');
} ## end sub main

sub getroundcubeurl {
    my $c   = shift;
    my $url = shift;
    return "/smanager/roundcube?url=$url";
} ## end sub getroundcubeurl
1;
