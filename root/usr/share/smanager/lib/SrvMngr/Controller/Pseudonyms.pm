package SrvMngr::Controller::Pseudonyms;

#----------------------------------------------------------------------
# heading     : User management
# description : Pseudonyms
# navigation  : 2000 210
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

#use Data::Dumper;
#use esmith::FormMagick::Panel::pseudonyms;
use esmith::AccountsDB;

#use URI::Escape;
our $cdb = esmith::ConfigDB->open   || die "Couldn't open configuration db";
our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %pse_datas = ();
    my $title     = $c->l('pse_FORM_TITLE');
    my $notif     = '';
    $pse_datas{trt} = 'LST';
    my @pseudonyms;

    if ($adb) {
        @pseudonyms = $adb->pseudonyms();
    }
    $c->stash(title => $title, notif => $notif, pse_datas => \%pse_datas, pseudonyms => \@pseudonyms);
    $c->render(template => 'pseudonyms');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LST');
    my $pseudonym = $c->param('pseudonym') || '';
    my $title     = $c->l('pse_FORM_TITLE');
    my %pse_datas = ();
    $pse_datas{'trt'} = $trt;

    if ($trt eq 'ADD') {

        #nothing
    }

    if ($trt eq 'UPD') {
        my $rec = $adb->get($pseudonym);

        if ($rec and $rec->prop('type') eq 'pseudonym') {
            $pse_datas{pseudonym} = $pseudonym;
            $pse_datas{account}   = $rec->prop('Account') || '';
            $pse_datas{internal}  = is_pseudonym_internal($pseudonym);
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'DEL') {
        my $rec = $adb->get($pseudonym);

        if ($rec and $rec->prop('type') eq 'pseudonym') {
            $pse_datas{pseudonym} = $pseudonym;
            $pse_datas{account}   = $rec->prop('Account') || '';
            $pse_datas{internal}  = is_pseudonym_internal($pseudonym);
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'LST') {
        my @pseudonyms;

        if ($adb) {
            @pseudonyms = $adb->pseudonyms();
        }
        $c->stash(pseudonyms => \@pseudonyms);
    } ## end if ($trt eq 'LST')
    $c->stash(title => $title, pse_datas => \%pse_datas);
    $c->render(template => 'pseudonyms');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LST');
    my $title     = $c->l('pse_FORM_TITLE');
    my %pse_datas = ();
    $pse_datas{'trt'} = $trt;
    my ($res, $result) = '';

    #my $pseudonym = uri_unescape($c->param('Pseudonym'));
    my $pseudonym = $c->param('Pseudonym');
    $pse_datas{'pseudonym'} = $pseudonym;

    if ($trt eq 'ADD') {
        my $account = $c->param('Account');

        # controls
        $res = $c->validate_new_pseudonym_name($pseudonym, $account);
        $result .= $res unless $res eq 'OK';

        #$result .= ' blocked';
        $res = '';

        if (!$result) {
            $adb->new_record(
                $pseudonym,
                {   type    => 'pseudonym',
                    Account => $account
                }
            ) or $result .= "Error occurred while creating pseudonym in database.";

            # Untaint $pseudonym before use in system()
            ($pseudonym) = ($pseudonym =~ /(.+)/);
            system("/sbin/e-smith/signal-event", "pseudonym-create", "$pseudonym",) == 0
                or $result .= 'pse_CREATE_ERROR.';
        } ## end if (!$result)

        if (!$result) {
            $res    = 'OK';
            $result = $c->l('pse_CREATE_SUCCEEDED') . ' ' . $pseudonym;
        }
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD') {
        my $account   = $c->param('Account');
        my $internal  = $c->param('Internal') || 'NO';
        my $removable = $adb->get($pseudonym)->prop('Removable') || 'yes';
        my %props     = ('Account' => $account);

        if ($removable eq 'yes') {
            if ($internal eq "YES") { $props{'Visible'} = 'internal'; }
            else                    { $adb->get($pseudonym)->delete_prop('Visible'); }
        }

        # controls
        #$res = '';
        #$res = validate_description( $c, $account );
        #$result .= $res unless $res eq 'OK';
        #$result .= 'blocked';
        $res = '';

        if (!$result) {
            $adb->get($pseudonym)->merge_props(%props)
                or $result .= "Error occurred while modifying pseudonym in database.";

            # Untaint $pseudonym before use in system()
            ($pseudonym) = ($pseudonym =~ /(.+)/);
            system("/sbin/e-smith/signal-event", "pseudonym-modify", "$pseudonym",) == 0
                or $result .= "Error occurred while modifying pseudonym.";
        } ## end if (!$result)

        if (!$result) {
            $res    = 'OK';
            $result = $c->l('pse_MODIFY_SUCCEEDED') . ' ' . $pseudonym;
        }
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'DEL') {

        # controls
        $res = '';
        $res = validate_is_pseudonym($c, $pseudonym);
        $result .= $res unless $res eq 'OK';

        #$result .= 'blocked';
        $res = '';

        if (!$result) {
            $res = $c->delete_pseudonym($pseudonym);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $res    = 'OK';
                $result = $c->l('pse_REMOVE_SUCCEEDED') . ' ' . $pseudonym;
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'DEL')

    # common parts
    if ($res ne 'OK') {
        $c->stash(error => $result);
        $c->stash(title => $title, pse_datas => \%pse_datas);
        return $c->render('pseudonyms');
    }
    my $message = "'Pseudonyms' updates $trt DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('/pseudonyms');
} ## end sub do_update

sub delete_pseudonym {
    my ($c, $pseudonym) = @_;
    my $msg = '';

    #------------------------------------------------------------
    # Make the pseudonym inactive, signal pseudonym-delete event
    # and then delete it
    #------------------------------------------------------------
    my @pseudonyms = $adb->pseudonyms();

    foreach my $p_rec (@pseudonyms) {
        if ($p_rec->prop("Account") eq $pseudonym) {
            $adb->get($p_rec->key)->set_prop('type', 'pseudonym-deleted')
                or $msg .= "Error occurred while changing pseudonym type.";
        }
    } ## end foreach my $p_rec (@pseudonyms)
    $adb->get($pseudonym)->set_prop('type', 'pseudonym-deleted')
        or $msg .= "Error occurred while changing pseudonym type.";

    # Untaint $pseudonym before use in system()
    ($pseudonym) = ($pseudonym =~ /(.+)/);
    system("/sbin/e-smith/signal-event", "pseudonym-delete", "$pseudonym") == 0
        or $msg .= "Error occurred while removing pseudonym.";

    #TODO: is it ->delete or get()->delete
    foreach my $p_rec (@pseudonyms) {

        if ($p_rec->prop("Account") eq $pseudonym) {
            $adb->get($p_rec->key)->delete()
                or $msg .= "Error occurred while deleting pseudonym from database.";
        }
    } ## end foreach my $p_rec (@pseudonyms)
    $adb->get($pseudonym)->delete()
        or $msg .= "Error occurred while deleting pseudonym from database.";
    return $msg unless $msg;
    return 'OK';
} ## end sub delete_pseudonym

sub existing_accounts_list {
    my $c = shift;
    my @existingAccounts = ([ 'Administrator' => 'admin' ]);

    foreach my $a ($adb->get_all) {
        if ($a->prop('type') =~ /(user|group)/) {
            push @existingAccounts, [ $a->key => $a->key ];
        }

        if ($a->prop('type') eq "pseudonym") {
            my $target = $adb->get($a->prop('Account'));

            unless ($target) {
                warn "WARNING: pseudonym (" . $a->key . ") => missing Account(" . $a->prop('Account') . ")\n";
                next;
            }
            push @existingAccounts, [ $a->key, $a->key ]
                unless ($target->prop('type') eq "pseudonym");
        } ## end if ($a->prop('type') eq...)
    } ## end foreach my $a ($adb->get_all)
    return (\@existingAccounts);
} ## end sub existing_accounts_list

=head2 get_pseudonym_account

Returns the current Account property for this pseudonym

=cut

sub get_pseudonym_account {
    my $c         = shift;
    my $pseudonym = shift;
    my $a         = $adb->get($pseudonym)->prop('Account');

    if ($a eq "admin") {
        $a = "Administrator";
    } elsif ($a eq "shared") {
        $a = $c->l("EVERYONE");
    }
    return ($a);
} ## end sub get_pseudonym_account

=head2 is_pseudonym_not_removable

Returns 1 if the current Account is not removable, 0 otherwise

=cut

sub is_pseudonym_not_removable {
    my $c         = shift;
    my $pseudonym = shift;
    my $removable = $adb->get($pseudonym)->prop('Removable') || 'yes';
    return 1 if ($removable eq 'yes');
    return 0;
} ## end sub is_pseudonym_not_removable

=head2 is_pseudonym_internal

Returns YES if the current Account property Visible is 'internal'

=cut

sub is_pseudonym_internal {

    #    my $c = shift;
    my $pseudonym = shift;
    my $visible = $adb->get($pseudonym)->prop('Visible') || '';
    return 'YES' if ($visible eq 'internal');
    return 'NO';
} ## end sub is_pseudonym_internal

=head2 validate_new_pseudonym_name FM PSEUDONYM

Returns "OK" if the pseudonym starts with a letter or number and
contains only letters, numbers, . - and _ and isn't taken

Returns  "VALID_PSEUDONYM_NAMES"  if the name contains invalid chars

Returns "NAME_IN_USE" if this pseudonym is taken.

=cut

sub validate_new_pseudonym_name {
    my ($c, $pseudonym, $account) = @_;
    my $acct = $adb->get($pseudonym);

    if (defined $acct) {
        return ($c->l('pse_NAME_IN_USE'));
    } elsif ($pseudonym =~ /@/) {
        use esmith::DomainsDB;
        my $ddb = esmith::DomainsDB->open_ro
            or die "Couldn't open DomainsDB\n";
        my ($lhs, $rhs) = split /@/, $pseudonym;
        return ($c->l('pse_PSEUDONYM_INVALID_DOMAIN')) unless ($ddb->get($rhs));
        return ($c->l('pse_PSEUDONYM_INVALID_SAMEACCT')) if ($lhs eq $account);
        return ('OK');    # p:' . $pseudonym . ' a:' . $account);
    } elsif ($pseudonym !~ /^([a-z0-9][a-z0-9\.\-_!#\?~\$\^\+&`%\/\*]*)$/) {
        return ($c->l('pse_VALID_PSEUDONYM_NAMES'));
    } else {
        return ('OK');
    }
} ## end sub validate_new_pseudonym_name

=head2 validate_is_pseudonym FM NAME

returns  "OK" if it is.
returns "NOT_A_PSEUDONYM" if the name in question isn't an existing pseudonym

=cut

sub validate_is_pseudonym {
    my $c         = shift;
    my $pseudonym = shift;
    $pseudonym = $adb->get($pseudonym);
    return ($c->l('pse_NOT_A_PSEUDONYM')) unless $pseudonym;
    my $type = $pseudonym->prop('type');

    unless (defined $type && ($type eq 'pseudonym')) {
        return ($c->l('NOT_A_PSEUDONYM'));
    }
    return ('OK');
} ## end sub validate_is_pseudonym
1;
