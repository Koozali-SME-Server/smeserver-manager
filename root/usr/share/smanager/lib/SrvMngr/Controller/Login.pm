package SrvMngr::Controller::Login;

#----------------------------------------------------------------------
# heading     : Support
# description : Login
# navigation  : 0000 001
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

use Locale::gettext;

use esmith::AccountsDB;
use SrvMngr::I18N;
use SrvMngr::Model::Main;

use SrvMngr qw( theme_list init_session );

my $MAX_LOGIN_ATTEMPTS = 3;
my $DURATION_BLOCKED = 30 * 60;		# access blocked for 30 min
my $TIMEOUT_FAILED_LOGIN = 1;
my $RESET_DURATION = 2 * 60 * 60;  # 2 hours for resetting

our $adb = esmith::AccountsDB->open() or die "Couldn't open DB Accounts\n";

my $allowed_user_re = qr/^\w{5,10}$/;
my %Login_Attempts;


sub main {

  my $c = shift;
  $c->stash( trt => 'NORM' );
  $c->render('login');

}


sub login {

  my $c = shift;

  my $trt  = $c->param('Trt');

    # password reset request
  if ( $trt eq 'RESET' ) {
    my $res = $c->mail_rescue();
    if ( $res ne 'OK' ) {
      $c->stash( error => $res, trt => $trt );
      return $c->render('login');
    }
    $c->flash( success => $c->l('use_RESET_REGISTERED') );
    record_login_attempt($c, 'RESET');
    return $c->redirect_to( $c->home_page );
  }

    # normal loggin
  my $name = $c->param('Username');
  my $pass = $c->param('Password');
  my $from = $c->param('From');

  if ( is_denied($c) ) {
	$c->stash( error => $c->l('use_TOO_MANY_LOGIN'), trt => 'NORM'  );
	return $c->render('login');
  }

#	untaint
  unless ( ($name =~ /^([a-z][\-\_\.a-z0-9]*)$/) && ($pass =~ /^([ -~]+)$/) ) {
	record_login_attempt($c, 'FAILED');
	$c->stash( error => $c->l('use_INVALID_DATA'), trt => 'NORM'  );
	return $c->render('login');
  }

  my $alias = SrvMngr::Model::Main->check_adminalias( $c );
  if ( $alias ) {
    if ( $name eq $alias ) {
	$name = 'admin';
    } elsif ( $name eq 'admin' ) {
	record_login_attempt($c, 'FAILED');
	$c->stash( error => $c->l('use_SORRY'), trt => 'NORM'  );
	return $c->render('login');
    }
  }

  if (SrvMngr::Model::Main->check_credentials($name, $pass)) {
    $c->session(logged_in => 1);             # set the logged_in flag
    $c->session(username => $name);      # keep a copy of the username
#    if ( $name eq 'admin' || $adb->is_user_in_group($name, 'AdmiN') )  # for futur use
    if ( $name eq 'admin' ) {
	$c->session(is_admin => 1);
    } else {
	$c->session(is_admin => 0);
    }
    $c->session(expiration => 600);          # expire this session in 10 minutes

    $c->flash( success =>  $c->l('use_WELCOME') );
    record_login_attempt($c, 'SUCCESS');
  } else {
    record_login_attempt($c, 'FAILED');
    sleep $TIMEOUT_FAILED_LOGIN;

    $c->stash( error => $c->l('use_SORRY'), trt => 'NORM'  );
    return $c->render('login');
  }

  $from = $c->home_page if ( $from eq 'login' );
  $c->redirect_to( $from );

}


sub pwdrescue {

  my $c = shift;

  $c->stash( trt => 'RESET' );

  $c->render('login');

}


sub mail_rescue {

  my $c = shift;
  my $name = $c->param('Username');
  my $from = $c->param('From');

  my $res;

  $res .= $c->l('use_TOO_MANY_LOGIN') if ( is_denied($c) );

#	untaint
  if ( ! $res &&  $name !~ /^([a-z][\-\_\.a-z0-9]*)$/ )  {
	record_login_attempt($c, 'FAILED');
	$res .= $c->l('use_ERR_NAME');
  }

  if ( ! $res && $name eq 'admin' )  {
	$res .= $c->l('use_NOT_THAT_OPER');
  }

# user exists ?
    if ( ! $res ) {
	my $acct = $adb->get($name);
	if ( ! $acct || $acct->prop('type') ne "user" || $acct->prop('PasswordSet') ne 'yes' ) {
	    $res .= $c->l('use_NOT_THAT_OPER');
	}
    }

    return $res if $res;

# send email
    my $email = $name .'@'. $c->session->{DomainName};
    my $until = time() + $RESET_DURATION;

  $c->pwdrst->{$name} = {
    email  => $email,
    date   => $until,
    confirmed => 0,
  };
  my $jwt = $c->jwt->claims({username => $name})->encode;
  my $url = $c->url_for('loginc')->to_abs->query(jwt => $jwt);

#  $c->email( $email, $c->l('use_CONFIRM_RESET'), $c->render_to_string(inline => $c->l('use_GO_TO_URL', $url) ) );
#  directly (without minion)
  $c->send_email( $email, $c->l('use_CONFIRM_RESET'), $c->render_to_string(inline => $c->l('use_GO_TO_URL', $url) ) );

  return 'OK';

}


sub logout {

  my $c = shift;
  $c->app->log->info($c->log_req);

  $c->session( expires => 1 );
  $c->flash( success => $c->l('use_BYE') );
  $c->flash( error => 'Byegood' );

  $c->redirect_to( $c->home_page );

}


sub confpwd {

  my $c = shift;

  my $jwt = $c->param('jwt');
  my $name = $c->jwt->decode($jwt)->{username};

    # request already treated or outdated
  if ( $c->pwdrst->{$name}{confirmed} != 0 or $c->pwdrst->{$name}{date} < time() ) {
	$c->flash( error => $c->l('use_INVALID_REQUEST'));
	return $c->redirect_to( $c->home_page );
  }

    # reset password for this account
  $c->pwdrst->{$name}{confirmed} = 1;

  $c->flash( success => $c->l('use_OK_FOR_RESET') );

    # call userpassword with encoded name
  my $url = $c->url_for('userpasswordr')->to_abs->query(jwt => $jwt);
    # warn "confpwd: " . $url . "\n";

  return $c->redirect_to( $url );

}


sub record_login_attempt {

  my ($c, $result) = @_;

  my $user = $c->param('Username');
  my $ip_address = $c->tx->remote_address;

  if ($result eq 'RESET') {

    $c->app->log->info(join "\t", "Password reset requested for : $user at ", $ip_address);

  } elsif ($result eq 'SUCCESS') {

    $c->app->log->info(join "\t", "Login succeeded: $user", $ip_address);
    $Login_Attempts{$ip_address}->{tries} = 0;	# reset the number of login attempts

  } else {

    $c->app->log->info(join "\t", "Login FAILED: $user", $ip_address);
    $Login_Attempts{$ip_address}->{tries}++;
    if ( $Login_Attempts{$ip_address}->{tries} > $MAX_LOGIN_ATTEMPTS ) {
      $Login_Attempts{$ip_address}->{denied_until} = time() + $DURATION_BLOCKED;
    }
  }
}


sub is_denied {
  my ($c) = @_;

  my $ip_address = $c->tx->remote_address;

  return unless exists $Login_Attempts{$ip_address}
        && exists $Login_Attempts{$ip_address}->{denied_until};

  return 'Denied'
    if $Login_Attempts{$ip_address}->{denied_until} > time();

  # TIMEOUT has expired, reset attempts
  delete $Login_Attempts{$ip_address}->{denied_until};
  $Login_Attempts{$ip_address}->{tries} = 0;

  return;
}


1;
