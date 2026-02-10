package SrvMngr::Controller::Login;

#----------------------------------------------------------------------
# heading     : Support
# description : Login
# navigation  : 0 200
# menu        : N
#
# routes : end
#----------------------------------------------------------------------
# for information
#    $r->get('/login')->to('login#main')->name('login');
#    $r->post('/login')->to('login#login')->name('signin');
#    $r->get('/login2')->to('login#pwdrescue')->name('pwdresc');
#    $r->get('/loginc')->to('login#confpwd')->name('resetpwdconf');
# for information
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'url_unescape';
use Locale::gettext;
use esmith::AccountsDB::UTF8;
use SrvMngr::I18N;
use SrvMngr::Model::Main;
use SrvMngr qw( theme_list init_session );
use Apache::AuthTkt;
# Loading AuthTkt config
my $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");

my $MAX_LOGIN_ATTEMPTS   = 3;
my $DURATION_BLOCKED     = 30 * 60;        # access blocked for 30 min
my $TIMEOUT_FAILED_LOGIN = 1;
my $RESET_DURATION       = 2 * 60 * 60;    # 2 hours for resetting
our $adb;
my $allowed_user_re = qr/^\w{5,10}$/;
my %Login_Attempts;

sub main {
    my $c = shift;
    $c->stash(trt => 'NORM');
    my $name; 
    my $from = $c->param('From');
    $from = $c->home_page if ($from eq 'login');
    my $debug    = $c->param('debug');
    # ticket might have changed since smanager has started.
    $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");
    $c->log->debug($c->req->headers->to_string) if $debug;
    #  in Mojo request cookies are automatically parsed according to RFC 6265
    # done because = created by base64 encoding, and Mojo may interpret them as part of the structure rather than the data.
    #  it is standard practice to URL-encode special characters in cookie values, where = becomes %3D
    # this means that we need to url_unescape before validating or we will  fail
    my $ticket= url_unescape $c->cookie('auth_tkt');
    if ($ticket) {
        $c->log->debug("auth_tkt: $ticket") if $debug;
        # Check if the user is already "logged in" in the Mojo session
        unless ($c->session('username')) {
            # validate the auth_tkt (e.g., decrypt or DB lookup)
            my $valid_ticket = $at->validate_ticket($ticket, ip_addr =>'',ignore_ip => 1);
            if ($valid_ticket) {
                $name =  $valid_ticket->{uid};
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
                record_login_attempt($c, 'SUCCESS');
                # TODO should we register cookie failed login ????
            } else {use Data::Dumper;; $c->log->debug("Invalid ticket". Dumper($at->parse_ticket($ticket))) if $debug; }
       }
    } else {$c->log->debug("no auth_tkt found ???") if $debug; }
    
    # TODO here add a redirect to referer or initial if user logged in 

    $c->render('login');
} ## end sub main

sub login {
    my $c   = shift;
    my $trt = $c->param('Trt');
    $adb = esmith::AccountsDB::UTF8->open() or die "Couldn't open DB Accounts\n";

    # password reset request
    if ($trt eq 'RESET') {
        my $res = $c->mail_rescue();

        if ($res ne 'OK') {
            $c->stash(error => $res, trt => $trt);
            return $c->render('login');
        }
        $c->flash(success => $c->l('use_RESET_REGISTERED'));
        record_login_attempt($c, 'RESET');
        return $c->redirect_to($c->home_page);
    } ## end if ($trt eq 'RESET')

    # normal loggin
    my $name = $c->param('Username');
    my $pass = $c->param('Password');
    my $from = $c->param('From');

    if (is_denied($c)) {
        $c->stash(error => $c->l('use_TOO_MANY_LOGIN'), trt => 'NORM');
        return $c->render('login');
    }

    #	untaint
    unless (($name =~ /^([a-z][\-\_\.a-z0-9]*)$/) && ($pass =~ /^([ -~]+)$/)) {
        record_login_attempt($c, 'FAILED');
        $c->stash(error => $c->l('use_INVALID_DATA'), trt => 'NORM');
        return $c->render('login');
    }
    my $alias = SrvMngr::Model::Main->check_adminalias($c);

    if ($alias) {
        if ($name eq $alias) {
            $name = 'admin';
        } elsif ($name eq 'admin') {
            record_login_attempt($c, 'FAILED');
            $c->stash(error => $c->l('use_SORRY'), trt => 'NORM');
            return $c->render('login');
        }
    } ## end if ($alias)

    # check authtkt
    # ticket might have changed since smanager has started.
    $at = Apache::AuthTkt->new(conf => "/etc/e-smith/web/common/cgi-bin/AuthTKT.cfg");
    my $server_name = $c->req->headers->header('X-Forwarded-Host');
    $server_name ||= $ENV{SERVER_NAME} if $ENV{SERVER_NAME};
    my $AUTH_DOMAIN = $server_name;
    my @auth_domain = $AUTH_DOMAIN && $AUTH_DOMAIN =~ /\./ ? ( domain => $AUTH_DOMAIN ) : ();
    my $ticket = $c->cookie('auth_tkt');
    my $probe = $c->cookie('auth_probe');
    my $back = $c->cookie($at->back_cookie_name) if $at->back_cookie_name;
    my $have_cookies = $ticket || $probe || $back || '';
    my $mode = 'login';
    # TODO add ip of the browser (not the proxy)
    my $ip_addr = undef;
    my $debug    = $c->param('debug');
    $debug = 3 if $debug;
    my @expires = $at->cookie_expires ? ( -expires => sprintf("+%ss", $at->cookie_expires) ) :  ();
   
    if (SrvMngr::Model::Main->check_credentials($name, $pass)) {
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
        record_login_attempt($c, 'SUCCESS');
        # set authtkt
        my $user_data = join(':', time(), $ip_addr || '');    # Optional
        my $tkt = $at->ticket(uid => $name, data => $user_data, ip_addr => $ip_addr, debug => $debug);
        $c->cookie(auth_tkt =>$tkt, {
            name => $at->cookie_name,
            path   => '/',
            secure => $at->require_ssl,
            @expires,
            @auth_domain,
        });
        $c->log->debug($c->req->headers->to_string) if $debug;
    } else {
        record_login_attempt($c, 'FAILED');
        sleep $TIMEOUT_FAILED_LOGIN;
        $c->stash(error => $c->l('use_SORRY'), trt => 'NORM');
        return $c->render('login');
    } ## end else [ if (SrvMngr::Model::Main...)]
    $from = $c->home_page if ($from eq 'login');
    $c->redirect_to($from);
} ## end sub login

sub pwdrescue {
    my $c = shift;
    $c->stash(trt => 'RESET');
    $c->render('login');
} ## end sub pwdrescue

sub mail_rescue {
    my $c    = shift;
    my $name = $c->param('Username');
    my $from = $c->param('From');
    $adb = esmith::AccountsDB::UTF8->open() or die "Couldn't open DB Accounts\n";
    my $res;
    $res .= $c->l('use_TOO_MANY_LOGIN') if (is_denied($c));

    #	untaint
    if (!$res && $name !~ /^([a-z][\-\_\.a-z0-9]*)$/) {
        record_login_attempt($c, 'FAILED');
        $res .= $c->l('use_ERR_NAME');
    }

    if (!$res && $name eq 'admin') {
        $res .= $c->l('use_NOT_THAT_OPER');
    }

    # user exists ?
    if (!$res) {
        my $acct = $adb->get($name);

        if (!$acct || $acct->prop('type') ne "user" || $acct->prop('PasswordSet') ne 'yes') {
            $res .= $c->l('use_NOT_THAT_OPER');
        }
    } ## end if (!$res)
    return $res if $res;

    # send email
    my $email = $name . '@' . $c->session->{DomainName};
    my $until = time() + $RESET_DURATION;
    $c->pwdrst->{$name} = {
        email     => $email,
        date      => $until,
        confirmed => 0,
    };
    my $jwt = $c->jwt->claims({ username => $name })->encode;
    my $url = $c->url_for('loginc')->to_abs->query(jwt => $jwt);

    #  $c->email( $email, $c->l('use_CONFIRM_RESET'), $c->render_to_string(inline => $c->l('use_GO_TO_URL', $url) ) );
    #  directly (without minion)
    $c->send_email($email, $c->l('use_CONFIRM_RESET'), $c->render_to_string(inline => $c->l('use_GO_TO_URL', $url)));
    return 'OK';
} ## end sub mail_rescue

## logout moved to Logout.pm

sub confpwd {
    my $c    = shift;
    my $jwt  = $c->param('jwt');
    my $name = $c->jwt->decode($jwt)->{username};

    # request already treated or outdated
    if ($c->pwdrst->{$name}{confirmed} != 0 or $c->pwdrst->{$name}{date} < time()) {
        $c->flash(error => $c->l('use_INVALID_REQUEST'));
        return $c->redirect_to($c->home_page);
    }

    # reset password for this account
    $c->pwdrst->{$name}{confirmed} = 1;
    $c->flash(success => $c->l('use_OK_FOR_RESET'));

    # call userpassword with encoded name
    my $url = $c->url_for('userpasswordr')->to_abs->query(jwt => $jwt);

    # warn "confpwd: " . $url . "\n";
    return $c->redirect_to($url);
} ## end sub confpwd

sub record_login_attempt {
    my ($c, $result) = @_;
    my $user       = $c->param('Username');
    my $ip_address = $c->tx->remote_address;

    if ($result eq 'RESET') {
        $c->app->log->info(join "\t", "Password reset requested for : $user at ", $ip_address);
    } elsif ($result eq 'SUCCESS') {
        $c->app->log->info(join "\t", "Login succeeded: $user", $ip_address);
        $Login_Attempts{$ip_address}->{tries} = 0;    # reset the number of login attempts
    } else {
        $c->app->log->info(join "\t", "Login FAILED: $user", $ip_address);
        $Login_Attempts{$ip_address}->{tries}++;

        if ($Login_Attempts{$ip_address}->{tries} > $MAX_LOGIN_ATTEMPTS) {
            $Login_Attempts{$ip_address}->{denied_until} = time() + $DURATION_BLOCKED;
        }
    } ## end else [ if ($result eq 'RESET')]
} ## end sub record_login_attempt

sub is_denied {
    my ($c) = @_;
    my $ip_address = $c->tx->remote_address;
    return
        unless exists $Login_Attempts{$ip_address}
        && exists $Login_Attempts{$ip_address}->{denied_until};
    return 'Denied'
        if $Login_Attempts{$ip_address}->{denied_until} > time();

    # TIMEOUT has expired, reset attempts
    delete $Login_Attempts{$ip_address}->{denied_until};
    $Login_Attempts{$ip_address}->{tries} = 0;
    return;
} ## end sub is_denied
1;
