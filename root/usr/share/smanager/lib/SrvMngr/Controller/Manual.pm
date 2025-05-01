package SrvMngr::Controller::Manual;

#----------------------------------------------------------------------
# heading     : Support
# description : Online manual
# navigation  : 0 300
# menu        : N
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
    my $title = $c->l('manual_FORM_TITLE');
    my $modul = $c->render_to_string(inline => $c->l('manual_DESCRIPTION'));
    $c->stash(title => $title, modul => $modul);
    $c->render(template => 'manual');
} ## end sub main
1;
