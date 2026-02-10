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
use Apache::AuthTkt;
# Loading AuthTkt config
my $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");

sub logout {
    my $c = shift;
    $c->app->log->info($c->log_req);
    $c->session(expires => 1);
    $c->flash(success => 'Goodbye');
    my $server_name = $c->req->headers->header('X-Forwarded-Host');
    $server_name ||= $ENV{SERVER_NAME} if $ENV{SERVER_NAME};
    my $AUTH_DOMAIN = $server_name;
    my @auth_domain = $AUTH_DOMAIN && $AUTH_DOMAIN =~ /\./ ? ( domain => $AUTH_DOMAIN ) : ();
    $c->cookie(auth_tkt => '', {
            name => $at->cookie_name,
            path   => '/',
            secure => $at->require_ssl,
            expires => '1',
            @auth_domain,
     });
    $c->log->debug($c->req->headers->to_string);
    $c->redirect_to($c->home_page);
} ## end sub logout
1;
