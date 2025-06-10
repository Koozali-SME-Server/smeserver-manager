# SrvMngr: a web-based Sme Koozali server administration GUI
package SrvMngr;

use strict;
use warnings;
use utf8;
binmode(STDOUT);

use Mojo::Base 'Mojolicious';

use File::Spec;
use File::Spec::Functions qw( rel2abs catdir );
use Cwd;
use Net::Netmask;

use Mojo::File qw( path );
use Mojo::Home;

use DBM::Deep;
use Mojo::JWT;
use POSIX qw(strftime);

use Mojolicious::Plugin::Config;
#use Mojolicious::Plugin::I18N;

use SrvMngr::Plugin::I18N;
use SrvMngr::I18N;
use SrvMngr::Model::Main;

use SrvMngr::Plugin::WithoutCache;

use esmith::I18N;
use esmith::ConfigDB::UTF8;
use esmith::NavigationDB; # no UTF8 raw is ok for ASCII only flat file

# Import the function(s) you need
use SrvMngr_Auth qw(check_admin_access);

#this is overwrittrn with the "release" by the spec file - release can be "99.el8.sme"
our $VERSION = '78.el8.sme'; 
#Extract the release value
if ($VERSION =~ /^(\d+)/) {
    $VERSION = $1;  # $1 contains the matched numeric digits
} else {
    $VERSION = '999' #No leading numeric digits found
}
$VERSION = eval $VERSION;

use Exporter 'import';
our @EXPORT_OK = qw( 
	init_session get_mod_url theme_list
	getNavigation ip_number validate_password is_normal_password email_simple
	mac_address_or_blank mac_address ip_number_or_blank
	lang_space get_routes_list subnet_mask get_reg_mask
	gen_locale_date_string get_public_ip_address simpleNavMerge
	);

has home => sub {
    my $path = $ENV{SRVMNGR_HOME} || getcwd;
    return Mojo::Home->new(File::Spec->rel2abs($path));
};

has config_file => sub {
    my $self = shift;
    return $ENV{SRVMNGR_CONFIG} if $ENV{SRVMNGR_CONFIG};
    return $self->home->rel_file('conf/srvmngr.conf');
};

has data_dir => sub {
    my $self = shift;
    return $ENV{SRVMNGR_DATA} if $ENV{SRVMNGR_DATA};
    return $self->home->rel_file('data');
};

has temp_dir => sub {
    my $self = shift;
    return $ENV{SRVMNGR_TEMP} if $ENV{SRVMNGR_TEMP};
    return $self->home->rel_file('temp');
};

has conf_dir => sub{
    my $self = shift;
    return $ENV{SRVMNGR_CONF} if $ENV{SRVMNGR_CONF};
    return $self->home->rel_file('conf');
};


sub startup {

    my $self = shift;

    $self->plugin( Config => { file => $self->config_file()} );

    $self->mode( $self->config->{mode} || 'production' );	#'development'

    $ENV{'MOJO_SMANAGER_DEBUG'} = $self->config->{debug} || 0;

    $self->setup_plugins;

    $self->setup_helpers;

    $self->setup_paths;

    $self->setup_sessions;

    $self->setup_routing;

    $self->setup_hooks;

    # no data in cache
    $self->renderer->cache->max_keys(0);

}


sub setup_sessions {

    my $self = shift;

    # Setup signed sessions
    $self->app->secrets( $self->config->{secrets} );
    $self->sessions->cookie_name('smanager');
    $self->sessions->default_expiration( $self->config->{timeout} );
    $self->sessions->secure( 1 );

}


sub setup_paths {

    my $self = shift;

    # Replace the default paths
    $self->renderer->paths([$self->home->rel_file('themes/default/templates')]);
    $self->static->paths([$self->home->rel_file('themes/default/public')]);

    my $theme = $self->config->{theme} || 'default';
    if ( $theme ne 'default' ) {
	# Put the new theme first
	my $t_path = $self->home->rel_file('themes/'.$theme);
	unshift @{$self->renderer->paths}, $t_path.'/templates' if -d $t_path.'/templates';
	unshift @{$self->static->paths},   $t_path.'/public' if -d $t_path.'/public';
    }

}


sub setup_helpers {

    my $self = shift;

    $self->helper(log_req => sub {
	my $c  = shift;
        my $mess = shift || '';
        my $method = $c->req->method;
        my $url = $c->req->url;
        my $version = $c->req->version;
        my $ip    = $c->tx->remote_address;
        return "Request received => $method $url HTTP/$version from $ip : $mess ";
    });

    $self->helper( 'home_page' => sub{ '/initial' } );

    $self->helper( 'auth_fail' => sub {
	my $self = shift;
	my $message = shift || $self->l('acs_NO');
        $self->flash( error => $message );
        $self->redirect_to( $self->home_page, status => 403 );
        return 0;
    });

    $self->helper( 'is_admin' => sub {
	my $self = shift;
        if ( defined $self->session->{username} &&  defined $self->session->{is_admin} ) {
    	    return $self->session->{is_admin};
    	}
        return undef;
    });

    $self->helper( 'is_unsafe' => sub {
	return SrvMngr::Model::Main->reconf_needed();
    });

    $self->helper( 'is_logged_in' => sub {
	my $self = shift;
        if ( defined $self->session->{logged_in} ) {
	    return 1 if ( $self->session('logged_in') == 1 );
	}
	return undef;
    });

    $self->helper(lang_space	=> \&_lang_space);

    $self->plugin( Config => { file => $self->config_file()} );

    $self->helper( send_email => sub {
	my ($c, $address, $subject, $body) = @_;

    if (not defined $body) {
        warn "send_email: Need 3 parameters (Address, Subject, Body)\n";
        return;
    }

    my $rcfile = $c->app->conf_dir().'/admin_muttrc';

    #warn "send_email: $rcfile * $address\n";	#$rcfile $subject $address\n";
    system( "/bin/echo \"$body\" | /usr/bin/mutt -F $rcfile -s \"$subject\" \"$address\"" ) == 0
        or warn "error sendmail:  $address \n";	# $subject";
    });

    $self->helper( pwdrst => sub {
	my $c = shift;
	my $file = $c->app->data_dir().'/pwdrst.db';
	state $db = DBM::Deep->new($file);
    });

    $self->helper( jwt => sub { 
	Mojo::JWT->new(secret => shift->app->secrets->[0] || die)
    });

    $self->helper( selected_field => sub {
                    my $self = shift;
                    my @options = shift;
                    my $selected = shift;
                    my $count = 0;
                    # search for occurence of value $selected in arrays; if found add selected => 'selected'
                    for  (my $i = 0; $i <= $#{$options[0]} ; $i++){
                      if (grep /^$selected$/,  @{$options[0][$i]}) {
                        push( @{$options[0][$i]} ,'selected', 'selected' );
                        $count++;last;
                      }
                    }
                    push ( @{$options[0]} ,[ ucfirst( $selected), $selected, 'selected', 'selected'] ) if ($count <1);
                    return @options;
    });

}


sub setup_plugins {

    my $self = shift;

    $self->plugin('TagHelpers');

    $self->plugin('RenderFile');
    
    $self->plugin('SrvMngr::Plugin::WithoutCache');

    # CSRF protection if production mode
#    $self->plugin('Mojolicious::Plugin::CSRFDefender' => {
#   Adapted plugin for use with GET method
    #$self->plugin('SrvMngr::Plugin::CSRFDefender' => {
	#onetime => 1,
	#error_status => 400,
	#error_content => 'Error: CSRF token is invalid or outdated'
    	#error_template => 'csrf_400'
	#}) if ( $self->mode eq 'production' );

    $self->plugin('SrvMngr::Plugin::I18N' => {namespace => 'SrvMngr::I18N', default => 'en'});

#    $self->plugin('Mojolicious::Plugin::FrozenSessions' => {});

    $self->helper(log_req => sub {

	my $c  = shift;
        my $mess = shift || '';

        my $method = $c->req->method;
        my $url = $c->req->url;
        my $version = $c->req->version;
        my $ip    = $c->tx->remote_address;

        return "Request received => $method $url HTTP/$version from $ip: $mess ";
    });
}


sub setup_routing {

    my $self = shift;
    my $r = $self->app->routes;
    $r->namespaces(['SrvMngr::Controller']);

    $r->get('/')->to('initial#main')->name('initial');
    $r->get('/initial')->to('initial#main')->name('initial');
    $r->get('/login')->to('login#main')->name('login');
    $r->post('/login')->to('login#login')->name('signin');
    $r->get('/manual')->to('manual#main')->name('manual');
    $r->get('/support')->to('support#main')->name('support');

    # Password reset allowed for this server
    if ( ( $self->config->{pwdreset} || '0') == 1 ) {
	$r->get('/login2')->to('login#pwdrescue')->name('pwdresc');
	$r->get('/loginc')->to('login#confpwd')->name('resetpwdconf');
        $r->get('/userpasswordr')->to('userpassword#main')->name('upwdreset');
        $r->post('/userpasswordr')->to('userpassword#change_password')->name('upwdreset2');
    }

    my $if_logged_in = $r->under( sub {
	my $c =shift;
	return $c->is_logged_in || $c->auth_fail($c->l("acs_LOGIN"));
    });
    $if_logged_in->post('/swttheme')->to('swttheme#main')->name('swttheme');
    $if_logged_in->get('/review')->to('review#main')->name('review');
    $if_logged_in->get('/logout')->to('logout#logout')->name('logout');
    $if_logged_in->get('/userpassword')->to('userpassword#main')->name('passwd');
    $if_logged_in->post('/userpassword')->to('userpassword#change_password')->name('passwd2');

	my $if_admin = $r->under( sub {
	    my $c = shift;
	    # Call the imported function directly
	    return check_admin_access($c) || $c->auth_fail($c->l("acs_ADMIN"));
	});

    $if_admin->get('/backup')->to('backup#main')->name('backup');
    $if_admin->post('/backup')->to('backup#do_display')->name('backupd');
    $if_admin->get('/backupd')->to('backup#do_display')->name('backupc'); # corrections #
    $if_admin->post('/backupd')->to('backup#do_update')->name('backupu');

    $if_admin->get('/bugreport')->to('bugreport#main')->name('bugreport');
    $if_admin->post('/bugreport')->to('bugreport#do_report')->name('bugreport2');
    $if_admin->post('/bugreportD')->to('bugreport#download_config_report')->name('bugreportD');

    $if_admin->get('/clamav')->to('clamav#main')->name('clamav');
    $if_admin->post('/clamav')->to('clamav#do_update')->name('clamav2');

    $if_admin->get('/datetime')->to('datetime#main')->name('datetime');
    $if_admin->post('/datetime')->to('datetime#do_update')->name('datetime2');

    $if_admin->get('/directory')->to('directory#main')->name('directory');
    $if_admin->post('/directory')->to('directory#do_update')->name('directory2');

    $if_admin->get('/domains')->to('domains#main')->name('domainsg');
    $if_admin->post('/domains')->to('domains#do_display')->name('domainsp');
    $if_admin->get('/domains2')->to('domains#do_display')->name('domains2g');
    $if_admin->post('/domains2')->to('domains#do_update')->name('domains2p');

    $if_admin->get('/emailsettings')->to('emailsettings#main')->name('emailsettings');
    $if_admin->post('/emailsettings')->to('emailsettings#do_display')->name('emailsetting');
    $if_admin->post('/emailsettingd')->to('emailsettings#do_update')->name('emailsettingu');

    $if_admin->get('/groups')->to('groups#main')->name('groupsl');
    $if_admin->post('/groups')->to('groups#do_display')->name('groupa');
    $if_admin->get('/groups2')->to('groups#do_display')->name('groupd');
    $if_admin->post('/groups2')->to('groups#do_update')->name('groupu');

    $if_admin->get('/hostentries')->to('hostentries#main')->name('hostentries');
    $if_admin->post('/hostentries')->to('hostentries#do_display')->name('hostentryadd');
    $if_admin->get('/hostentriesd')->to('hostentries#do_display')->name('hostentrydis');
    $if_admin->post('/hostentriesd')->to('hostentries#do_update')->name('hostentryupd');

    $if_admin->get('/ibays')->to('ibays#main')->name('ibays');
    $if_admin->post('/ibays')->to('ibays#do_display')->name('ibayadd');
    $if_admin->get('/ibaysd')->to('ibays#do_display')->name('ibaydis');
    $if_admin->post('/ibaysd')->to('ibays#do_update')->name('ibayupd');

    $if_admin->get('/localnetworks')->to('localnetworks#main')->name('localnetworks');
    $if_admin->post('/localnetworks')->to('localnetworks#do_display')->name('localnetworks');
    $if_admin->post('/localnetworksa')->to('localnetworks#do_display')->name('localnetworksadd');
    $if_admin->post('/localnetworksb')->to('localnetworks#do_display')->name('localnetworksadd1');
    $if_admin->get('/localnetworksd')->to('localnetworks#do_display')->name('localnetworksdel');
    $if_admin->post('/localnetworkse')->to('localnetworks#do_display')->name('localnetworksdel1');

    $if_admin->get('/portforwarding')->to('portforwarding#main')->name('portforwarding');
    $if_admin->post('/portforwarding')->to('portforwarding#do_display')->name('portforwarding');
    $if_admin->post('/portforwardinga')->to('portforwarding#do_display')->name('portforwardingadd');
    $if_admin->post('/portforwardingb')->to('portforwarding#do_display')->name('portforwardingadd1');
    $if_admin->get('/portforwardingd')->to('portforwarding#do_display')->name('portforwardingdel');
    $if_admin->post('/portforwardinge')->to('portforwarding#do_display')->name('portforwardingdel1');

    $if_admin->get('/printers')->to('printers#main')->name('printersg');
    $if_admin->post('/printers')->to('printers#do_display')->name('printera');
    $if_admin->get('/printers2')->to('printers#do_display')->name('printer2g');
    $if_admin->post('/printers2')->to('printers#do_update')->name('printers2p');

    $if_admin->get('/proxy')->to('proxy#main')->name('proxy');
    $if_admin->post('/proxy')->to('proxy#do_update')->name('proxy2');

    $if_admin->get('/pseudonyms')->to('pseudonyms#main')->name('pseudonymsl');
    $if_admin->post('/pseudonyms')->to('pseudonyms#do_display')->name('pseudonyma');
    $if_admin->get('/pseudonyms2')->to('pseudonyms#do_display')->name('pseudonymd');
    $if_admin->post('/pseudonyms2')->to('pseudonyms#do_update')->name('pseudonymu');

    $if_admin->get('/qmailanalog')->to('qmailanalog#main')->name('qmailanalog');
    $if_admin->post('/qmailanalog')->to('qmailanalog#do_update')->name('qmailanalog2');

    $if_admin->get('/quota')->to('quota#main')->name('quota');
    $if_admin->get('/quotad')->to('quota#do_display')->name('quotalist');
    $if_admin->post('/quotad')->to('quota#do_update')->name('quotaupd');
    $if_admin->post('/quota2')->to('quota#do_update')->name('quotaval');

    $if_admin->get('/reboot')->to('reboot#main')->name('reboot');
    $if_admin->post('/reboot')->to('reboot#do_action')->name('rebootact');

    $if_admin->get('/remoteaccess')->to('remoteaccess#main')->name('remoteaccess');
    $if_admin->post('/remoteaccess')->to('remoteaccess#do_action')->name('remoteaccessact');

    $if_admin->get('/support')->to('support#main')->name('support');

    $if_admin->get('/useraccounts')->to('useraccounts#main')->name('useraccounts');
    $if_admin->post('/useraccounts')->to('useraccounts#do_display')->name('useraccountadd');
    $if_admin->get('/useraccountsd')->to('useraccounts#do_display')->name('useraccountdis');
    $if_admin->post('/useraccountsd')->to('useraccounts#do_update')->name('useraccountupd');
    $if_admin->post('/useraccountso')->to('useraccounts#do_display')->name('useraccountvpn');

    $if_admin->get('/viewlogfiles')->to('viewlogfiles#main')->name('viewlogfiles');
    $if_admin->post('/viewlogfiles')->to('viewlogfiles#do_action')->name('viewlogfiles2');
    $if_admin->post('/viewlogfilesr')->to('viewlogfiles#do_action')->name('viewlogfilesr');

    $if_admin->get('/yum')->to('yum#main')->name('yum');
    $if_admin->post('/yum')->to('yum#do_display')->name('yumd1');
    $if_admin->get('/yumd')->to('yum#do_display')->name('yumd');
    $if_admin->post('/yumd')->to('yum#do_update')->name('yumu');

    $if_admin->get('/welcome')->to('welcome#main')->name('welcome');

    $if_admin->get('/workgroup')->to('workgroup#main')->name('workgroup');
    $if_admin->post('/workgroup')->to('workgroup#do_update')->name('workgroup2');

    # additional routes (for contribs) got from 'routes' db
    #my @routes = @{SrvMngr::get_routes_list()};

    foreach (@{SrvMngr::get_routes_list()}) {

	if ( defined $_->{method} and defined $_->{url} and defined $_->{ctlact} and defined $_->{name} ) {
	    my $menu = defined $_->{menu} ? $_->{menu} : 'A';
	    if ( $menu eq 'N' ) {
	    	$r->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
			if ( $_->{method} eq 'get');
		$r->post($_->{url})->to($_->{ctlact})->name($_->{name})
			if ( $_->{method} eq 'post');
	    } elsif ( $menu eq 'U' ) {
	    	$if_logged_in->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
			if ( $_->{method} eq 'get');
		$if_logged_in->post($_->{url})->to($_->{ctlact})->name($_->{name})
			if ( $_->{method} eq 'post');
	    } else {
	    	$if_admin->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
			if ( $_->{method} eq 'get');
		$if_admin->post($_->{url})->to($_->{ctlact})->name($_->{name})
			if ( $_->{method} eq 'post');
	    }
	}
    }

    $if_admin->get('/config/:key' => {key => qr/[a-z0-9]{2,32}/})->to('request#getconfig')->name('getconfig');
    $if_admin->get('/account/:key' => {key => qr/[a-z0-9]{2,32}/})->to('request#getaccount')->name('getaccount');
    $if_admin->get('/:module' => {module => qr/[a-z0-9]{2,32}/})->to('modules#modsearch')->name('module_search');
    $if_admin->any('/*whatever' => {whatever => ''})->to('modules#whatever')->name('whatever');

}


sub setup_hooks {
    my ($c) = @_;

    $c->hook( before_routes => sub {
	my $c = shift;
	if ( not defined $c->session->{lang} ) {
    	    SrvMngr::init_session ( $c );
	}
	$c->lang_space();
    });

    if ( my $path = $ENV{MOJO_REVERSE_PROXY} ) {
	my @path_parts = grep /\S/, split m{/}, $path;
        $c->hook( before_dispatch => sub {
	    my ( $c ) = @_;
    	    my $url = $c->req->url;
            my $base = $url->base;
	    push @{ $base->path }, @path_parts;
    	    $base->path->trailing_slash(1);
            $url->path->leading_slash(0);
	});
    }

}


sub init_session {

    my $c = shift;
    $c->app->log->info("Init app session.");

    my %datas = ();
    %datas = %{SrvMngr::Model::Main->init_data()};

    $c->session->{lang} = $datas{'lang'};
    $c->session->{copyRight} = $c->l($datas{'copyRight'});
    $c->session->{releaseVersion} = $datas{'releaseVersion'};
    $c->session->{PwdSet} = $datas{'PwdSet'};
    $c->session->{SystemName} = $datas{'SystemName'};
    $c->session->{DomainName} = $datas{'DomainName'};
    $c->session->{Access} = $datas{'Access'};
    if ( not defined $c->session->{CurrentTheme} ) {
	$c->session->{CurrentTheme} = $c->config->{theme};
    }
}


sub get_mod_url{

    my $c = shift;
    my $module = shift;

    # test if module (panel) exists 
    my $module_file = $c->config->{modules_dir} . '/' . ucfirst($module) . '.pm';
    if ( -e $module_file){
        return "/$module";
    }
    return -1; 
}


=head2 theme_list()

Returns a hash of themes for the header theme field's drop down list.

=cut


sub theme_list {

    my $c  = shift;

    my @files = ();
    my @themes = ();
    my $theme_ignore = "(\.\.?)";

#    my $themedir = '/usr/share/smanager/themes/';
    my $themedir = $c->app->home->rel_file('themes/');

    if (opendir (DIR, $themedir)) {
        @files = grep (!/^${theme_ignore}$/, readdir(DIR));
        closedir (DIR);
    } else {
        warn "Can't open directory $themedir\n";
    }

    foreach my $theme (@files) {
        if (-d "$themedir/$theme") {
		push @themes, $theme;
    	}
    }

    return \@themes;
}


#------------------------------------------------------------
# subroutine to feed navigation bar
#------------------------------------------------------------

sub getNavigation {
    my $class  = shift; #not the controller as it is called as an external, not part of the controller.
    my $lang = shift || 'en-us';
    my $menu = shift || 'N';
    my $username = shift || ''; #Username when logged in as a user not admin

#    my $lang = $c->session->{lang} || 'en-us';

    # Use this variable throughout to keep track of files
    # list of just the files

    my @files = ();
    my %files_hash = ();
    
    # Added: Store allowed admin panels for non-admin users
    my @allowed_admin_panels = ();
    my $is_admin = 1;  # Default to admin (full access)
    
    # Added: Check if user is non-admin and get their allowed panels
    if ($username ne '') {
        # Get the AccountsDB to check user permissions
        my $accountsdb = esmith::AccountsDB::UTF8->open_ro() or
            die "Couldn't open AccountsDB\n";
            
        # Check if user has AdminPanels property
        my $user_rec = $accountsdb->get($username);
        if (defined $user_rec && $user_rec->prop('AdminPanels')) {
            $is_admin = 0;  # User is non-admin with specific panel access
            # Get comma-separated list of allowed admin panels
            my $admin_panels = $user_rec->prop('AdminPanels');
            @allowed_admin_panels = split(/,/, $admin_panels);
        }
    }

    #-----------------------------------------------------
    # Determine the directory where the functions are kept
    #----------------------------------------------------- 
	my $navigation_ctlr_ignore = 
	"(\.\.?|.*\-Custom\.pm|Swttheme\.pm|Login\.pm|Request\.pm|Modules\.pm|Legacypanel\.pm(-.*)?)";
#	"(\.\.?|Initial\.pm|.*Manual\.pm|Swttheme\.pm|Request\.pm|Modules\.pm(-.*)?)";
	my $navigation_cgi_ignore = 
	"(\.\.?|navigation|noframes|online-manual|(internal|pleasewait)(-.*)?)";

#	my $ctrldir = $c->app->home->rel_file('lib/SrvMngr/Controller');
	my $ctrldir = '/usr/share/smanager/lib/SrvMngr/Controller';
	my $cgidir = '/etc/e-smith/web/panels/manager/cgi-bin/';

	if (opendir (DIR, $ctrldir)) {
	    @files = grep (!/^${navigation_ctlr_ignore}$/,
		readdir (DIR));
	    closedir (DIR);
	} else {
	    warn "Can't open directory $ctrldir\n";
	}

	foreach my $file (@files) {
	    next if (-d "$ctrldir/$file");
	    next if ( $file !~ m/^[A-Z].*\.pm$/ );

	    my $file2 = lc($file);
	    $file2 =~ s/\.pm$//;
	    $files_hash{$file2} = 'ctrl';
	}

	# Is there some old panels not managed in new way ?
	@files = ();
	if (opendir (DIR, $cgidir)) {
	    @files = grep (!/^${navigation_cgi_ignore}$/,
		readdir (DIR));
	    closedir (DIR);
	}

	foreach my $file (@files) {
	    next if (-d "$cgidir/$file");
	    $files_hash{$file} = 'cgim' if ( ! exists $files_hash{$file} );
	}

    #-------------------------------------------------- 
    # For each script, extract the description and category
    # information. Build up an associative array mapping headings
    # to heading structures. Each heading structure contains the
    # total weight for the heading, the number of times the heading
    # has been encountered, and another associative array mapping
    # descriptions to description structures. Each description
    # structure contains the filename of the particular cgi script
    # and a weight.
    #-------------------------------------------------- 
    my %nav = ();

    use constant NAVIGATIONDIR => '/home/e-smith/db/navigation2';
#    use constant WEBFUNCTIONS  => '/etc/e-smith/web/functions';

    my $navinfo = NAVIGATIONDIR . "/navigation.$lang";

    my $navdb = esmith::NavigationDB->open_ro( $navinfo ) or die "Couldn't open $navinfo\n"; # no UTF8

    # Check the navdb for anything with a UrlPath, which means that it doesn't
    # have a cgi file to be picked up by the above code. Ideally, only pages
    # that exist should be in the db, but that's not the case. Anything
    # without a cgi file will have to remove themselves on uninstall from the
    # navigation dbs.
    foreach my $rec ($navdb->get_all)
    {
	if ($rec->prop('UrlPath'))
	{
	    $files_hash{$rec->{key}} = $cgidir;
	}
    }

    foreach my $file (keys %files_hash)
		{
		#my $heading = 'Unknown';
		my $heading = 'Legacy';
		
		my $description = $file;
		my $headingWeight = 99999;
		my $descriptionWeight = 99999;
		my $urlpath = '';
		my $menucat = 'A';	# admin menu (default)

		my $rec = $navdb->get($file);

		if (defined $rec)
		{
			$heading = $rec->prop('Heading');
			$description = $rec->prop('Description');
			$headingWeight = $rec->prop('HeadingWeight') || 99999; #Stop noise in logs if file in dir does not have nav header.
			$descriptionWeight = $rec->prop('DescriptionWeight');
			$urlpath = $rec->prop('UrlPath') || '';
			$menucat = $rec->prop('MenuCat') || 'A';	# admin menu (default)
		}
		
		# Added: Check if this is an admin menu item and if user has access
		if ($menucat eq 'A' && !$is_admin) {
			# Skip this admin panel if user doesn't have access to it
			my $has_access = 0;
			my $file_no_ext = $file;
			$file_no_ext =~ s/\.pm$//;  # Remove .pm extension if present
			foreach my $allowed_panel (@allowed_admin_panels) {
				if ($file_no_ext eq lc($allowed_panel)) {
					#die("Here!!$file $file_no_ext $allowed_panel ");
					$has_access = 1;
					last;
				}
			}
			next if !$has_access;
		}

		next if $menu ne $menucat;

		#-------------------------------------------------- 
		# add heading, description and weight information to data structure
		#-------------------------------------------------- 

		unless (exists $nav {$heading})
		{
			$nav {$heading} = { COUNT => 0, WEIGHT => 0, DESCRIPTIONS => [] };
		}

		$nav {$heading} {'COUNT'} ++;
		$nav {$heading} {'WEIGHT'} += $headingWeight;

		# Check for manager panel, and assign the appropriate
		#  cgi-bin prefix for the links.
		# Grab the last 2 directories by splitting for '/'s and
		#  then concatenating the last 2
		# probably a better way, but I don't know it.

		my $path;
		if ( $files_hash{$file} eq 'ctrl') {
			$path = "2";
		} elsif ( $files_hash{$file} eq 'cgim') {
			$path = "/cgi-bin";
		} else {
			my @filename = split /\//, $files_hash{$file};
			$path = "/$filename[scalar @filename - 2]/$filename[scalar @filename - 1]";
		};

		push @{ $nav {$heading} {'DESCRIPTIONS'} },
			{ DESCRIPTION => $description,
			  WEIGHT => $descriptionWeight, 
			  FILENAME => $urlpath ? $urlpath : "$path/$file",
			  CGIPATH => $path,
			  MENUCAT => $menucat
			};
    }

	return \%nav;

}

sub simpleNavMerge {
	#Used to merge two nav structures - used for the user and selected admin menu.
    my ($class,$nav1, $nav2) = @_;
    my %result = %$nav1;  # Start with a copy of first nav
    
    # Merge in second nav
    foreach my $heading (keys %$nav2) {
        if (exists $result{$heading}) {
            # Add counts and weights
            $result{$heading}{COUNT} += $nav2->{$heading}{COUNT};
            $result{$heading}{WEIGHT} += $nav2->{$heading}{WEIGHT};
            # Append descriptions
            push @{$result{$heading}{DESCRIPTIONS}}, @{$nav2->{$heading}{DESCRIPTIONS}};
        } else {
            # Just copy the heading
            $result{$heading} = $nav2->{$heading};
        }
    }
    
    return \%result;
}



sub _lang_space {

    my $c = shift;

    my $panel = $c->tx->req->url;
    if ( $panel =~ m/\.css$|\.js$|\.jpg$|\.gif$|\.png$/ ) {
	#warn "panel not treated $panel";
	return
    }

    my $lang = ( $c->tx->req->headers->accept_language || ['en_US'] );
    $lang = (split(/,/, $lang))[0];
#    my $lang = (split(/,/, $c->tx->req->headers->accept_language))[0];
## convert xx_XX lang format to xx-xx + delete .UTFxx + lowercase
#    $lang =~ s/_(.*)\..*$/-${1}/;		# just keep 'en-us'
    ##$lang = lc( substr( $lang,0,2 ) );	# just keep 'en'

    $panel = '/initial' if ($panel eq '/' or $panel eq '');

    (my $module = $panel) =~ s|\?.*$||;
    $module =~ s|^/||;
    $module = ucfirst($module);

    my $moduleLong = "SrvMngr::I18N::Modules::$module";
    (my $dir = $moduleLong) =~ s|::|/|g;
    my $I18Ndir = $c->app->home->rel_file('lib/') . '/' . $dir;

    ##$c->app->log->debug("$panel $module $moduleLong $I18Ndir");
    if ( ! -d $I18Ndir ) {
	( $moduleLong = $moduleLong) =~ s/.$//;
	( $I18Ndir = $I18Ndir) =~ s/.$//;
    }
    if ( -d $I18Ndir ) {
    ##    $c->app->log->debug("hook_b_r->panel route. lang: $lang  namespace: $moduleLong ldir; $I18Ndir");
        warn "NS already loaded: $moduleLong \n" if ( $c->i18ns() eq $moduleLong );		# i18ns changed
	$c->i18ns( $moduleLong, $lang );
    } else {
        warn "Locale lexicon missing for $module \n";
    }
};


sub get_routes_list {

    my $c  = shift;

    my $rtdb = esmith::ConfigDB::UTF8->open_ro('routes') || die 'Cannot open Routes db';
    my @routes = $rtdb->get_all();
    my @rt;

    for (@routes) {
	my ( $contrib, $name ) = split ( /\+/, $_->key);
        push @rt, 
	    { 	'method' => $_->prop('Method'), 'url' => $_->prop('Url'), 
		'ctlact' => $_->prop('Ctlact'), 'menu' => $_->prop('Menu'),
		'name' => $name, 'contrib' => $contrib,
	    };
    }
    return \@rt;

}


sub ip_number {

#  from CGI::FormMagick::Validator qw( ip_number );

    my ($c, $data) = @_;

    return undef unless defined $data;

    return $c->l('FM_IP_NUMBER1') . " (" . $data . ")" unless $data =~ /^[\d.]+$/;

    my @octets = split /\./, $data;
    my $dots = ($data =~ tr/.//);

    return $c->l('FM_IP_NUMBER2') unless (scalar @octets == 4 and $dots == 3);

    foreach my $octet (@octets) {
        return $c->l("FM_IP_NUMBER3", $octet) if $octet > 255;
    }

    return 'OK';
}

sub validate_password {
    my ($c, $strength, $pass) = @_;
    use esmith::util;
    use POSIX qw(locale_h);
    use locale;
    my $old_locale = setlocale(LC_ALL);
    setlocale(LC_ALL, "en_US");
    my $reason = esmith::util::validatePassword($pass,$strength);
    return "OK" if ($reason eq "ok");
    setlocale(LC_ALL, $old_locale);
    return
          $c->l("Bad Password Choice") . ": "
        . $c->l("The password you have chosen is not a good choice, because") . " "
        . $c->l($reason). ".";
} ## end sub validate_password

# to deprecate : this is not anymore a way to validate our passwords
sub is_normal_password {

#  from CGI::FormMagick::Validator qw( password );

    my ($c, $data) = @_;
    $_ = $data;
    if (not defined $_) {
        return $c->l("FM_PASSWORD1");
    } elsif (/\d/ and /[A-Z]/ and /[a-z]/ and /\W|_/ and length($_) > 6) {
        return "OK";
    } else {
        return $c->l("FM_PASSWORD2");
    }
}

sub gen_locale_date_string
{
    my $self = shift;
    my $i18n = esmith::I18N->new();
    $i18n->setLocale('formmagick', $i18n->preferredLanguage());
    return strftime "%c", localtime;
}

sub get_public_ip_address
{
    my $self = shift;
	my $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    my $sysconfig = $cdb->get('sysconfig');
    if ($sysconfig)
    {
        my $publicIP = $sysconfig->prop('PublicIP');
        if ($publicIP)
        {
            return $publicIP;
        }
    }
    return undef;
}

sub email_simple {
    my ($c, $data) = @_;

    use Mail::RFC822::Address;

    if (not defined $data ) {
        return $c->l("FM_EMAIL_SIMPLE1");
	} elsif (Mail::RFC822::Address::valid($data)) {
        return "OK";
    } else {
        return $c->l("FM_EMAIL_SIMPLE2");
    }
}


sub mac_address_or_blank {
    my ($c, $data) = @_;
    return "OK" unless $data;
    return mac_address($c, $data);
}


sub mac_address {

#	from CGI::FormMagick::Validator::Network

    my ($c, $data) = @_;

    $_ = lc $data;  # easier to match on $_
    if (not defined $_) {
        return $c->l('FM_MAC_ADDRESS1');
    } elsif (/^([0-9a-f][0-9a-f](:[0-9a-f][0-9a-f]){5})$/) {
        return "OK";
    } else {
        return $c->l('FM_MAC_ADDRESS2');
    }
}


sub ip_number_or_blank {

    # XXX - FIXME - we should push this down into CGI::FormMagick

    my $c = shift;
    my $ip = shift;

    if (!defined($ip) || $ip eq "")
    {
        return 'OK';
    }

    return ip_number( $c, $ip ); 
}


sub subnet_mask {

    my ( $data ) = @_;

    # we test for a valid mask or bit mask
    my $tip="192.168.1.50";
    my $block = new Net::Netmask("$tip/$data") or return "INV1 $data";

    if ($block->mask() eq "$data" || $block->bits() eq "$data") {
        return "OK";
    }
    return "INV2 $data";
}


sub get_reg_mask {

    my ( $address, $mask ) = @_;

    # we transform bit mask to regular mask
    my $block = new Net::Netmask("$address/$mask");

    return $block->mask();
}


1;
