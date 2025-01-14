package SrvMngr::Controller::Swttheme;
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

#use SrvMngr qw(theme_list init_session);
our $db = esmith::ConfigDB->open() || die "Couldn't open config db";

sub main {
    my $c     = shift;
    my $from  = $c->param('From') || '/';
    my $theme = $c->param('Theme');
    $c->app->log->info(" swt theme '$from'  '$theme' ");
    my $oldTheme = $c->session->{CurrentTheme};

    if ($theme ne $oldTheme) {

        #	$c->app->renderer->paths([$c->app->home->rel_file('themes/default/templates')]);
        #	$c->app->static->paths([$c->app->home->rel_file('themes/default/public')]);
        #	if ( $theme ne 'default' ) {
        #        # Put the new theme first
        #	    my $t_path = $c->app->home->rel_file('themes/'.$theme);
        #	    unshift @{$c->app->renderer->paths}, $t_path.'/templates' if -d $t_path.'/templates';
        #	    unshift @{$c->app->static->paths},   $t_path.'/public' if -d $t_path.'/public';
        #	}
        $c->session->{CurrentTheme} = $theme;
        $db->get('smanager')->set_prop('Theme', $theme);
        system("/sbin/e-smith/signal-event smanager-theme-change") == 0
            or warn "$c->l('ERROR_UPDATING')";
    } ## end if ($theme ne $oldTheme)
## (not sure)     $c->flash( warning => $c->l('swt_LOGIN_AGAIN') );
    $from = '/initial'  if $from eq '/';
    $from = '/' . $from if ($from !~ m|^\/|);
    $c->redirect_to($from);
} ## end sub main
1;
