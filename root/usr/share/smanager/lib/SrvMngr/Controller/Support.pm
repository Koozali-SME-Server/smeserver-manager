package  SrvMngr::Controller::Support;

#----------------------------------------------------------------------
# heading     : Support
# description : Support and licensing
# navigation  : 0000 200
# menu        : N
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use SrvMngr qw(theme_list init_session);
use esmith::util;

sub display_licenses {
    my $lang = shift;
    my $lic  = '';

    foreach my $license (esmith::util::getLicenses($lang)) {
        $lic .= $license . '<br>';
    }
    return $lic;
} ## end sub display_licenses

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $title = $c->l('support_FORM_TITLE');
    my $modul = $c->render_to_string(inline => display_licenses($c->session->{lang}));
    $c->stash(title => $title, modul => $modul);
    $c->render(template => 'module');
} ## end sub main
1;
