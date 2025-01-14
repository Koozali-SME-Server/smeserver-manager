package SrvMngr::Controller::Ibays;

#----------------------------------------------------------------------
# heading     : Network
# description : Shared areas (was ibays)
# navigation  : 6000 100
#
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw( theme_list init_session is_normal_password );
use esmith::AccountsDB;
use esmith::ConfigDB;
use esmith::DomainsDB;

#use esmith::FormMagick::Panel::ibays;
our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";
our $cdb = esmith::ConfigDB->open() || die "Couldn't open config db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %iba_datas = ();
    my $title     = $c->l('iba_FORM_TITLE');
    $iba_datas{'trt'} = 'LIST';
    my @ibays;

    if ($adb) {
        @ibays = $adb->ibays();
    }
    $c->stash(title => $title, iba_datas => \%iba_datas, ibays => \@ibays);
    $c->render(template => 'ibays');
} ## end sub main

sub do_display {
    my $c    = shift;
    my $rt   = $c->current_route;
    my $trt  = ($c->param('trt') || 'LIST');
    my $ibay = $c->param('ibay') || '';

    #$trt = 'DEL' if ( $ibay );
    #$trt = 'ADD' if ( $rt eq 'ibayadd' );
    my %iba_datas = ();
    my $title     = $c->l('iba_FORM_TITLE');
    my $modul     = '';
    $iba_datas{'trt'} = $trt;

    if ($trt eq 'ADD') {
        $iba_datas{ibay}         = '';
        $iba_datas{description}  = '';
        $iba_datas{group}        = '';
        $iba_datas{userAccess}   = '';
        $iba_datas{publicAccess} = '';
        $iba_datas{CgiBin}       = '';
        $iba_datas{SSL}          = '';
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD') {
        my $rec = $adb->get($ibay);

        if ($rec and $rec->prop('type') eq 'ibay') {
            $iba_datas{ibay}         = $ibay;
            $iba_datas{description}  = $rec->prop('Name') || '';
            $iba_datas{group}        = $rec->prop('Group') || '';
            $iba_datas{userAccess}   = $rec->prop('UserAccess') || '';
            $iba_datas{publicAccess} = $rec->prop('PublicAccess') || '';
            $iba_datas{CgiBin}       = $rec->prop('CgiBin') || 'disabled';
            $iba_datas{SSL}          = $rec->prop('SSL') || 'disabled';
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'DEL') {
        my $rec = $adb->get($ibay);

        if ($rec and $rec->prop('type') eq 'ibay') {
            $iba_datas{ibay} = $ibay;
            $iba_datas{description} = $rec->prop('Name') || '';
            $modul .= print_vhost_message($c, $ibay);
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'PWD') {
        my $rec = $adb->get($ibay);

        if ($rec and $rec->prop('type') eq 'ibay') {
            $iba_datas{ibay} = $ibay;
            $iba_datas{description} = $rec->prop('Name') || '';
        }
    } ## end if ($trt eq 'PWD')

    if ($trt eq 'LIST') {
        my @ibays;
        $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";

        if ($adb) {
            @ibays = $adb->ibays();
        }
        $c->stash(ibays => \@ibays);
    } ## end if ($trt eq 'LIST')
    $c->stash(title => $title, modul => $modul, iba_datas => \%iba_datas);
    $c->render(template => 'ibays');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LIST');
    my %iba_datas = ();
    my $title     = $c->l('iba_FORM_TITLE');
    $iba_datas{'trt'} = $trt;
    my $result = '';
    my $res;

    if ($trt eq 'ADD') {
        my $name = ($c->param('ibay') || '');

        # controls
        $res = validate_ibay($c, $name);
        $result .= $res unless $res eq 'OK';

        if (!$result) {
            $res = create_ibay($c, $name);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('iba_SUCCESSFULLY_CREATED_IBAY') . ' ' . $name;
                $iba_datas{trt} = 'LST';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD') {
        my $name = ($c->param('ibay') || '');

        # controls
        $res = '';

        if (!$result) {
            $res = modify_ibay($c, $name);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('iba_SUCCESSFULLY_MODIFIED_IBAY') . ' ' . $name;
                $iba_datas{trt} = 'LST';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'PWD') {
        my $ibay  = ($c->param('ibay')          || '');
        my $pass1 = ($c->param('newPass')       || '');
        my $pass2 = ($c->param('newPassVerify') || '');

        # controls
        unless ($pass1 eq $pass2) {
            $result .= $c->l('iba_IBAY_PASSWD_VERIFY_ERROR') . ' - ';
        }
        $res = check_password($c, $pass1);
        $result .= $res unless $res eq 'OK';

        if (!$result) {
            $res = reset_password($c, $ibay, $pass1);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('iba_SUCCESSFULLY_RESET_PASSWORD') . ' ' . $ibay;
                $iba_datas{trt} = 'LST';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'PWD')

    if ($trt eq 'DEL') {
        my $ibay = $c->param('ibay');

        if ($ibay =~ /^([a-z][a-z0-9]*)$/) {
            $ibay = $1;
        } else {
            $result .= $c->l('iba_ERR_INTERNAL_FAILURE') . ':' . $ibay;
        }

        if (!$result) {
            $res = remove_ibay($c, $ibay);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('iba_SUCCESSFULLY_DELETED_IBAY') . ' ' . $ibay;
                $iba_datas{trt} = 'LST';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'DEL')

    # common parts
    if ($res ne 'OK') {
        $c->stash(error => $result);
        $c->stash(title => $title, iba_datas => \%iba_datas);
        return $c->render('ibays');
    }
    my $message = "'Ibays' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('/ibays');
} ## end sub do_update

sub validate_ibay {
    my ($c, $name) = @_;
    my $msg = validate_name($c, $name);

    unless ($msg eq "OK") {
        return ($msg);
    }
    $msg = max_ibay_name_length($c, $name);

    unless ($msg eq "OK") {
        return ($msg);
    }
    $msg = conflict_check($c, $name);

    unless ($msg eq "OK") {
        return ($msg);
    }
    return ('OK');
} ## end sub validate_ibay

sub create_ibay {
    my ($c, $name) = @_;
    my $msg;
    my $uid = $adb->get_next_uid();

    if (my $acct = $adb->new_record(
            $name,
            {   Name         => $c->param('ibayDesc'),
                CgiBin       => $c->param('CgiBin'),
                Group        => $c->param('group'),
                PublicAccess => $c->param('publicAccess'),
                SSL          => $c->param('SSL'),
                UserAccess   => $c->param('userAccess'),
                Uid          => $uid,
                Gid          => $uid,
                PasswordSet  => 'no',
                type         => 'ibay',
            }
        )
        )
    {
        # Untaint $name before use in system()
        $name =~ /(.+)/;
        $name = $1;

        if (system("/sbin/e-smith/signal-event", "ibay-create", $name) == 0) {
            $msg = 'OK';
        } else {
            $msg = $c->l('iba_ERROR_WHILE_CREATING_IBAY');
        }
    } else {
        $msg = $c->l('iba_CANT_CREATE_IBAY');
    }
    return $msg;
} ## end sub create_ibay

sub modify_ibay {
    my ($c, $name) = @_;
    my $msg;

    if (my $acct = $adb->get($name)) {
        if ($acct->prop('type') eq 'ibay') {
            $acct->merge_props(
                Name         => $c->param('ibayDesc'),
                CgiBin       => $c->param('CgiBin'),
                Group        => $c->param('group'),
                PublicAccess => $c->param('publicAccess'),
                SSL          => $c->param('SSL'),
                UserAccess   => $c->param('userAccess'),
            );

            # Untaint $name before use in system()
            $name =~ /(.+)/;
            $name = $1;

            if (system("/sbin/e-smith/signal-event", "ibay-modify", $name) == 0) {
                $msg = 'OK';
            } else {
                $msg = $c->l('iba_ERROR_WHILE_MODIFYING_IBAY');
            }
        } else {
            $msg = $c->l('iba_CANT_FIND_IBAY');
        }
    } else {
        $msg = $c->l('iba_CANT_FIND_IBAY');
    }
    return $msg;
} ## end sub modify_ibay

sub print_vhost_message {
    my $c              = shift;
    my $name           = $c->param('ibay');
    my $result         = '';
    my $domaindb       = esmith::DomainsDB->open();
    my @domains        = $domaindb->get_all_by_prop(Content => $name);
    my $vhostListItems = join "\n", (map ($_->key . " " . $_->prop('Description'), @domains));

    if ($vhostListItems) {
        $result = $c->l('iba_VHOST_MESSAGE') . "<br><ul>";

        foreach ($vhostListItems) {
            $result .= "<li> $_ </li>";
        }
        $result .= '</ul>';
    } ## end if ($vhostListItems)
    return $result;
} ## end sub print_vhost_message

sub remove_ibay {
    my ($c, $name) = @_;
    my $msg = '';

    if (my $acct = $adb->get($name)) {
        if ($acct->prop('type') eq 'ibay') {
            $acct->set_prop('type', 'ibay-deleted');
            my $domains_db = esmith::DomainsDB->open();
            my @domains = $domains_db->get_all_by_prop(Content => $name);

            foreach my $d (@domains) {
                $d->set_prop(Content => 'Primary');
            }

            # Untaint $name before use in system()
            $name =~ /(.+)/;
            $name = $1;

            if (system("/sbin/e-smith/signal-event", "ibay-delete", $name) == 0) {
                $msg = 'OK';
                $acct->delete();
            } else {
                $msg = $c->l('iba_ERROR_WHILE_DELETING_IBAY');
            }
        } else {
            $msg = $c->l('iba_CANT_FIND_IBAY');
        }
    } else {
        $msg = $c->l('iba_CANT_FIND_IBAY');
    }
    return $msg;
} ## end sub remove_ibay

sub reset_password {
    my ($c, $name, $newPass) = @_;
    my ($msg, $acct);

    if (($acct = $adb->get($name)) && ($acct->prop('type') eq 'ibay')) {
        esmith::util::setIbayPassword($acct->key, $newPass);
        $acct->set_prop('PasswordSet', 'yes');

        # Untaint $name before use in system()
        $name =~ /(.+)/;
        $name = $1;

        if (system("/sbin/e-smith/signal-event", "password-modify", $name) == 0) {
            $msg = 'OK';
        } else {
            $msg = $c->l('iba_ERROR_WHILE_RESETTING_PASSWORD');
        }
    } else {
        $msg = $c->l('iba_CANT_FIND_IBAY');
    }
    return $msg;
} ## end sub reset_password

sub check_password {
    my ($c, $password) = @_;
    my $strength;
    my $rec = $cdb->get('passwordstrength');
    $strength = ($rec ? ($rec->prop('Ibays') || 'none') : 'none');
    return validate_password($c, $strength, $password);
} ## end sub check_password

sub validate_password {
    my ($c, $strength, $pass) = @_;
    use Crypt::Cracklib;
    my $reason;

    if ($strength eq "none") {
        return $c->l("Passwords must be at least 7 characters long") unless (length($pass) > 6);
        return "OK";
    }
    $reason = is_normal_password($c, $pass, undef);
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

=head2 group_list()

Returns a hash of groups for the Create/Modify screen's group field's
drop down list.

=cut

sub group_list_m {
    my @groups = $adb->groups();
    my @grps = ([ 'Admin' => 'admin' ], [ 'Everyone' => 'shared' ]);

    foreach my $g (@groups) {
        push @grps, [ $g->prop('Description') . " (" . $g->key . ")", $g->key() ];
    }
    return \@grps;
} ## end sub group_list_m

=head2 userAccess_list

Returns the hash of user access settings for showing in the user access
drop down list.

=cut

sub userAccess_list_m {
    my $c = shift;
    return [
        [ $c->l('WARG') => 'wr-admin-rd-group' ],
        [ $c->l('WGRE') => 'wr-group-rd-everyone' ],
        [ $c->l('WGRG') => 'wr-group-rd-group' ]
    ];
} ## end sub userAccess_list_m

=head2 publicAccess_list

Returns the hash of public access settings for showing in the public
access drop down list.

=cut

sub publicAccess_list_m {
    my $c = shift;
    return [
        [ $c->l('NONE')                            => 'none' ],
        [ $c->l('LOCAL_NETWORK_NO_PASSWORD')       => 'local' ],
        [ $c->l('LOCAL_NETWORK_PASSWORD')          => 'local-pw' ],
        [ $c->l('ENTIRE_INTERNET_NO_PASSWORD')     => 'global' ],
        [ $c->l('ENTIRE_INTERNET_PASSWORD')        => 'global-pw' ],
        [ $c->l('ENTIRE_INTERNET_PASSWORD_REMOTE') => 'global-pw-remote' ]
    ];
} ## end sub publicAccess_list_m

sub max_ibay_name_length {
    my ($c, $data) = @_;
    $cdb->reload();
    my $max = $cdb->get('maxIbayNameLength')->value;

    if (length($data) <= $max) {
        return "OK";
    } else {
        return $c->l('iba_MAX_IBAY_NAME_LENGTH_ERROR', $data, $max, $max);

        #        {acctName => $data,
        #         maxIbayNameLength => $max,
        #         maxLength => $max});
    } ## end else [ if (length($data) <= $max)]
} ## end sub max_ibay_name_length

sub conflict_check {
    my ($c, $name) = @_;
    my $rec = $adb->get($name);
    my $type;

    if (defined $rec) {
        my $type = $rec->prop('type');

        if ($type eq "pseudonym") {
            my $acct      = $rec->prop("Account");
            my $acct_type = $adb->get($acct)->prop('type');
            return $c->l('iba_ACCT_CLASHES_WITH_PSEUDONYM', $name, $acct_type, $acct);
        } ## end if ($type eq "pseudonym")
    } elsif (defined getpwnam($name) || defined getgrnam($name)) {
        $type = 'system';
    } else {

        # No account record and no account
        return 'OK';
    }
    return $c->l('iba_ACCOUNT_EXISTS', $name, $type);
} ## end sub conflict_check

sub validate_name {
    my ($c, $acctName) = @_;

    unless ($acctName =~ /^([a-z][\_\.\-a-z0-9]*)$/) {
        return $c->l('iba_ACCT_NAME_HAS_INVALID_CHARS', $acctName);
    }
    return "OK";
} ## end sub validate_name
1
