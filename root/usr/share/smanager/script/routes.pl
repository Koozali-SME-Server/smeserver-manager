#! /usr/bin/perl -w

# purge Routes database (uninstalled contribs)

use strict;
use warnings;

use esmith::ConfigDB::UTF8;

use constant WEBFUNCTIONS => '/usr/share/smanager/lib/SrvMngr/Controller/';

my $rtdb = esmith::ConfigDB::UTF8->open('routes') or
        die "Couldn't access Routes database\n";

my @routes = $rtdb->get_all_by_prop( type => 'route' );

exit 0 unless @routes;

my ($sv_contrib, $sv_exist, $file) = '';

for (@routes) {
    my ( $contrib, $name ) = split ( /\+/, $_->key);

    if ( $contrib ne $sv_contrib) {
	$sv_contrib = $contrib;
	$file = WEBFUNCTIONS . ucfirst($contrib) .'.pm';
	$sv_exist = ( -f $file ) ? 1 : 0;
    }
    # print("$contrib $file deleted \n") unless $sv_exist;
    $rtdb->get($_->key)->delete() unless $sv_exist;

}

exit 0;
