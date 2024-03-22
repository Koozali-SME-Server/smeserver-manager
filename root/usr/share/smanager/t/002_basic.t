use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

eval "use esmith::ConfigDB";
plan skip_all => 'esmith::ConfigDB (and others) required for testing 002_basic' if $@;

plan tests => 3;


my $t = Test::Mojo->new('SrvMngr');
$t->get_ok('/')->status_is(200)->content_like(qr/SME Server 10/);
