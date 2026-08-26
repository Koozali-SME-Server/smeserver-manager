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

use Data::Dumper;

use Apache::AuthTkt;
# Loading AuthTkt config
my $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");
use Mojo::Util 'url_unescape';

# Import the function(s) you need
use SrvMngr_Auth qw(check_admin_access);

#this is overwritten with the "release" by the spec file - release can be "99.el8.sme"
our $VERSION = '247.el8.sme'; 
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
	handle_tkt lang_space get_routes_list subnet_mask get_reg_mask
	gen_locale_date_string get_public_ip_address simpleNavMerge 
    validate_Phone validate_NonEmptyString
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

    $self->app->log->info("Server manager II version:$VERSION");
    
    $self->plugin( Config => { file => $self->config_file()} );

    $self->mode( $self->config->{mode} || 'production' );	#'development'

    $ENV{'MOJO_SMANAGER_DEBUG'} = $self->config->{debug} || 0;
    
    $ENV{'PATH'} = '/root/perl5/bin:/usr/share/Modules/bin:/sbin/e-smith:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin';

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

sub _handle_tkt {
  my $c  = shift;
  # Extract the raw path string (e.g., "/smanager/useraccounts/subdir")
  my $from = $c->req->url->path->to_string;
  
  # Safely strip the "smanager/" prefix if it exists
  #TODO FIXME :detect this a better way in case we change the path to manager
  $from =~ s{^/?smanager/}{};
  
  # Add a leading slash so Mojolicious treats it as a root-level absolute path
  $from = "/$from" unless $from =~ m{^/};

  # Append query string if present (e.g., ?id=12)
  my $query = $c->req->url->query->to_string;
  $from .= "?$query" if $query;

  # Fallbacks: If it is empty, root, or pointing directly to login, use the home page
  if (!$from || $from eq '/' || $from =~ m{^/login}) {
      $from = $c->home_page;
  }

  $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");
  my $ticket= ( $c->cookie('auth_tkt') ) ? url_unescape $c->cookie('auth_tkt') : undef;
  my $server_name = $c->req->headers->header('X-Forwarded-Host');
  $server_name ||= $ENV{SERVER_NAME} if $ENV{SERVER_NAME};
  my $AUTH_DOMAIN = $server_name;
  my @auth_domain = $AUTH_DOMAIN && $AUTH_DOMAIN =~ /\./ ? ( domain => $AUTH_DOMAIN ) : ();
  my $probe = $c->cookie('auth_probe');
  my $back = $c->cookie($at->back_cookie_name) if $at->back_cookie_name;
  my $have_cookies = $ticket || $probe || $back || '';
  my $mode = 'login';
  # TODO add ip of the browser (not the proxy)
  my $ip_addr = undef;
  my $debug    = $c->config('debug');
  $debug = 3 if $debug;
  my @expires = $at->cookie_expires ? ( -expires => sprintf("+%ss", $at->cookie_expires) ) :  ();
  if ($ticket) {
    $c->log->debug("auth_tkt: $ticket") if $debug;
    # Check if the user is already "logged in" in the Mojo session
    my $valid_ticket = $at->validate_ticket($ticket, ip_addr =>'',ignore_ip => 1);
    if ( (defined $valid_ticket) && ($c->session('username')) ) {
        $c->log->debug("TKT cookie age: ".(time()-$valid_ticket->{'ts'}). " and TKT cookie timeout: ".$at->timeout()) if $debug;
        if ((time()-$valid_ticket->{'ts'}) > $at->timeout() ) {
          $c->log->debug("TKT expired, removing") if $debug;
          #TODO logout and destroy cookie
          $c->app->log->info($c->log_req);
          $c->session(expires => 1);
          $c->flash(success => 'Goodbye');
          $c->cookie(auth_tkt => '', {
                  name => $at->cookie_name,
                  value => "",
                  path   => '/',
                  secure => $at->require_ssl,
                  expires => '-1h',
                  @auth_domain,
                  });
          $c->redirect_to($c->home_page);
        } elsif ((time()-$valid_ticket->{'ts'}) > $at->timeout()/2) {
           #TODO use the TKT setting instead of arbitrary /2
           $c->log->debug("TKT needs refresh") if $debug;
           # set authtkt
           my $user_data = join(':', time(), $ip_addr || '');    # Optional
           my $tkt = $at->ticket(uid => $c->session('username'), data => $user_data, ip_addr => $ip_addr, debug => $debug);
           $c->cookie(auth_tkt =>$tkt, {
                  name => $at->cookie_name,
                  path   => '/',
                  secure => $at->require_ssl,
                  samesite  => 'Lax',
                  @expires,
                  @auth_domain,
                  });
        } else {
             $c->log->debug("TKT active") if $debug;
        }
    } elsif ( (defined $valid_ticket) && ( ! $c->session('username')) ) {
        $c->log->debug("TKT but not logged in") if $debug;
        if ((time()-$valid_ticket->{'ts'}) < $at->timeout() ) {
            my $name =  $valid_ticket->{uid};
            $c->session(logged_in => 1);        # set the logged_in flag
            $c->session(username  => $name);    # keep a copy of the username
            #    if ( $name eq 'admin' || $adb->is_user_in_group($name, 'Admin') )  # for futur use
            if ($name eq 'admin') {
               $c->session(is_admin => 1);
            } else {
               $c->session(is_admin => 0);
            }
            $c->session(expiration => $c->config->{timeout} );     # expire this session in the time set  in config
            $c->flash(success => $c->l('use_WELCOME'));
            SrvMngr::Controller::Login::record_login_attempt($c, 'SUCCESS');
            $c->flash(success => "Welcome back! Redirecting you now.");
            $c->log->debug("Valid ticket so we log in the user, redirect to  $from") if $debug;
            return $c->redirect_to($from);
        } else {
            # delete TKT
            $c->log->debug("TKT expired, removing") if $debug;
            $c->cookie(auth_tkt => '', {
                    name => $at->cookie_name,
                    value => "",
                    path   => '/',
                    secure => $at->require_ssl,
                    expires => '-1h',
                    @auth_domain,
                  });
        }
    }
  }
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
    $self->helper(handle_tkt  => \&_handle_tkt);

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

	$self->plugin('SrvMngr::Plugin::CSRFProtectBuiltin' => {
	});

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

	#extra route to pass the locale to a JS template
	$r->get('/get-locale')->to('initial#get_locale')->name('get-locale'); 

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
    $if_admin->post('/datetimeu')->to('datetime#do_update')->name('datetimeu');
    $if_admin->get('/datetimed')->to('datetime#do_display')->name('datetimed');
    $if_admin->post('/datetimet')->to('datetime#do_testntp')->name('datetimet');


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

    $if_admin->get('/mailanalog')->to('mailanalog#main')->name('mailanalog');
    $if_admin->post('/mailanalog')->to('mailanalog#do_update')->name('mailanalog2');

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
    $if_admin->post('/viewlogfilesd')->to('viewlogfiles#do_action')->name('viewlogfilesd');
    $if_admin->post('/viewlogfilesr')->to('viewlogfiles#do_action')->name('viewlogfilesr');
    $if_admin->get('/viewlogfilest')->to('viewlogfiles#stream_logs', format => 0)->name('viewlogfilest');


    $if_admin->get('/yum')->to('yum#main')->name('yum');
    $if_admin->post('/yum')->to('yum#do_display')->name('yumd1');
    $if_admin->get('/yumd')->to('yum#do_display')->name('yumd');
    $if_admin->post('/yumd')->to('yum#do_update')->name('yumu');
    
    $if_admin->get ('/dnf')->to('dnf#do_show')->name('dnf');
    $if_admin->post('/dnf/start/:function')->to('dnf#start_dnf')->name('dnf_start_dnf');
    $if_admin->get ('/dnf/stream/:run_id')->to('dnf#dnf_stream')->name('dnf_stream');
    $if_admin->get('/dnf/options/:function')->to('dnf#dnf_options')->name('dnf_options');
    $if_admin->get('/dnf/partial')->to('dnf#dnf_partial')->name('dnf_partial');
    $if_admin->get('/dnf/status')->to('dnf#dnf_status')->name('dnf_status');
    $if_admin->post('/dnfd')->to('dnf#do_update')->name('dnfd');
    $if_admin->get('/dnfd')->to('dnf#dnf_options')->name('dnf_from_config');

    $if_admin->get('/welcome')->to('welcome#main')->name('welcome');

    $if_admin->get('/workgroup')->to('workgroup#main')->name('workgroup');
    $if_admin->post('/workgroup')->to('workgroup#do_update')->name('workgroup2');

    # additional routes (for contribs) got from 'routes' db
    #my @routes = @{SrvMngr::get_routes_list()};

    #foreach (@{SrvMngr::get_routes_list()}) {
		#if ( defined $_->{method} and defined $_->{url} and defined $_->{ctlact} and defined $_->{name} ) {
			#my $menu = defined $_->{menu} ? $_->{menu} : 'A';
			#if ( $menu eq 'N' ) {
				#$r->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
				#if ( $_->{method} eq 'get');
			#$r->post($_->{url})->to($_->{ctlact})->name($_->{name})
				#if ( $_->{method} eq 'post');
			#} elsif ( $menu eq 'U' ) {
				#$if_logged_in->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
				#if ( $_->{method} eq 'get');
			#$if_logged_in->post($_->{url})->to($_->{ctlact})->name($_->{name})
				#if ( $_->{method} eq 'post');
			#} else {
				#$if_admin->get($_->{url})->to($_->{ctlact})->name($_->{name}) 
				#if ( $_->{method} eq 'get');
			#$if_admin->post($_->{url})->to($_->{ctlact})->name($_->{name})
				#if ( $_->{method} eq 'post');
			#}
		#}
    #}
    
    foreach my $route (@{SrvMngr::get_routes_list()}) {
		if (defined $route->{method} && defined $route->{url} && defined $route->{ctlact} && defined $route->{name}) {
			my $menu = defined $route->{menu} ? $route->{menu} : 'A';
			
			# Fix controller case: convert "ControllerName" to "controllername" in "ControllerName#action"
			# this is so that AdminLTE breadcrumb works  - it appears that perl Packages names are NOT case sensitive 
			# and that the breadcrumb package assumes that the package name is the same as the main route.
			my ($controller, $action) = split /#/, $route->{ctlact}, 2;
			my $fixed_ctlact = lc($controller) . '#' . $action;
			
			if ($menu eq 'N') {
				$r->get($route->{url})->to($fixed_ctlact)->name($route->{name}) 
					if $route->{method} eq 'get';
				$r->post($route->{url})->to($fixed_ctlact)->name($route->{name})
					if $route->{method} eq 'post';
			}
			elsif ($menu eq 'U') {
				$if_logged_in->get($route->{url})->to($fixed_ctlact)->name($route->{name}) 
					if $route->{method} eq 'get';
				$if_logged_in->post($route->{url})->to($fixed_ctlact)->name($route->{name})
					if $route->{method} eq 'post';
			}
			else {  # Default: menu 'A'
				$if_admin->get($route->{url})->to($fixed_ctlact)->name($route->{name}) 
					if $route->{method} eq 'get';
				$if_admin->post($route->{url})->to($fixed_ctlact)->name($route->{name})
					if $route->{method} eq 'post';
			}
		}
	}


    $if_admin->get('/config/:key' => {key => qr/[a-z0-9]{2,32}/})->to('request#getconfig')->name('getconfig');
    $if_admin->get('/account/:key' => {key => qr/[a-z0-9]{2,32}/})->to('request#getaccount')->name('getaccount');

    $if_admin->get('/:module' => {module => qr/[a-z0-9]{2,32}/})->to('modules#modsearch')->name('module_search');
    $if_admin->any('/*whatever' => {whatever => ''})->to('modules#whatever')->name('whatever');

}


sub get_locale {
  my $c = shift;
  # $c->app->log->info($c->log_req); #Reduce noise in log.
  # Locale already saved in stash 'locale'
  # and "Please Wait" localised saved in stash "pleasewait"
  $c->render(template => 'get-locale', format => 'js');
};


sub setup_hooks {
    my ($c) = @_;

    $c->hook( before_routes => sub {
	my $c = shift;
	if ( not defined $c->session->{lang} ) {
    	    SrvMngr::init_session ( $c );
	}
	$c->lang_space();
          $c->handle_tkt();
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
    my $debug    = $c->config('debug');

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
	$c->log->debug("Found theme:$theme") if $debug;
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
        $is_admin = 0;  # User is non-admin with specific panel access
        my $accountsdb = esmith::AccountsDB::UTF8->open_ro() or
            die "Couldn't open AccountsDB\n";
            
        # Check if user has AdminPanels property
        my $user_rec = $accountsdb->get($username);
        if (defined $user_rec && $user_rec->prop('AdminPanels')) {
            # Get comma-separated list of allowed admin panels
            my $admin_panels = $user_rec->prop('AdminPanels');
			@allowed_admin_panels = $admin_panels eq '' ? () : split(/,/, $admin_panels);
            #@allowed_admin_panels = split(/,/, $admin_panels);
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

    # $lang here is whatever the I18N layer negotiated for this request - it
    # can be a bare base language (e.g. 'en') but it can equally be a full
    # region-qualified tag straight from the browser's Accept-Language header
    # (e.g. 'en-gb', 'en-us', 'fr-ca'). navigation2-conf only ever builds one
    # navigation.$lang file per base language returned by
    # esmith::I18N->availableLanguages() (which lists /etc/e-smith/locale) -
    # it never creates region-qualified variants UNLESS that exact tag was
    # itself one of the base languages the module ships translations for
    # (e.g. 'pt-br' and 'zh-tw' are real, distinct first-class languages in
    # this project, not fallbacks of 'pt'/'zh'). So: try the exact requested
    # tag first (this is what makes pt-br/zh-tw work correctly on their own
    # file), and only degrade to the base language / 'en' if that exact file
    # doesn't exist - instead of dying outright for any tag that happens not
    # to have its own file.
	my @lang_candidates = ( $lang );
	if ( $lang =~ /^([a-zA-Z]+)[-_]/ ) {
		my $base = lc($1);
		push @lang_candidates, $base unless lc($lang) eq $base;
	}
	push @lang_candidates, 'en' unless grep {
		lc($_) eq 'en'
	}
	@lang_candidates;
	my ( $navdb, $navinfo );
	my @tried;
	for my $candidate (@lang_candidates) {
		my $try_navinfo = NAVIGATIONDIR . "/navigation.$candidate";
		push @tried, $try_navinfo;
		next unless -e $try_navinfo;
		$navdb = esmith::NavigationDB->open_ro( $try_navinfo );
		if ($navdb) {
			$navinfo = $try_navinfo;
			last;
		}
	}
	die "Couldn't open any navigation database for language '$lang' (tried: " . join( ', ', @tried ) . ")\n" unless $navdb;
	# no UTF8
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
			# By default, deny access if no allowed_admin_panels are specified
			my $has_access = 0;
			if (@allowed_admin_panels) {
				my $file_no_ext = $file;
				$file_no_ext =~ s/\.pm$//;  # Remove .pm extension if present
				foreach my $allowed_panel (@allowed_admin_panels) {
					if ($file_no_ext eq lc($allowed_panel)) {
						$has_access = 1;
						last;
					}
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
    #die(Dumper(\%nav));
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
	# This progmram uses the URL of the request (route) to derive the module that is being called
	# in order that the context for I18N lexical translation can occur, however some routes are for images etc, and one or two routes 
	# are utility routes used to pass data to JS code in the client browser or extra special routes for templates to use.
	# Consequently we need to eliminate these and give it the initial module context.
	# It may be that an alternative way to derive the module using the module/route would get us to the proper module without 
	# the special cases.  This can be investigated later?

    my $c = shift;
	my $debug    = $c->config('debug');
    
    #$c->app->log->info("lang_space path=" . $c->req->url->path->to_string);

    my $path = $c->tx->req->url;
    if ( $path =~ m/\.css$|\.js$|\.jpg$|\.gif$|\.png$|\.ico$|\.map$/ ) {
		#warn "path not treated $path";
		return
    }

    # NOTE (fixed): the fallback here used to be the arrayref ['en_US']
    # instead of the plain string 'en_US'. When no Accept-Language header
    # is present at all, split(/,/, $lang) on an arrayref stringifies it to
    # "ARRAY(0x...)" (no commas to split on), which then gets used to build
    # a package name like "...::Initial::ARRAY(0x...)" - Perl's parser
    # chokes on the "(0x...)" trying to read it as a version number, dying
    # with "Invalid version format". This was always latent but only
    # started actually firing once i18ns() became unconditional (see fix
    # above) for requests with no Accept-Language header at all.
    my $lang = ( $c->tx->req->headers->accept_language || 'en_US' );
    $lang = (split(/,/, $lang))[0];
    $c->stash(locale=>$lang);  #Stash it for template use
    
    warn "LANG_DEBUG pid=$$ path=$path raw_header='" . ( $c->tx->req->headers->accept_language // '<none>' ) . "' parsed_lang='$lang'" if $debug;
    
    $path = 'initial' if ($path eq '/' or $path eq '' or $path eq 'get-locale'); 
    #warn "langspace:path=$path" if $debug;
    my ($module) = $path =~ m{\A([^/?]+)};
    $module = ucfirst($module);
    #warn "langspace:module=$module" if $debug;

    my $moduleLong = "SrvMngr::I18N::Modules::$module";
    (my $dir = $moduleLong) =~ s|::|/|g;
    my $I18Ndir = $c->app->home->rel_file('lib/') . '/' . $dir;

    ##$c->app->log->debug("$panel $module $moduleLong $I18Ndir");
    # If the plural-named legacy directory doesn't exist, see if a
    # singular-named legacy directory does (some older routes/modules used
    # a singular form there) and use that name instead - but ONLY when it
    # actually exists. If NEITHER exists, keep the original (plural,
    # route-derived) name: that's what the newer .po/.mo toolchain
    # (smeserver-manager-locale) keys its per-module directories by, so
    # falling back to a blindly-stripped name here would silently point
    # i18ns() at the wrong namespace for every module migrated to that tier.
    if ( ! -d $I18Ndir ) {
		( my $singularLong = $moduleLong) =~ s/.$//;
		( my $singularDir  = $I18Ndir)   =~ s/.$//;
		if ( -d $singularDir ) {
			$moduleLong = $singularLong;
			$I18Ndir    = $singularDir;
		}
    }
    ##    $c->app->log->debug("hook_b_r->panel route. lang: $lang  namespace: $moduleLong ldir; $I18Ndir");
    # Always attempt to switch the I18N namespace to this module, whether or
    # not the legacy per-module Perl-lexicon directory ($I18Ndir, computed
    # above) exists on disk. That directory only ever holds the OLD
    # locales2-conf-generated *.pm lexicons; modules migrated to the newer
    # .po/.mo toolchain (smeserver-manager-locale) no longer ship it at all.
    # Gating the i18ns() call on -d $I18Ndir silently skipped it entirely for
    # every migrated module - which meant not just that module's own strings,
    # but also the shared General-lexicon merge that i18namespace() performs
    # on every call, never happened either, so panels fell all the way back
    # to raw untranslated keys. i18namespace() -> _load_module() ->
    # _load_own_lexicon() already falls back to a harmless empty placeholder
    # when nothing at all is found for a given namespace+lang (the same
    # mechanism that already protects languages with no translations at
    # all - see the "symmetric fallback" fix in SrvMngr::Plugin::I18N), so
    # calling this unconditionally is safe for modules with no lexicon of
    # any kind, and now correctly picks up real content for modules whose
    # translations moved to the new tier.
    warn "NS already loaded: $moduleLong \n" if ( $c->i18ns() eq $moduleLong );		# i18ns changed
    $c->i18ns( $moduleLong, $lang );
    #Only do this once the localise functions are setup.
    $c->stash(pleasewait=>$c->l('Please_Wait')); #Used in JS
    #$c->app->log->info("Localised pleasewait: ".$c->stash('pleasewait'));

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

sub validate_NonEmptyString {
    my $c           = shift;
    my $description = shift;
    # first character needs to be a unicode 
    # other can be unicode or - ' ` . , or space
    return ($description =~ /^([\w][\-\'\`,\w\s\.]*)$/u)
        ? 'OK'
        : 'STRING_VALIDATION';
} 

#sub validate_Phone {
    #my $c           = shift;
    #my $description = shift;
    ## Regex breakdown:
    ## ^                                -> Start of string
    ## (?:                              -> Start of Main Phone Group
    ##   (?:\+?1[-. ]?)?                -> Optional country code (+1 or 1)
    ##   (?:(?:\(([0-9]{3})\)|([0-9]{3}))[-. ]?)? -> OPTIONAL 3-digit area code (with or without parentheses)
    ##   ([0-9]{3})[-. ]?([0-9]{4})     -> Required 3-digit exchange + 4-digit line number
    ##   (?:(?:,\s*|[ ]+|ext\.?|x)([0-9]{2,5}))?  -> Optional 2 to 5 digit extension ($5)
    ## )                                -> End of Main Phone Group
    ## |                                -> OR alternative
    ## ^([0-9]{2,5})$                   -> Standalone 2 to 5 digit extension ($6)
    #my $phone_regex = qr/
        #^(?:
            #(?:\+?1[-. ]?)?
            #(?:(?:\(([0-9]{3})\)|([0-9]{3}))[-. ]?)?
            #([0-9]{3})[-. ]?([0-9]{4})
            #(?:(?:,\s*|[ ]+|ext\.?|x)([0-9]{2,5}))?
        #)$
        #|
        #^([0-9]{2,5})$
    #/xi;
    #return ($description =~ $phone_regex)
        #? 'OK'
        #: 'PHONE_VALIDATION';
#}

sub validate_Phone {
    my $c           = shift;
    my $description = shift;

    # International-friendly phone regex (not NANP-specific).
    # Regex breakdown:
    # ^                                     -> Start of string
    # (?:                                   -> Main phone group
    #   (?:\+|00[-. ]?)?                    -> Optional international prefix: + or 00
    #   \(?[0-9]{1,4}\)?                    -> First group: country/area code, 1-4 digits, optional parens
    #   (?:[-. ]?[0-9]){6,11}               -> Remaining 6-11 digits, each with an optional separator
    #                                          (total digits across the number: 7-15, per ITU-T E.164)
    #   (?:[\s,]+(?:ext\.?|x\.?)?[\s]*([0-9]{2,5}))?  -> Optional extension (comma/space/"ext"/"x" + 2-5 digits)
    # )                                     -> End of main phone group
    # |                                     -> OR
    # ^([0-9]{2,5})$                        -> Standalone 2-5 digit extension
    my $phone_regex = qr{
        ^(?:
            (?:\+|00[-. ]?)?
            \(?[0-9]{1,4}\)?
            (?:[-. ]?[0-9]){6,11}
            (?:[\s,]+(?:ext\.?|x\.?)?[\s]*([0-9]{2,5}))?
        )$
        |
        ^([0-9]{2,5})$
    }xi;

    return ($description =~ $phone_regex)
        ? 'OK'
        : 'PHONE_VALIDATION';
}


1;
