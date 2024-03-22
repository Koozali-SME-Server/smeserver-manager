use Test::More;

plan skip_all => 'unset QUICK_TEST to enable this test' if $ENV{QUICK_TEST};

plan tests => 8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('SrvMngr');

# modules
use_ok('Mojolicious');
use_ok('Mojolicious::Plugin::I18N');
use_ok('Mojolicious::Plugin::RenderFile');
use_ok('Mojolicious::Plugin::CSRFDefender');
use_ok('Net::Netmask');
use_ok('DBM::Deep');
use_ok('Mojo::JWT');
