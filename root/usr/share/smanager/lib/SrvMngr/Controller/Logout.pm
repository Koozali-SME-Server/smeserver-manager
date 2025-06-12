package SrvMngr::Controller::Logout;

#----------------------------------------------------------------------
# heading     : Current User
# description : Logout
# navigation  : 1000 1000
# menu        : U
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw( theme_list init_session );

sub logout {
    my $c = shift;
    $c->app->log->info($c->log_req);
    $c->session(expires => 1);
    $c->flash(success => 'Goodbye');
    $c->redirect_to($c->home_page);
} ## end sub logout
1;
