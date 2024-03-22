use Mojo::Base -strict;

use utf8;
use Test::More;

plan skip_all => 'unset QUICK_TEST to enable this test' if $ENV{QUICK_TEST};

plan tests => 3;

use FindBin;
use lib "$FindBin::Bin/../lib";

package main;
use Mojolicious::Lite;

use Test::Mojo;

plugin 'SrvMngr::Plugin::I18N' => {
    namespace => 'SrvMngr::I18N::Modules::General', default => 'en'
    };

get '/' => 'index';

my $t = Test::Mojo->new;

$t->get_ok('/')->status_is(200)
    ->content_is("Disabled en\n");

done_testing();

__DATA__
@@ index.html.ep
<%=l 'DISABLED' %> <%= languages %>
