package SrvMngr::Controller::Userpassword;

#----------------------------------------------------------------------
# heading     : Current User
# description : Change password
# navigation  : 1000 250
# menu        : U
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use esmith::util;
use esmith::ConfigDB;
use esmith::AccountsDB;
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw( theme_list init_session is_normal_password );
our $cdb = esmith::ConfigDB->open_ro || die "Couldn't open configuration db";

sub main {
    my $c         = shift;
    my %pwd_datas = ();

    if ($c->is_logged_in) {
        $pwd_datas{Account} = $c->session->{username};
        $pwd_datas{trt}     = 'NORM';
    } else {
        my $rt   = $c->current_route;
        my $mess = '';
        my $jwt  = $c->param('jwt') || '';
        my $name = $c->jwt->decode($jwt)->{username} || '';
        $mess = 'Invalid state' unless ($jwt and $name and $rt eq 'upwdreset');

        # request already treated or outdated
        if ($c->pwdrst->{$name}{confirmed} != 1 or $c->pwdrst->{$name}{date} < time()) {
            $mess = $c->l('use_INVALID_REQUEST') . ' -step 1-';
        }

        if ($mess) {
            $c->stash(error => $mess);
            return $c->redirect_to($c->home_page);
        }

        # ok for reset password for this account - step 2
        $c->pwdrst->{$name}{confirmed} = 2;
        $pwd_datas{Account}            = $name;
        $pwd_datas{trt}                = 'RESET';
        $pwd_datas{jwt}                = $jwt;
        $c->flash(success => $c->l('use_OK_FOR_RESET'));
    } ## end else [ if ($c->is_logged_in) ]
    $c->stash(pwd_datas => \%pwd_datas);
    $c->render('userpassword');
} ## end sub main

sub change_password {
    my $c = shift;
    my $result;
    my $res;
    my %pwd_datas  = ();
    my $trt        = $c->param('Trt');
    my $acctName   = $c->param('User');
    my $oldPass    = $c->param('Oldpass') || '';
    my $pass       = $c->param('Pass');
    my $passVerify = $c->param('Passverify');
    my $jwt        = $c->param('jwt') || '';
    my $rt         = $c->current_route;
    my $mess       = '';
    my $name       = '';
    $name = $c->jwt->decode($jwt)->{username} if $jwt;

    if ($trt eq 'RESET') {
        $mess = 'Invalid state' unless ($jwt and $name and ($rt eq 'upwdreset2'));

        # request already treated or outdated
        if ($c->pwdrst->{$name}{confirmed} != 2 or $c->pwdrst->{$name}{date} < time()) {
            $mess = $c->l('use_INVALID_REQUEST') . ' -step 2-';
        }

        if (!$name or $c->is_logged_in or $name ne $acctName) {
            $mess = 'Invalid reset state';
        }
    } else {

        if ($name or $jwt or !$c->is_logged_in) {
            $mess = 'Invalid update state';
        }
    } ## end else [ if ($trt eq 'RESET') ]

    if ($mess) {
        $c->stash(error => $mess);
        return $c->redirect_to($c->home_page);
    }
    $pwd_datas{Account} = $acctName;
    $pwd_datas{trt}     = $trt;

    # common controls
    if ($acctName eq 'admin') {
        $result .= "Admin password should not be reset here !";
    } else {

        unless ($pass && $passVerify) {
            $result .= $c->l('pwd_FIELDS_REQUIRED') . "<br>";
        } else {
            $result .= $c->l('pwd_PASSWORD_INVALID_CHARS') . "<br>" unless (($pass) = ($pass =~ /^([ -~]+)$/));
            $result .= $c->l('pwd_PASSWORD_VERIFY_ERROR') . "<br>" unless ($pass eq $passVerify);
        }
    } ## end else [ if ($acctName eq 'admin')]

    if ($result ne '') {
        $c->stash(error => $result, pwd_datas => \%pwd_datas);
        return $c->render('userpassword');
    }

    # validate new password
    $res = $c->check_password($pass);
    $result .= $res . "<br>" unless ($res eq 'OK');

    #  controls old password
    if ($trt ne 'RESET') {

        unless ($oldPass) {
            $result .= $c->l('pwd_FIELDS_REQUIRED') . "<br>" unless $trt eq 'RESET';
        } else {
            $result .= $c->l('pwd_PASSWORD_OLD_INVALID_CHARS') . "<br>" unless (($oldPass) = ($oldPass =~ /^(\S+)$/));
        }

        if ($result ne '') {
            $c->stash(error => $result, pwd_datas => \%pwd_datas);
            return $c->render('userpassword');
        }

        # verify old password
        if ($trt ne 'RESET') {
            $result .= $c->l('pwd_ERROR_PASSWORD_CHANGE') . "<br>"
                unless (SrvMngr::Model::Main->check_credentials($acctName, $oldPass));
        }
    } ## end if ($trt ne 'RESET')

    # $result .= 'Blocked for test (prevents updates)<br>';
    if (!$result) {
        my $res = $c->reset_password($trt, $acctName, $pass, $oldPass);
        $result .= $res unless $res eq 'OK';
    }

    if ($result) {
        record_password_change_attempt($c, 'FAILED');
        $c->stash(error => $result, pwd_datas => \%pwd_datas);
        return $c->render('userpassword');
    } ## end if ($result)
    $c->pwdrst->{$name}{confirmed} = 9 if $trt eq 'RESET';
    record_password_change_attempt($c, 'SUCCESS');
    $result .= $c->l('pwd_PASSWORD_CHANGE_SUCCESS');
    $c->flash(success => $result);
    $c->redirect_to($c->home_page);
} ## end sub change_password

sub reset_password {
    my ($c, $trt, $user, $password, $oldpassword) = @_;
    my $ret;
    return $c->l('usr_TAINTED_USER') unless (($user) = ($user =~ /^(\w[\-\w_\.]*)$/));
    $user = $1;
    my $adb  = esmith::AccountsDB->open();
    my $acct = $adb->get($user);
    return $c->l('NO_SUCH_USER', $user) unless ($acct->prop('type') eq 'user');
    $ret = esmith::util::setUserPasswordRequirePrevious($user, $oldpassword, $password) if $trt ne 'RESET';
    $ret = esmith::util::setUserPassword($user, $password) if $trt eq 'RESET';
    return $c->l('pwd_ERROR_PASSWORD_CHANGE') . ' ' . $trt unless $ret;
    $acct->set_prop("PasswordSet", "yes");
    undef $adb;

    if (system("/sbin/e-smith/signal-event", "password-modify", $user)) {
        $adb = esmith::AccountsDB->open();
        return $c->l("usr_ERR_OCCURRED_MODIFYING_PASSWORD");
    }
    $adb = esmith::AccountsDB->open();
    return 'OK';
} ## end sub reset_password

sub record_password_change_attempt {
    my ($c, $result) = @_;
    my $user       = $c->param('User');
    my $ip_address = $c->tx->remote_address;

    if ($result eq 'SUCCESS') {
        $c->app->log->info(join "\t", "Password change succeeded: $user", $ip_address);
    } else {
        $c->app->log->info(join "\t", "Password change FAILED: $user", $ip_address);
    }
} ## end sub record_password_change_attempt

sub check_password {
    my $c        = shift;
    my $password = shift;
    my $strength;
    my $rec = $cdb->get('passwordstrength');
    $strength = ($rec ? ($rec->prop('Users') || 'none') : 'none');
    return validate_password($c, $strength, $password);
} ## end sub check_password

sub validate_password {
    my ($c, $strength, $pass) = @_;
    use Crypt::Cracklib;

    if ($strength eq "none") {
        return $c->l("Passwords must be at least 7 characters long") unless (length($pass) > 6);
        return "OK";
    }
    my $reason = is_normal_password($c, $pass, undef);
    return $reason unless ($reason eq "OK");
    return "OK" unless ($strength eq "strong");

    if (-f '/usr/lib64/cracklib_dict.pwd') {
        $reason = fascist_check($pass, '/usr/lib64/cracklib_dict');
    } else {
        $reason = fascist_check($pass, '/usr/lib/cracklib_dict');
    }
    $reason ||= "Software error: password check failed";
    return "OK" if ($reason eq "ok");
    return
          $c->l("Bad Password Choice") . ": "
        . $c->l("The password you have chosen is not a good choice, because") . " "
        . $c->($reason) . ".";
} ## end sub validate_password
1;
