package SrvMngr::Controller::Request;

#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);

# retrieve a configuration db record
sub getconfig {
    my $c = shift;
    my $key = $c->param('key');

    $c->app->log->info($c->log_req . ' ' . $key);

    if ($key) {
	use esmith::ConfigDB qw(open_ro);
	my $cdb = esmith::ConfigDB->open_ro;
	return getdb( $c, $cdb, $key);
    }
}


# retrieve an accounts db record, given its name
sub getaccount {
    my $c = shift;
    my $key = $c->param('key');

    $c->app->log->info($c->log_req . ' ' . $key);

    if ($key) {
	use esmith::AccountsDB qw(open_ro);
	my $adb = esmith::AccountsDB->open_ro;
	return getdb( $c, $adb, $key);
    }
}


sub getdb {

    my ($c, $db, $key) = @_;

    if ( my $rec = $db->get($key) ) {
	return $c->render(json => { $key => { $rec->props }} );
    }
    return undef;
}


1;
