package SrvMngr::Controller::Modules;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
#
# routes : end
#----------------------------------------------------------------------
use SrvMngr qw(theme_list init_session);

sub bugreport {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $modul = $c->render_to_string(
        inline => "<p>#    my (\$lang, \$releaseVersion,
<br>#	\$c->stash\(\'lang\', \'releaseVer\'
#	\'navigation\'</p>"
    );
    $c->stash(modul => $modul);
} ## end sub bugreport

sub support {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $modul = $c->stash('modul');
    $modul .= 'Mail result is 1 + 8.';
    $c->stash(modul => $modul, PwdSet => '0', Unsafe => '0');

    #$c->render('modules/support');
} ## end sub support

sub modsearch {
    my $c      = shift;
    my $module = $c->param('module');
    $c->app->log->info($c->log_req);
    my $redirect_url = SrvMngr->get_mod_url($module);

    if ($redirect_url ne "-1") {

        #$c->render(text => "mod_search: $module to $redirect_url");
        return $c->redirect_to($redirect_url);

        #return $c->redirect_to( url_for($redirect_url) );
    } ## end if ($redirect_url ne "-1")

    #$c->render(text => "mod_search: $module to 'welcome'");
    return $c->redirect_to($c->home_page);
} ## end sub modsearch

sub whatever {
    my $c        = shift;
    my $whatever = $c->param('whatever');
    $c->app->log->info($c->log_req . ' ' . $whatever);
    $c->render(text => "whatever: /$whatever did not match.", status => 404);
} ## end sub whatever
1;
