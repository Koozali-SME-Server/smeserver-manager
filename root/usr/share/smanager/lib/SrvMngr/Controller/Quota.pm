package SrvMngr::Controller::Quota;

#----------------------------------------------------------------------
# heading     : User management
# description : Quotas
# navigation  : 2000 500
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw(looks_like_number);
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use esmith::AccountsDB::UTF8;

my $adb;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %quo_datas = ();
    my $title     = $c->l('quo_FORM_TITLE');
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $quo_datas{'trt'} = 'LIST';
    my @userAccounts;

    if ($adb) {
        @userAccounts = $adb->users();
    }
    $c->stash(title => $title, quo_datas => \%quo_datas, userAccounts => \@userAccounts);
    $c->render(template => 'quota');
} ## end sub main

sub do_display {
    my $c    = shift;
    my $rt   = $c->current_route;
    my $trt  = ($c->param('trt') || 'LIST');
    my $user = $c->param('user') || '';
    $trt = 'UPD' if ($user);
    my %quo_datas = ();
    my $title     = $c->l('quo_FORM_TITLE');
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $quo_datas{'trt'} = $trt;

    if ($trt eq 'UPD') {
        my $rec = $adb->get($user);

        if ($rec and $rec->prop('type') eq 'user') {
            $quo_datas{user}    = $user;
            $quo_datas{userRec} = $rec;
            my $max = $c->toBestUnit($rec->prop('MaxBlocks'));
            $quo_datas{hardlim} = $max;
            $max                = $c->toBestUnit($rec->prop('MaxBlocksSoftLim'));
            $quo_datas{softlim} = $max;
        } ## end if ($rec and $rec->prop...)
    } ## end if ($trt eq 'UPD')
    $c->stash(title => $title, quo_datas => \%quo_datas);
    $c->render(template => 'quota');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $title     = $c->l('quo_FORM_TITLE');
    my %quo_datas = ();
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LIST');
    $quo_datas{trt} = $trt;
    my $result = '';
    my $res;
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";

    if ($trt eq 'UPD') {
        $quo_datas{user}    = ($c->param('user') || '');
        $quo_datas{softlim} = ($c->param('Soft') || '');
        $quo_datas{hardlim} = ($c->param('Hard') || '');

        # controls
        $res = validate_quota($c, $quo_datas{user}, $quo_datas{softlim}, $quo_datas{hardlim});
        $result .= $res unless $res eq 'OK';

        if (!$result) {
            $result = $c->l('quo_SUCCESSFULLY_MODIFIED') . ' ' . $quo_datas{user};
        } else {
            $quo_datas{userRec} = $adb->get($quo_datas{user}) || undef;
        }
    } ## end if ($trt eq 'UPD')

    # common parts
    if ($res ne 'OK') {
        $c->stash(error => $result);
        $c->stash(title => $title, quo_datas => \%quo_datas);
        return $c->render('quota');
    }
    my $message = "'Quota' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('/quota');
} ## end sub do_update

sub validate_quota {
    my ($c, $acct, $softlim, $hardlim) = @_;
    my $msg;
    my $rec = $adb->get($acct);
    return $c->l('quo_ERR_NO_SUCH_ACCT') . ' : ' . $acct unless (defined $rec);
    my $type = $rec->prop('type');

    unless ($type eq "user") {
        $msg = $c->l('quo_ERR_NOT_A_USER_ACCT') . $acct . $c->l('quo_ACCOUNT_IS_TYPE') . $type;
        return $msg;
    }
    my $uid = getpwnam($acct);
    return $c->l('COULD_NOT_GET_UID') . $acct unless ($uid);

    if (($softlim !~ /^(.+?)\s*([KMGT])?$/) || (!looks_like_number($1))) {
        return $c->l('quo_SOFT_VAL_MUST_BE_NUMBER');
    }
    my $exponent = 1;    # Entries with no suffix are assumed to be in megabytes.

    if (defined($2)) {
        $exponent = index("KMGT", $2);
    }
    $softlim = ($1 * 1024**$exponent);

    if (($hardlim !~ /^(.+?)\s*([KMGT])?$/) || (!looks_like_number($1))) {
        return $c->l('quo_HARD_VAL_MUST_BE_NUMBER');
    }
    $exponent = 1;       # Entries with no suffix are assumed to be in megabytes.

    if (defined($2)) {
        $exponent = index("KMGT", $2);
    }
    $hardlim = ($1 * 1024**$exponent);

    #------------------------------------------------------------
    # Make sure that soft limit is less than hard limit.
    #------------------------------------------------------------
    unless ($hardlim == 0 or $hardlim > $softlim) {
        return $c->l('quo_ERR_HARD_LT_SOFT');
    }

    #------------------------------------------------------------
    # Update accounts database and signal the user-modify event.
    #------------------------------------------------------------
    $rec->set_prop('MaxBlocks',        $hardlim);
    $rec->set_prop('MaxBlocksSoftLim', $softlim);

    # Untaint $acct before using in system().
    $acct =~ /^(\w[\-\w_\.]*)$/;
    $acct = $1;
    system("/sbin/e-smith/signal-event", "user-modify", "$acct") == 0
        or die($c->l('quo_ERR_MODIFYING') . "\n");
    return 'OK';
} ## end sub validate_quota

sub toMB
{
    my ($self,$kb) = @_;
    return sprintf("%.2f", $kb / 1024);
}

sub toMBNoDecimalPlaces
{
    my ($self,$kb) = @_;
    return sprintf("%.0f", $kb / 1024);
}

sub toGBNoDecimalPlaces
{
    my ($self,$kb) = @_;
    return sprintf("%.0f", $kb / 1024 / 1024);
}

sub toKB 
{
    my ($self,$mb) = @_;
    return sprintf("%.0f", $mb * 1024);
}


sub GBtoKB
{
    my ($self,$gb) = @_;
    return sprintf("%.0f", $gb * 1024 * 1024);
}

sub MBtoKB
{
    my ($self,$mb) = @_;
    return sprintf("%.0f", $mb * 1024);
}

sub toBestUnit
{
    my ($self,$kb) = @_;
    return 0 if($kb == 0);
    return $kb."K" if($kb < 1024);
    return $kb."K" if($kb > 1024 && $kb < 1048576 && $kb % 1024 != 0);
    return $self->toMBNoDecimalPlaces($kb)."M" if($kb < 1048576);
    return $self->toMBNoDecimalPlaces($kb)."M" if($kb > 1048576 
	&& ($kb % 1048576 != 0));
    return $self->toGBNoDecimalPlaces($kb)."G";
}

1
