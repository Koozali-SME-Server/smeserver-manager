use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

eval "use esmith::ConfigDB";
plan skip_all => 'esmith::ConfigDB (and others) required for testing 004_panels' if $@;

my $tests;
plan tests => $tests;

BEGIN { $tests += 2 * 3 };

my $t = Test::Mojo->new('SrvMngr');
$t->ua->max_redirects(1);

$t->get_ok('/')->status_is(200)->content_like(qr/SME Server 10/);
$t->get_ok('/manual')->status_is(200)->content_like(qr/SME Server 10/);

BEGIN { $tests += 5 * 2 };
my @panels = qw/ Initial Login Manual Support Request /;

for ( @panels ) {
    $t->get_ok("/$_")->status_is(200);
}

BEGIN { $tests += 29 * 2 };
@panels = qw/ Backup Bugreport Clamav Datetime 
 Directory Domains Emailsettings Groups
 Hostentries Ibays Localnetworks Logout
 Modules Portforwarding Printers Proxy
 Pseudonyms Qmailanalog Quota Reboot
 Remoteaccess Review Support Swttheme
 Useraccounts Userpassword 
 Viewlogfiles Workgroup Yum /;

for ( @panels ) {
    $t->get_ok("/$_")->status_is(200);
}

##done_testing();
