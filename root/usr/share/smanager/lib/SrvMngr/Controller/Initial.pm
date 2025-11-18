package SrvMngr::Controller::Initial;

#----------------------------------------------------------------------
# heading     : Support
# description : Home
# navigation  : 0000 000
# menu        : N
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
    my $title = $c->l('initial_FORM_TITLE');
    my $modul = $c->render_to_string(inline => $c->l('initial_FRAMES_BODY'));
    $c->stash(title => $title, modul => $modul);
    $c->render(template => 'initial');
} ## end sub main

sub get_locale {
  my $c = shift;
  $c->app->log->info($c->log_req);
  # Locale already saved in stash 'locale'
  $c->render(template => 'get-locale', format => 'js');
};

1;