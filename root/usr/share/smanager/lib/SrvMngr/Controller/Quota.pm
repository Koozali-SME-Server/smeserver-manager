package SrvMngr::Controller::Quota;

#----------------------------------------------------------------------
# heading     : User management
# description : Quotas
# navigation  : 2000 300
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use esmith::FormMagick::Panel::quota;

#use esmith::TestUtils;
use Scalar::Util qw(looks_like_number);

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);

#our $db = esmith::ConfigDB->open || die "Couldn't open config db";
our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %quo_datas = ();
    my $title = $c->l('quo_FORM_TITLE');

    $quo_datas{'trt'} = 'LIST';

    my @userAccounts;
    if ($adb) {
        @userAccounts = $adb->users();
    }

    $c->stash( title => $title, quo_datas => \%quo_datas, userAccounts => \@userAccounts );
    $c->render(template => 'quota');

};


sub do_display {

    my $c = shift;

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');
    my $user = $c->param('user') || '';

    $trt = 'UPD' if ( $user );

    my %quo_datas = ();
    my $title = $c->l('quo_FORM_TITLE');

    $quo_datas{'trt'} = $trt;

        if ( $trt eq 'UPD' ) {

	    my $rec = $adb->get($user);
	    if ($rec and $rec->prop('type') eq 'user') {
    		$quo_datas{user} = $user;
    		$quo_datas{userRec} = $rec;
		my $max = esmith::FormMagick::Panel::quota->toBestUnit($rec->prop('MaxBlocks'));
    		$quo_datas{hardlim} = $max;
		$max = esmith::FormMagick::Panel::quota->toBestUnit($rec->prop('MaxBlocksSoftLim'));
    		$quo_datas{softlim} = $max;
	    }

        }

    $c->stash( title => $title, quo_datas => \%quo_datas );
    $c->render( template => 'quota' );

};


sub do_update {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('quo_FORM_TITLE');
    my %quo_datas = ();

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');

    $quo_datas{trt} = $trt;
    my $result = '';
    my $res;

    if ( $trt eq 'UPD' ) {

	$quo_datas{user} = ($c->param('user') || '');
	$quo_datas{softlim} = ($c->param('Soft') || '');
        $quo_datas{hardlim} = ($c->param('Hard') || '');

	# controls
	$res = validate_quota( $c, $quo_datas{user}, $quo_datas{softlim}, $quo_datas{hardlim} );
	$result .= $res unless $res eq 'OK';

	if ( ! $result ) {
	    $result = $c->l('quo_SUCCESSFULLY_MODIFIED') . ' ' . $quo_datas{user};
	} else {
	    $quo_datas{userRec} = $adb->get($quo_datas{user}) || undef;
	}
    }

    # common parts

    if ($res ne 'OK') {
	$c->stash( error => $result );
	$c->stash( title => $title, quo_datas => \%quo_datas );
	return $c->render('quota');
    }

    my $message = "'Quota' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash( success => $result );

    $c->redirect_to('/quota');

};


sub validate_quota {
    my ($c, $acct, $softlim, $hardlim ) = @_;
    my $msg;

    my $rec = $adb->get($acct);
    return $c->l('quo_ERR_NO_SUCH_ACCT') . ' : ' . $acct  unless (defined $rec);

    my $type = $rec->prop('type');
    unless ($type eq "user") {
	$msg = $c->l('quo_ERR_NOT_A_USER_ACCT').$acct.$c->l('quo_ACCOUNT_IS_TYPE').$type;
	return $msg;
    }
    my $uid = getpwnam($acct);
    return $c->l('COULD_NOT_GET_UID').$acct unless ($uid);

    if (($softlim !~ /^(.+?)\s*([KMGT])?$/ ) || (!looks_like_number ($1)))  {
	return $c->l('quo_SOFT_VAL_MUST_BE_NUMBER');
    }
    
   my $exponent = 1; # Entries with no suffix are assumed to be in megabytes.
   if (defined ($2)) { 
   	$exponent = index("KMGT",$2);
   }
   $softlim = ($1 * 1024 ** $exponent);

    if (($hardlim !~ /^(.+?)\s*([KMGT])?$/ ) || (!looks_like_number ($1))) {
	return $c->l('quo_HARD_VAL_MUST_BE_NUMBER');
    }
   $exponent = 1; # Entries with no suffix are assumed to be in megabytes.
   if (defined ($2)) 
   { 
   	$exponent = index("KMGT",$2);
   }   
   $hardlim = ($1 * 1024 ** $exponent);

    #------------------------------------------------------------
    # Make sure that soft limit is less than hard limit.
    #------------------------------------------------------------

    unless ($hardlim == 0 or $hardlim > $softlim) {
	return $c->l('quo_ERR_HARD_LT_SOFT');
    }

    #------------------------------------------------------------
    # Update accounts database and signal the user-modify event.
    #------------------------------------------------------------

    $rec->set_prop('MaxBlocks', $hardlim);
    $rec->set_prop('MaxBlocksSoftLim', $softlim);

    # Untaint $acct before using in system().
    $acct =~ /^(\w[\-\w_\.]*)$/; $acct = $1;
    system ("/sbin/e-smith/signal-event", "user-modify", "$acct") == 0
        or die ($c->l('quo_ERR_MODIFYING')."\n");

    return 'OK';
}


1
