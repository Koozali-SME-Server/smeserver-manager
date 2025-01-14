package SrvMngr::Controller::Proxy;

#----------------------------------------------------------------------
# heading     : System
# description : Proxy settings
# navigation  : 4000 710
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
our $db = esmith::ConfigDB->open || die "Couldn't open config db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %prx_datas = ();
    my $title     = $c->l('prx_TITLE');
    my $modul     = $c->render_to_string(inline => $c->l('prx_FIRST_PAGE_DESCRIPTION'));
    $prx_datas{'http_proxy_status'} = ($db->get_prop('squid', 'status')) || 'disabled';

    #if (system('/bin/rpm -q e-smith-email > /dev/null') == 0)
    #{
    $prx_datas{'smtp_proxy_status'} = $db->get_prop('qpsmtpd', 'Proxy') || undef;

    #}
    #(system('/bin/rpm -q e-smith-email > /dev/null') == 0) ?
    $c->stash(title => $title, modul => $modul, prx_datas => \%prx_datas);
    $c->render(template => 'proxy');
} ## end sub main

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $http_proxy_status = $c->param('http_proxy_status') || 'disabled';
    my $smtp_proxy_status = $c->param('smtp_proxy_status') || '';
    my $result            = "";
    my $squid = $db->get('squid') or $result = $c->l('prx_ERR_NO_SQUID_REC');

    # smtpd is allowed to not exist, as the relevant packages may not be
    # installed.
    my $smtpd = $db->get('qpsmtpd') || undef;
    $squid->set_prop('status', $http_proxy_status);
    $smtpd->set_prop('Proxy', $smtp_proxy_status) if $smtpd;
    #
    # Update the system
    #
    system("/sbin/e-smith/signal-event proxy-update") == 0
        or $result = $c->l('prx_ERR_PROXY_UPDATE_FAILED');
    my $title = $c->l('prx_TITLE');
    if ($result eq '') { $result = $c->l('prx_SUCCESS'); }
    $c->stash(title => $title, modul => $result);
    $c->render(template => 'module');
} ## end sub do_update
1;
