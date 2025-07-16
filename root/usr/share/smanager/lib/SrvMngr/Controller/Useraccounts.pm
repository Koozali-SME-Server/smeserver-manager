package SrvMngr::Controller::Useraccounts;

#----------------------------------------------------------------------
# heading     : User management
# description : Users
# navigation  : 2000 100
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session
    validate_password email_simple);
use esmith::AccountsDB::UTF8;
use esmith::ConfigDB::UTF8;
use esmith::util;

#use File::Basename;
#use Exporter;
#use Carp qw(verbose);
my ($cdb,$adb);

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
	$cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
	$adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    my $notif     = '';
    my %usr_datas = ();
    my $title     = $c->l('usr_FORM_TITLE');
    $usr_datas{'trt'} = 'LIST';
    my @users = $adb->get('admin');
    push @users, $adb->users();
    $c->stash(title => $title, notif => $notif, usr_datas => \%usr_datas, users => \@users);
    $c->render(template => 'useraccounts');
} ## end sub main

sub do_display {
    my $c         = shift;
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'ADD');
    my $user      = ($c->param('user') || '');
    my %usr_datas = ();
    my $title     = $c->l('usr_FORM_TITLE');
    my ($notif, $modul) = '';
	$cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
	$adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $usr_datas{'trt'} = $trt;

    if ($trt eq 'ADD') {
        $usr_datas{user}      = '';
        $usr_datas{firstname} = '';
        $usr_datas{lastname}  = '';
        $usr_datas{dept}      = $c->get_ldap_value('Dept');
        $usr_datas{company}   = $c->get_ldap_value('Company');
        $usr_datas{street}    = $c->get_ldap_value('Street');
        $usr_datas{city}      = $c->get_ldap_value('City');
        $usr_datas{phone}     = $c->get_ldap_value('Phone');
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD' or $trt eq 'UPS') {
        my $rec = $adb->get($user);
        my $type = ($trt eq 'UPS') ? 'system' : 'user';

        if ($rec and $rec->prop('type') eq $type) {
            $usr_datas{user}            = $user;
            $usr_datas{firstname}       = $rec->prop('FirstName');
            $usr_datas{lastname}        = $rec->prop('LastName');
            $usr_datas{vpnclientaccess} = $rec->prop('VPNClientAccess');
            $usr_datas{emailforward}    = $rec->prop('EmailForward');
            $usr_datas{forwardaddress}  = $rec->prop('ForwardAddress');

            if ($trt eq 'UPD') {
                $usr_datas{dept}    = $rec->prop('Dept');
                $usr_datas{company} = $rec->prop('Company');
                $usr_datas{street}  = $rec->prop('Street');
                $usr_datas{city}    = $rec->prop('City');
                $usr_datas{phone}   = $rec->prop('Phone');
            } ## end if ($trt eq 'UPD')
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'UPD' or $trt...)

    if ($trt eq 'DEL') {
        my $rec = $adb->get($user);

        if ($rec and $rec->prop('type') eq 'user') {
            $usr_datas{user} = $user;
            $usr_datas{name} = $c->get_user_name($user);
        }
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'PWD' or $trt eq 'PWS') {
        my $rec = $adb->get($user);
        my $type = ($trt eq 'PWS') ? 'system' : 'user';

        if ($rec and $rec->prop('type') eq $type) {
            $usr_datas{user} = $user;
            $usr_datas{name} = $c->get_user_name($user);
        }
    } ## end if ($trt eq 'PWD' or $trt...)

    if ($trt eq 'LCK') {
        my $rec = $adb->get($user);

        if ($rec and $rec->prop('type') eq 'user') {
            $usr_datas{user} = $user;
            $usr_datas{name} = $c->get_user_name($user);
        }
    } ## end if ($trt eq 'LCK')

    if ($trt eq 'LIST') {
        my @useraccounts;

        if ($adb) {
            @useraccounts = $adb->useraccounts();
        }
        $c->stash(useraccounts => \@useraccounts);
    } ## end if ($trt eq 'LIST')
    $c->stash(title => $title, notif => $notif, usr_datas => \%usr_datas);
    $c->render(template => 'useraccounts');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LIST');
    my $user      = ($c->param('user') || '');
    my $name      = ($c->param('name') || '');
    my %usr_datas = ();
    $usr_datas{trt} = $trt;
    my $title = $c->l('usr_FORM_TITLE');
    my ($res, $result) = '';
	$cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
	$adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";

    if ($trt eq 'ADD') {

        # controls
        my $first = $c->param('FirstName');
        my $last  = $c->param('LastName');
        my $mail  = $c->param('ForwardAddress');

        unless ($first) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        unless ($last) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        #unless ( $mail ) {
        #    $result .= $c->l('FM_NONBLANK') . ' - ';
        #}
        $res = $c->validate_acctName($user);
        $result .= $res unless $res eq 'OK';
        $res = $c->validate_acctName_length($user);
        $result .= $res unless $res eq 'OK';
        $res = $c->validate_acctName_conflict($user);
        $result .= $res unless $res eq 'OK';
        $res = $c->pseudonym_clash($first);
        $result .= $res unless $res eq 'OK';

        if ($mail) {
            $res = $c->emailforward($mail);
            $result .= $res unless $res eq 'OK';
        }

        #$result .= 'Blocked for testing';
        if (!$result) {
            $res = create_user($c, $user);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_USER_CREATED') . ' ' . $user;
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD' or $trt eq 'UPS') {

        # controls
        my $first = $c->param('FirstName');
        my $last  = $c->param('LastName');
        my $mail  = $c->param('ForwardAddress');

        unless ($first) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        unless ($last) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        #unless ( $mail ) {
        #    $result .= $c->l('FM_NONBLANK') . ' - ';
        #}
        $res = $c->pseudonym_clash($first);
        $result .= $res unless $res eq 'OK';

        if ($mail) {
            $res = $c->emailforward($mail);
            $result .= $res unless $res eq 'OK';
        }

        #$result .= 'Blocked for testing';
        if (!$result) {

            if ($trt eq 'UPS') {
                $res = $c->modify_admin();
            } else {
                $res = $c->modify_user($user);
            }
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_USER_MODIFIED') . ' ' . $user;
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'UPD' or $trt...)

    if ($trt eq 'PWD') {
        my $pass1 = $c->param('newPass');
        my $pass2 = $c->param('newPassVerify');

        # controls
        unless ($pass1) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        unless ($pass1 eq $pass2) {
            $result .= $c->l('PASSWORD_VERIFY_ERROR') . ' - ';
        }

        if (!$result) {
            $res = check_password($c, $pass1);
            $result .= $res unless $res eq 'OK';
        }

        if ($user eq 'admin') {
            $result .= "System password  should not be reset here !";
        }

        #$result .= 'Blocked for testing';
        if (!$result) {
            my $res = $c->reset_password($user, $pass1);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_PASSWORD_CHANGE_SUCCEEDED', $user);
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'PWD')

    if ($trt eq 'PWS') {    # system password reset (admin)
        my $curpass = $c->param('CurPass');
        my $pass1   = $c->param('Pass');
        my $pass2   = $c->param('PassVerify');

        # controls
        if ($curpass) {
            $res = $c->system_authenticate_password($curpass);
            $result .= $res unless $res eq 'OK';
        } else {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        unless ($pass1 and $pass2) {
            $result .= $c->l('FM_NONBLANK') . ' - ';
        }

        unless ($pass1 eq $pass2) {
            $result .= $c->l('usr_SYSTEM_PASSWORD_VERIFY_ERROR') . ' - ';
        }

        if (!$result) {
            $res = $c->system_validate_password($pass1);
            $result .= $res unless $res eq 'OK';
            $res = $c->system_check_password($pass1);
            $result .= $res unless $res eq 'OK';
        } ## end if (!$result)

        #$result .= 'Blocked for testing';
        if (!$result) {
            my $res = $c->system_change_password();
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_SYSTEM_PASSWORD_CHANGED', $user);
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'PWS')

    if ($trt eq 'LCK') {

        # controls
        #$res = xxxxxxxxxxx();
        #$result .= $res unless $res eq 'OK';
        #$result .= 'Blocked for testing';
        if (!$result) {
            my $res = $c->lock_account($user);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_LOCKED_ACCOUNT', $user);
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'LCK')

    if ($trt eq 'DEL') {

        # controls
        #$res = xxxxxxxxxxx();
        #$result .= $res unless $res eq 'OK';
        #$result .= 'Blocked for testing';
        if (!$result) {
            my $res = $c->remove_account($user);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('usr_SUCCESSFULLY_DELETED_USER') . ' ' . $user;
                $usr_datas{trt} = 'SUC';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'DEL')
    $usr_datas{'user'} = $user;
    $usr_datas{'name'} = $name;
    $c->stash(title => $title, notif => $result, usr_datas => \%usr_datas);

    if ($usr_datas{trt} ne 'SUC') {
        return $c->render(template => 'useraccounts');
    }
    $c->redirect_to('/useraccounts');
} ## end sub do_update

sub lock_account {
    my $c    = shift;
    my $user = $c->param('user');
    my $acct = $adb->get($user);

    if ($acct->prop('type') eq "user") {
        undef $adb;

        # Untaint the username before use in system()
        $user =~ /^(\w[\-\w_\.]*)$/;
        $user = $1;

        if (system("/sbin/e-smith/signal-event", "user-lock", $user)) {
            $adb = esmith::AccountsDB::UTF8->open();
            return $c->l("usr_ERR_OCCURRED_LOCKING");
        }
        $adb = esmith::AccountsDB::UTF8->open();
        return 'OK';
    } else {
        return $c->l('usr_NO_SUCH_USER', $user);
    }
} ## end sub lock_account

sub remove_account {
    my ($c)  = @_;
    my $user = $c->param('user');
    my $acct = $adb->get($user);

    if ($acct->prop('type') eq 'user') {
        $acct->set_prop('type', 'user-deleted');
        undef $adb;

        # Untaint the username before use in system()
        $user =~ /^(\w[\-\w_\.]*)$/;
        $user = $1;

        if (system("/sbin/e-smith/signal-event", "user-delete", $user)) {
            $adb = esmith::AccountsDB::UTF8->open();
            return $c->l("usr_ERR_OCCURRED_DELETING");
        }
        $adb = esmith::AccountsDB::UTF8->open();
        $adb->get($user)->delete;
        return 'OK';
    } else {
        return $c->l('usr_NO_SUCH_USER', $user);
    }
} ## end sub remove_account

sub reset_password {
    my ($c, $user, $passw1) = @_;


    unless (($user) = ($user =~ /^(\w[\-\w_\.]*)$/)) {
        return $c->l('usr_TAINTED_USER');
    }
    $user = $1;
	my $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    my $acct = $adb->get($user);

    if ($acct->prop('type') eq "user") {
        esmith::util::setUserPassword($user, $passw1);
        $acct->set_prop("PasswordSet", "yes");
        undef $adb;

        if (system("/sbin/e-smith/signal-event", "password-modify", $user)) {
            $adb = esmith::AccountsDB::UTF8->open();
            return $c->l("usr_ERR_OCCURRED_MODIFYING_PASSWORD");
        }
        $adb = esmith::AccountsDB::UTF8->open();
        return 'OK';
    } else {
        return $c->l('usr_NO_SUCH_USER', $user);
    }
} ## end sub reset_password

sub check_password {
    my $c     = shift;
    my $pass1 = shift;
    my $check_type;
    my $rec = $cdb->get('passwordstrength');
    $check_type = ($rec ? ($rec->prop('Users') || 'none') : 'none');
    return validate_password($c, $check_type, $pass1);
} ## end sub check_password

sub emailForward_list {
    my $c = shift;
    return [
        [ $c->l('usr_DELIVER_EMAIL_LOCALLY') => 'local' ],
        [ $c->l('usr_FORWARD_EMAIL')         => 'forward' ],
        [ $c->l('usr_DELIVER_AND_FORWARD')   => 'both' ]
    ];
} ## end sub emailForward_list

sub max_user_name_length {
    my ($c, $data) = @_;
    $cdb->reload();
    my $max = $cdb->get('maxuserNameLength')->value;

    if (length($data) <= $max) {
        return "OK";
    } else {
        return $c->l('usr_MAX_user_NAME_LENGTH_ERROR', $data, $max, $max);
    }
} ## end sub max_user_name_length

sub validate_acctName {
    my ($c, $acctName) = @_;

    unless ($adb->validate_account_name($acctName)) {
        return $c->l('usr_ACCT_NAME_HAS_INVALID_CHARS', $acctName);
    }
    return "OK";
} ## end sub validate_acctName

sub validate_acctName_length {
    my $c                 = shift;
    my $acctName          = shift;
    my $maxAcctNameLength = ($cdb->get('maxAcctNameLength') ? $cdb->get('maxAcctNameLength')->prop('type') : "") || 12;

    if (length $acctName > $maxAcctNameLength) {
        return $c->l('usr_ACCOUNT_TOO_LONG', $maxAcctNameLength);
    } else {
        return ('OK');
    }
} ## end sub validate_acctName_length

sub validate_acctName_conflict {
    my $c        = shift;
    my $acctName = shift;
    my $account  = $adb->get($acctName);
    my $type;

    if (defined $account) {
        $type = $account->prop('type');
    } elsif (defined getpwnam($acctName) || defined getgrnam($acctName)) {
        $type = "system";
    } else {
        return ('OK');
    }
    return $c->l('usr_ACCOUNT_CONFLICT', $acctName, $type);
} ## end sub validate_acctName_conflict

sub get_user_name {
    my ($c, $acctName) = @_;
    my $usr = $adb->get($acctName);
    return '' unless $usr;
    return $usr->prop('FirstName') . " " . $usr->prop('LastName');
} ## end sub get_user_name

sub get_ldap_value {
    my ($c, $field) = @_;

    # don't do the lookup if this is a modification of an existing user
    if ($c->param('user')) {
        return $c->param($field);
    }
    my %CGIParam2DBfield = (
        Dept    => 'defaultDepartment',
        Company => 'defaultCompany',
        Street  => 'defaultStreet',
        City    => 'defaultCity',
        Phone   => 'defaultPhoneNumber'
    );
    return $cdb->get('ldap')->prop($CGIParam2DBfield{$field});
} ## end sub get_ldap_value

sub get_pptp_value {
    return $cdb->get('pptpd')->prop('AccessDefault') || 'no';
}

sub pseudonym_clash {
    my ($c, $first) = @_;
    $first ||= "";
    my $last     = $c->param('LastName') || "";
    my $acctName = $c->param('user')     || "";
    my $up       = "$first $last";
    $up =~ s/^\s+//;
    $up =~ s/\s+$//;
    $up =~ s/\s+/ /g;
    $up =~ s/\s/_/g;
    my $dp = $up;
    $dp =~ s/_/./g;
    $dp = $adb->get($dp);
    $up = $adb->get($up);
    my $da = $dp->prop('Account') if $dp;
    my $ua = $up->prop('Account') if $up;

    if ($dp and $da and $da ne $acctName) {
        return $c->l('usr_PSEUDONYM_CLASH', $acctName, $da, $dp->key);
    } elsif ($up and $ua and $ua ne $acctName) {
        return $c->l('usr_PSEUDONYM_CLASH', $acctName, $ua, $up->key);
    } else {
        return "OK";
    }
} ## end sub pseudonym_clash

sub emailforward {
    my ($c, $data) = @_;
    my $response = $c->email_simple($data);

    if ($response eq "OK") {
        return "OK";
    } elsif ($data eq "") {

        # Blank is ok, only if we're not forwarding, which means that the
        # EmailForward param must be set to 'local'.
        my $email_forward = $c->param('EmailForward') || '';
        $email_forward =~ s/^\s+|\s+$//g;
        return 'OK' if $email_forward eq 'local';
        return $c->l('usr_CANNOT_CONTAIN_WHITESPACE');
    } else {
        return $c->l('usr_CANNOT_CONTAIN_WHITESPACE')
            if ($data =~ /\s+/);

        # Permit a local address.
        return "OK" if $data =~ /^[a-zA-Z][a-zA-Z0-9\._\-]*$/;
        return $c->l('usr_UNACCEPTABLE_CHARS');
    } ## end else [ if ($response eq "OK")]
} ## end sub emailforward

sub get_groups {
    my ($c) = shift;
    my @groups = $adb->groups();
    return \@groups;
} ## end sub get_groups

sub ipsec_for_acct {
    my $c = shift;

    # Don't show ipsecrw setting unless the status property exists
    return '' unless ($cdb->get('ipsec')
        && $cdb->get('ipsec')->prop('RoadWarriorStatus'));

    # Don't show ipsecrw setting unless /sbin/e-smith/roadwarrior exists
    return '' unless -x '/sbin/e-smith/roadwarrior';
    my $user = $c->param('user');
    return '' unless $user;
    my $rec = $adb->get($user);

    if ($rec) {
        my $pwset     = $rec->prop('PasswordSet')     || 'no';
        my $VPNaccess = $rec->prop('VPNClientAccess') || 'no';

        if ($pwset eq 'yes' and $VPNaccess eq 'yes') {
            return 'OK';
        }
    } ## end if ($rec)
    return '';
} ## end sub ipsec_for_acct

sub is_user_in_group {
    my $c     = shift;
    my $user  = shift || '';
    my $group = shift || '';
    return '' unless ($user and $group);
    return ($adb->is_user_in_group($user, $group)) ? 'OK' : '';
} ## end sub is_user_in_group

sub get_ipsec_client_cert {
    my $c    = shift;
    my $user = $c->param('user');
    ($user) = ($user =~ /^(.*)$/);
    die "Invalid user: $user\n" unless getpwnam($user);
    open(KID, "/sbin/e-smith/roadwarrior get_client_cert $user |")
        or die "Can't fork: $!";
    my $certfile = <KID>;
    close KID;
    require File::Basename;
    my $certname = File::Basename::basename($certfile);
    print "Expires: 0\n";
    print "Content-type: application/x-pkcs12\n";
    print "Content-disposition: inline; filename=$certname\n";
    print "\n";
    open(CERT, "<$certfile");

    while (<CERT>) {
        print;
    }
    close CERT;
    return '';
} ## end sub get_ipsec_client_cert

sub modify_user {
    my ($c) = @_;
    my $acctName = $c->param('user');

    unless (($acctName) = ($acctName =~ /^(\w[\-\w_\.]*)$/)) {
        return $c->l('usr_TAINTED_USER', $acctName);
    }

    # Untaint the username before use in system()
    $acctName = $1;
    my $acct     = $adb->get($acctName);
    my $acctType = $acct->prop('type');

    if ($acctType eq "user") {
        $adb->remove_user_auto_pseudonyms($acctName);
        my %newProperties = (
            'FirstName'       => $c->param('FirstName'),
            'LastName'        => $c->param('LastName'),
            'Phone'           => $c->param('Phone'),
            'Company'         => $c->param('Company'),
            'Dept'            => $c->param('Dept'),
            'City'            => $c->param('City'),
            'Street'          => $c->param('Street'),
            'EmailForward'    => $c->param('EmailForward'),
            'ForwardAddress'  => $c->param('ForwardAddress'),
            'VPNClientAccess' => $c->param('VPNClientAccess'),
        );
        $acct->merge_props(%newProperties);
        $adb->create_user_auto_pseudonyms($acctName)
            if (($cdb->get_prop('pseudonyms', 'create') || 'enabled') eq 'enabled');
        my @old_groups = $adb->user_group_list($acctName);
        my @new_groups = @{ $c->every_param("groupMemberships") };

        #    $c->app->log->info($c->dumper("groups: Old " . @old_groups .' New '. @new_groups));
        $adb->remove_user_from_groups($acctName, @old_groups);
        $adb->add_user_to_groups($acctName, @new_groups);
        undef $adb;

        unless (system("/sbin/e-smith/signal-event", "user-modify", $acctName) == 0) {
            $adb = esmith::AccountsDB::UTF8->open();
            return $c->l('usr_CANNOT_MODIFY_USER');
        }
        $adb = esmith::AccountsDB::UTF8->open();
    } ## end if ($acctType eq "user")
    return 'OK';
} ## end sub modify_user

sub create_user {
    my $c        = shift;
    my $acctName = $c->param('user');
    my %userprops;

    foreach my $field (
        qw( FirstName LastName Phone Company Dept
        City Street EmailForward ForwardAddress VPNClientAccess)
        )
    {
        $userprops{$field} = $c->param($field);
    } ## end foreach my $field (qw( FirstName LastName Phone Company Dept...))
    $userprops{'PasswordSet'} = "no";
    $userprops{'type'}        = 'user';
    my $acct = $adb->new_record($acctName)
        or warn "Can't create new account for $acctName (does it already exist?)\n";
    $acct->reset_props(%userprops);
    $adb->create_user_auto_pseudonyms($acctName)
        if (($cdb->get_prop('pseudonyms', 'create') || 'enabled') eq 'enabled');
    my @groups = @{ $c->every_param("groupMemberships") };
    $adb->add_user_to_groups($acctName, @groups);
    undef $adb;

    # Untaint the username before use in system()
    $acctName =~ /^(\w[\-\w_\.]*)$/;
    $acctName = $1;

    if (system("/sbin/e-smith/signal-event", "user-create", $acctName)) {
        $adb = esmith::AccountsDB::UTF8->open();
        return $c->l("usr_ERR_OCCURRED_CREATING");
    }
    $adb = esmith::AccountsDB::UTF8->open();
    $c->set_groups();
    return 'OK';
} ## end sub create_user

sub set_groups {
    my $c        = shift;
    my $acctName = $c->param('user');
    my @groups   = @{ $c->every_param("groupMemberships") };
    $adb->set_user_groups($acctName, @groups);
} ## end sub set_groups

sub modify_admin {
    my ($c)           = @_;
    my $acct          = $adb->get('admin');
    my %newProperties = (
        'FirstName'       => $c->param('FirstName'),
        'LastName'        => $c->param('LastName'),
        'EmailForward'    => $c->param('EmailForward'),
        'ForwardAddress'  => $c->param('ForwardAddress'),
        'VPNClientAccess' => $c->param('VPNClientAccess'),
    );
    $acct->merge_props(%newProperties);
    undef $adb;
    my $status = system("/sbin/e-smith/signal-event", "user-modify-admin", 'admin');
    $adb = esmith::AccountsDB::UTF8->open();

    if ($status == 0) {
        return 'OK';
    } else {
        return $c->l('usr_CANNOT_MODIFY_USER', 'First');
    }
} ## end sub modify_admin

sub system_validate_password {
    my $c     = shift;
    my $pass1 = shift;

    # If the password contains one or more printable character
    if ($pass1 =~ /^([ -~]+)$/) {
        return ('OK');
    } else {
        return $c->l('usr_SYSTEM_PASSWORD_UNPRINTABLES_IN_PASS');
    }
} ## end sub system_validate_password

sub system_check_password {
    my $c     = shift;
    my $pass1 = shift;
    my $conf = esmith::ConfigDB::UTF8->open();
    my ($check_type, $rec);

    if ($conf) {
        $rec = $conf->get('passwordstrength');
    }
    $check_type = ($rec ? ($rec->prop('Admin') || 'strong') : 'strong');
    return $c->validate_password($check_type, $pass1);
} ## end sub system_check_password

sub system_authenticate_password {
    my $c    = shift;
    my $pass = shift;

    if (esmith::util::authenticateUnixPassword(
            ($cdb->get_value("AdminIsNotRoot") eq 'enabled') ? 'admin' : 'root', $pass
        )
        )
    {
        return "OK";
    } else {
        return $c->l("usr_SYSTEM_PASSWORD_AUTH_ERROR");
    }
} ## end sub system_authenticate_password

sub system_change_password {
    my ($c) = @_;
    my $pass = $c->param('Pass');
    ($cdb->get_value("AdminIsNotRoot") eq 'enabled')
        ? esmith::util::setUnixPassword('admin', $pass)
        : esmith::util::setUnixSystemPassword($pass);
    esmith::util::setServerSystemPassword($pass);
    my $result = system("/sbin/e-smith/signal-event password-modify admin");

    if ($result == 0) {
        return 'OK';
    } else {
        return $c->l("Error occurred while modifying password for admin.");
    }
} ## end sub system_change_password
1