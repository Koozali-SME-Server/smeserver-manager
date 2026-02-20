package SrvMngr::Controller::Legacypanel;

#----------------------------------------------------------------------
# heading     : Legacy
# description : Legacy panel
# navigation  : 99999 9999
#----------------------------------------------------------------------
#----------------------------------------------------------------------
# name   : legacypanel,    method : get,   url : /legacypanel,     ctlact : Legacypanel#main
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
    my $title         = $c->l('legacy panel');
    my $legacy_url    = $c->param('url');
    my $legacy_height = $c->param('height') || 600;
    $c->stash(title => $title, modul => $legacy_url, height => $legacy_height);
    $c->render(template => 'embedded');
} ## end sub main

sub getlegacyurl {
    my $c   = shift;
    my $url = shift;
    return "/smanager/legacypanel?url=$url";
} ## end sub getlegacyurl
1;
