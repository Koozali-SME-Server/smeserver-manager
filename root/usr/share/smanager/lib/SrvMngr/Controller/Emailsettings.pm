package SrvMngr::Controller::Emailsettings;

#----------------------------------------------------------------------
# heading     : System
# description : E-mail
# navigation  : 4000 500
#
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session ip_number_or_blank);

use esmith::ConfigDB;
use esmith::AccountsDB;

use esmith::util;
use File::Basename;

our $pattern_db = esmith::ConfigDB->open("mailpatterns");
our $cdb = esmith::ConfigDB->open || die "Couldn't open config db";


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %mai_datas = ();
    my $title = $c->l('mai_FORM_TITLE');

    $mai_datas{'trt'} = 'LIST';
    $mai_datas{fetchmailmethod} = $cdb->get_prop('fetchmail', 'Method');

    $c->stash( title => $title, notif => '', mai_datas => \%mai_datas );
    $c->render(template => 'emailsettings');

};


sub do_display {

    my $c = shift;

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');

    my %mai_datas = ();
    my $title = $c->l('mai_FORM_TITLE');
    my ($notif, $dest) = '';

    $mai_datas{'trt'} = $trt;

        if ( $trt eq 'ACC' ) {
	    $dest = 'emailaccess';
	    $mai_datas{fetchmailmethod} = $cdb->get_prop('fetchmail', 'Method');
        }

        if ( $trt eq 'FIL' ) {
	    $dest = 'emailfilter';
	    $mai_datas{'virusstatus'} = $c->get_virus_status();
	    $mai_datas{'spamstatus'} = $cdb->get_prop('spamassassin', 'status');
	    $mai_datas{'spamsensitivity'} = $cdb->get_prop('spamassassin', 'Sensitivity','medium');
	    $mai_datas{'spamtaglevel'} = $cdb->get_prop('spamassassin', 'TagLevel') || '0';
	    $mai_datas{'spamrejectlevel'} = $cdb->get_prop('spamassassin', 'RejectLevel') || '0';
	    $mai_datas{spamsortspam} = $cdb->get_prop('spamassassin', 'SortSpam');
	    $mai_datas{spamsubjecttag} = $cdb->get_prop('spamassassin', 'SubjectTag');
	    $mai_datas{spamsubject} = $cdb->get_prop('spamassassin', 'Subject');
        }

        if ( $trt eq 'REC' ) {
	    $dest = 'emailreceive';
	    $mai_datas{fetchmailmethod} = $cdb->get_prop('fetchmail', 'Method');
	    $mai_datas{freqoffice} = $cdb->get_prop('fetchmail', 'FreqOffice');
	    $mai_datas{freqoutside} = $cdb->get_prop('fetchmail', 'FreqOutside');
	    $mai_datas{freqweekend} = $cdb->get_prop('fetchmail', 'FreqWeekend');
	    $mai_datas{secondarymailserver} = $cdb->get_prop('fetchmail', 'SecondaryMailServer');
	    $mai_datas{secondarymailaccount} = $cdb->get_prop('fetchmail', 'SecondaryMailAccount');
	    $mai_datas{secondarymailpassword} = $cdb->get_prop('fetchmail', 'SecondaryMailPassword');
	    $mai_datas{specifyheader} = get_secondary_mail_use_envelope();
	    $mai_datas{secondarymailenvelope} = $cdb->get_prop('fetchmail', 'SecondaryMailEnvelope');

	}

        if ( $trt eq 'DEL' ) {
	    $dest = 'emaildeliver';
	    $mai_datas{emailunknownuser} = $cdb->get_value('EmailUnknownUser') || '"returntosender';
	    $mai_datas{delegatemailserver} = $cdb->get_value('DelegateMailServer');
	    $mai_datas{smtpsmarthost} = $cdb->get_value('SMTPSmartHost');
	    $mai_datas{smtpauthproxystatus} = $cdb->get_prop('smtp-auth-proxy', 'status') || 'disabled';
	    $mai_datas{smtpauthproxyuserid} = $cdb->get_prop('smtp-auth-proxy', 'Userid') || '';
	    $mai_datas{smtpauthproxypassword} = $cdb->get_prop('smtp-auth-proxy', 'Passwd') || '';
	}


    $c->stash( title => $title, notif => $notif, mai_datas => \%mai_datas );
    return $c->render( template => $dest );

};


sub do_update {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = $c->param('trt');

    my %mai_datas = ();
    $mai_datas{trt} = $trt;

    my $title = $c->l('mai_FORM_TITLE');

    my ($dest, $res, $result) = '';

    if ( $trt eq 'ACC' ) {

	$dest = 'emailaccess';
#	$mai_datas{xxx}	= $c->param('XXX');

	# controls
#	$res = xxxxxxx( $c );
#	$result .= $res unless $res eq 'OK';

	if ( ! $result ) {
	    $res = $c->change_settings_access();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('mai_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'FIL' ) {

	$dest = 'emailfilter';
#	$mai_datas{xxx}	= $c->param('XXX');

	# controls
#	$res = zzzzzz( $c );
#	$result .= $res unless $res eq 'OK';

	if ( ! $result ) {
	    $res = $c->change_settings_filtering();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('mai_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'REC' ) {

	$dest = 'emailreceive';
#	$mai_datas{xxx}	= $c->param('XXX');

	# controls
#	$res = yyyyyyyyy( $c );
#	$result .= $res unless $res eq 'OK';

	if ( ! $result ) {
	    $res = $c->change_settings_reception();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('mai_SUCCESS'); 
	    }
	}
    }

    if ( $trt eq 'DEL' ) {

	$dest = 'emaildeliver';
#	$mai_datas{xxx}	= $c->param('XXX');

	# controls
	$res = $c->ip_number_or_blank( $c->param('DelegateMailServer') );
	$result .= $res . ' DMS <br>' unless $res eq 'OK';

	$res = $c->validate_smarthost( $c->param('SMTPSmartHost') );
	$result .= $res . ' SH <br>' unless $res eq 'OK';

	$res = $c->nonblank_if_smtpauth( $c->param('SMTPSmartHost') );
	$result .= $res . ' SH <br>' unless $res eq 'OK';

	$res = $c->nonblank_if_smtpauth( $c->param('SMTPAUTHPROXY_Userid') );
	$result .= $res . ' USR <br>' unless $res eq 'OK';

	$res = $c->nonblank_if_smtpauth( $c->param('SMTPAUTHPROXY_Passwd') );
	$result .= $res . ' PWD <br>' unless $res eq 'OK';

	if ( ! $result ) {
	    $res = $c->change_settings_delivery();
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('mai_SUCCESS');
	    }
	}
    }


    # common part

    if ($res ne 'OK') {
	$c->stash( error => $result );
	$c->stash( title => $title, mai_datas => \%mai_datas );
	return $c->render( $dest );
    }

    my $message = "emailsettings updates $trt DONE";
    $c->app->log->info($message);
    $c->flash( success => $result );

    $c->redirect_to("/emailsettings");

};


sub get_virus_status {

    my ($c, $localise) = @_;

    my $status = $cdb->get_prop("qpsmtpd", 'VirusScan') || 'disabled';

    return $localise ? $c->localise_status($status) : $status;
}

sub get_spam_status {

    my ($c, $localise) = @_;

    my $status = $cdb->get_prop('spamassassin', 'status') || 'disabled';

    return $localise ? $c->localise_status($status) : $status;
}


sub localise_status {

    my ($c, $status) = @_;

    return $c->l($status eq 'enabled' ? $c->l('ENABLED') : $c->l('DISABLED'));
}


sub get_prop {

    my ($c, $item, $prop, $default) = @_;

    return $cdb->get_prop($item, $prop) || $default;
}


sub get_value {

    my $c   = shift;
    my $item = shift;

    return $cdb->get_value($item) || '';
}


sub get_emailunknownuser_status {

    my ($c, $localise) = @_;

    my $options = $c->get_emailunknownuser_options();

    my $val = $cdb->get_value('EmailUnknownUser') || "returntosender";

    return $localise ? $c->l($options->{$val}) : $val;
}


sub get_patterns_status {

    my ($c, $localise) = @_;

    my $status = $cdb->get_prop("qpsmtpd", 'PatternsScan') || 'disabled';

    return $localise ? $c->localise_status($status) : $status;
}


sub adjust_patterns {

    my $c = shift;

    my @selected = @{$c->every_param('BlockExecutableContent')};

    foreach my $pattern ( $pattern_db->get_all_by_prop( type => "pattern") )
    {
        my $status = (grep $pattern->key eq $_, @selected) ? 'enabled' 
                                                           : 'disabled';
        $pattern->set_prop('Status', $status);
    }

    $pattern_db->reload;

    return scalar @selected;

}


sub get_current_pop3_access {

    my ($c, $localise) = @_;

    my $pop3Status = $cdb->get_prop('pop3', 'status') || 'enabled';
    my $pop3Access = $cdb->get_prop('pop3', 'access') || 'private';

    my $pop3sStatus = $cdb->get_prop('pop3s', 'status') || 'enabled';
    my $pop3sAccess = $cdb->get_prop('pop3s', 'access') || 'private';

    my $options = get_pop_options();

    if ($pop3Status ne 'enabled' && $pop3sStatus ne 'enabled')
    {
        return $localise ? $c->l($options->{disabled}) : 'disabled';
    }
    elsif ($pop3Status eq 'enabled' && $pop3Access eq 'public')
    {
        return $localise ? $c->l($options->{public}) : 'public';
    }
    elsif ($pop3sStatus eq 'enabled' && $pop3sAccess eq 'public')
    {
        return $localise ? $c->l($options->{publicSSL}) : 'publicSSL';
    }
    return $localise ? $c->l($options->{private}) : 'private';
}


sub get_current_imap_access {

    my ($c, $localise) = @_;

    my $imapStatus = $cdb->get_prop('imap', 'status') || 'enabled';
    my $imapAccess = $cdb->get_prop('imap', 'access') || 'private';

    my $imapsStatus = $cdb->get_prop('imaps', 'status') || 'enabled';
    my $imapsAccess = $cdb->get_prop('imaps', 'access') || 'private';

    my $options = get_imap_options();

    if (($imapStatus ne 'enabled' || $imapAccess eq 'localhost') && $imapsStatus ne 'enabled')
    {
        return $localise ? $c->l($options->{disabled}) : 'disabled';
    }
    if ($imapStatus eq 'enabled' && $imapAccess eq 'public')
    {
        return $localise ? $c->l($options->{public}) : 'public';
    }
    elsif ($imapsStatus eq 'enabled' && $imapsAccess eq 'public')
    {
        return $localise ? $c->l($options->{publicSSL}) : 'publicSSL';
    }
    return $localise ? $c->l($options->{private}) : 'private';
}


sub get_current_smtp_auth {

    my ($c, $localise) = @_;

    my $smtpStatus = $cdb->get_prop('qpsmtpd', 'status') || 'enabled';
    my $smtpAuth = $cdb->get_prop('qpsmtpd', 'Authentication') || 'enabled';

    my $smtpsStatus = $cdb->get_prop('sqpsmtpd', 'status') || 'enabled';
    my $smtpsAuth = $cdb->get_prop('sqpsmtpd', 'Authentication') || 'enabled';

    my $options = get_smtp_auth_options();

    if ($smtpStatus eq 'enabled' && $smtpAuth eq 'enabled')
    {
        return $localise ? $c->l($options->{public}) : 'public';
    }
    elsif ($smtpsStatus eq 'enabled' && $smtpsAuth eq 'enabled')
    {
        return $localise ? $c->l($options->{publicSSL}) : 'publicSSL';
    }
    return $localise ? $c->l($options->{disabled}) : 'disabled';
}


sub get_current_webmail_status {

  my ($c, $localise) = @_;

  # determine status of webmail
  my $WebmailStatus = "disabled";

  my $IMPStatus = $cdb->get_prop('imp', 'status') || 'disabled';

  my $HordeStatus = $cdb->get_prop('horde', 'status') || 'disabled';

  my $MysqlStatus = $cdb->get_prop('mariadb', 'status') || 'disabled';

  my $PHPStatus = $cdb->get_prop('php', 'status') || 'disabled';

  my $Networkaccess = $cdb->get_prop('horde','access') || 'disabled';

  # all four components must be on for webmail to be working
  if ( ( $IMPStatus eq "enabled" )
       && ( $HordeStatus eq "enabled" )
       && ( $MysqlStatus eq "enabled" )
       && ( $PHPStatus eq "enabled"   ) 
       && ( $Networkaccess eq "public"))
    {
      $WebmailStatus = "enabledSSL";
    }

  elsif ( ( $IMPStatus eq "enabled" )
       && ( $HordeStatus eq "enabled" )
       && ( $MysqlStatus eq "enabled" )
       && ( $PHPStatus eq "enabled"   )
       && ( $Networkaccess eq "private" ))
    {
      $WebmailStatus = "localnetworkSSL";
    }

  my $options = get_webmail_options();

  return $localise ? $c->l($options->{$WebmailStatus}) 
                   : $WebmailStatus;
}


sub get_pop_opt {

  my $c = shift;

    return [[ $c->l('DISABLED') => 'disabled' ],
	    [ $c->l('NETWORKS_ALLOW_LOCAL') => 'private' ],
	    [ $c->l('mai_SECURE_POP3') => 'publicSSL' ],
	    [ $c->l('mai_INSECURE_POP3') => 'public' ]];

}


sub get_pop_options {

  my $c = @_;

    my %options = (
	disabled => 'DISABLED',
	private => 'NETWORKS_ALLOW_LOCAL',
	publicSSL  => 'mai_SECURE_POP3'
    );

    my $access = $cdb->get_prop('pop3', 'access') || 'private';

    $options{public} = 'mai_INSECURE_POP3' if ($access eq 'public');

    \%options;
}


sub get_imap_opt {

  my $c = shift;

    return [[ $c->l('DISABLED') => 'disabled' ],
	    [ $c->l('NETWORKS_ALLOW_LOCAL') => 'private' ],
	    [ $c->l('mai_SECURE_IMAP') => 'publicSSL' ],
	    [ $c->l('mai_INSECURE_IMAP') => 'public' ]];

}


sub get_imap_options {

  my $c = shift;

    my %options = (
	disabled => 'DISABLED',
	private => 'NETWORKS_ALLOW_LOCAL',
	publicSSL  => 'mai_SECURE_IMAP'
    );

    my $access = $cdb->get_prop('imap', 'access') || 'private';

    $options{public} = 'mai_INSECURE_IMAP' if ($access eq 'public');

    \%options;
}


sub get_smtp_auth_options {
    
    my $c = shift;

    my %options = ( disabled => 'DISABLED', publicSSL  => 'mai_SECURE_SMTP', public => 'mai_INSECURE_SMTP');

    \%options;
}


sub get_webmail_opt {

  my $c = shift;

    return [[ $c->l('DISABLED') => 'disabled' ],
	    [ $c->l('mai_ENABLED_SECURE_ONLY') => 'enabledSSL' ],
	    [ $c->l('mai_ONLY_LOCAL_NETWORK_SSL') => 'localnetworkSSL' ],
	    [ $c->l('mai_ENABLED_BOTH') => 'public' ]];

}


sub get_webmail_options {

    my $c = shift;

    my %options = ( 
		disabled   => 'DISABLED', 
               enabledSSL => 'mai_ENABLED_SECURE_ONLY',
               localnetworkSSL => 'mai_ONLY_LOCAL_NETWORK_SSL' );

    \%options;
}


sub get_retrieval_opt {

  my $c = shift;

    return $cdb->get("SystemMode")->value eq "servergateway-private"
         ? [ $c->l('mai_MULTIDROP') => 'multidrop']
         : [[ $c->l('mai_STANDARD') => 'standard'],
            [ $c->l('mai_ETRN') => 'etrn' ],
            [ $c->l('mai_MULTIDROP') => 'multidrop']];
}


sub get_smtp_auth_opt {

    my $c = shift;

    return [[ $c->l('DISABLED') => 'disabled'],
	    [ $c->l('mai_SECURE_SMTP') => 'publicSSL'],
	    [ $c->l('mai_INSECURE_SMTP') => 'public']];
}


sub get_emailunknownuser_options {

    my $c = shift;
    my $accounts = esmith::AccountsDB->open_ro();
    my %existingAccounts = ('admin' => $c->l("mai_FORWARD_TO_ADMIN"), 
            'returntosender' => $c->l("mai_RETURN_TO_SENDER") );

    foreach my $account ($accounts->get_all) {
        next if $account->key eq 'everyone';
        if ($account->prop('type') =~ /(user|group|pseudonym)/) {
            $existingAccounts{$account->key} = $c->l("mai_FORWARD_TO") . " " . $account->key;
        }
    }
    return(\%existingAccounts); 
}


sub get_emailunknownuser_opt {

    my $c = shift;
    my $accounts = esmith::AccountsDB->open_ro();

    my @existingAccounts = ([ $c->l("mai_FORWARD_TO_ADMIN") => 'admin'],
        		    [ $c->l("mai_RETURN_TO_SENDER") => 'returntosender']);

    foreach my $account ($accounts->get_all) {
        next if $account->key eq 'everyone';
        if ($account->prop('type') =~ /(user|group|pseudonym)/) {
            push @existingAccounts, [ $c->l("mai_FORWARD_TO") . " " . $account->key => $account->key];
        }
    }
    return(\@existingAccounts); 
}


sub get_patterns_opt {

    my $c = shift;
    my @options;

    foreach my $pattern ( $pattern_db->get_all_by_prop( type => "pattern" ) ) {
        my %props = $pattern->props;
        push @options, [ $props{'Description'} => $pattern->key ];
    }
    return \@options;
}


sub get_patterns_current_opt {

    my $c = shift;
    my @selected;

    foreach my $pattern ( $pattern_db->get_all_by_prop( type => "pattern" ) ) {
        my %props = $pattern->props;
        push @selected, $pattern->key if ($props{'Status'} eq 'enabled');
    }
    return \@selected;
}

sub get_spam_level_options {

    return [ 0..20 ];
}


sub get_spam_sensitivity_opt {

  my $c = shift;

    return [[ $c->l('mai_VERYLOW') => 'verylow' ],
	    [ $c->l('mai_LOW') => 'low' ],
	    [ $c->l('mai_MEDIUM') => 'medium' ],
	    [ $c->l('mai_HIGH') => 'high' ],
	    [ $c->l('mai_VERYHIGH') => 'veryhigh' ],
	    [ $c->l('mai_CUSTOM') => 'custom' ]];

}


sub fetchmail_freq {

  my $c = shift;

    return [[ $c->l('mai_NEVER') => 'never' ],
	    [ $c->l('mai_EVERY5MIN') => 'every5min' ],
	    [ $c->l('mai_EVERY15MIN') => 'every15min' ],
	    [ $c->l('mai_EVERY30MIN') => 'every30min' ],
	    [ $c->l('mai_EVERYHOUR') => 'everyhour' ],
	    [ $c->l('mai_EVERY2HRS') => 'every2hrs' ]];
}


sub display_multidrop {

    my $status = $cdb->get_prop('fetchmail', 'status') || 'disabled';

    # XXX FIXME - WIP 
    # Only display ETRN/multidrop settings if relevant
    # To do this, we need an "Show ETRN/multidrop settings" button
    # in standard mode.

    # return ($status eq 'enabled');
    return 1;	
}


sub change_settings_reception {

    my $c = shift;

    my $FetchmailMethod = ( $c->param('FetchmailMethod') || 'standard' );

    my $FetchmailFreqOffice = ( $c->param('FreqOffice') || 'every15min' );

    my $FetchmailFreqOutside = ( $c->param('FreqOutside')   || 'everyhour' );
    my $FetchmailFreqWeekend = ( $c->param('FreqWeekend')   || 'everyhour' );
    my $SpecifyHeader        = ( $c->param('SpecifyHeader') || 'off' );

    my $fetchmail = $cdb->get('fetchmail') || $cdb->new_record( "fetchmail", 
			{ type => "service", status => "disabled" } );

    if ( $FetchmailMethod eq 'standard' ) {
        $fetchmail->set_prop( 'status', 'disabled' );
        $fetchmail->set_prop( 'Method', $FetchmailMethod );
    }
    else {
        $fetchmail->set_prop( 'status', 'enabled' );
        $fetchmail->set_prop( 'Method', $FetchmailMethod );
        $fetchmail->set_prop( 'SecondaryMailServer', 
	    $c->param('SecondaryMailServer') )
	    unless ( $c->param('SecondaryMailServer') eq '' );

        $fetchmail->set_prop('FreqOffice',  $FetchmailFreqOffice );
        $fetchmail->set_prop('FreqOutside', $FetchmailFreqOutside );
        $fetchmail->set_prop('FreqWeekend', $FetchmailFreqWeekend );
        $fetchmail->set_prop('SecondaryMailAccount',
	    $c->param('SecondaryMailAccount') )
	    unless ( $c->param('SecondaryMailAccount') eq '' );

        $fetchmail->set_prop( 'SecondaryMailPassword',
	    $c->param('SecondaryMailPassword') )
	    unless ( $c->param('SecondaryMailPassword') eq '' );

        if ( $SpecifyHeader eq 'on' ) {
            $fetchmail->merge_props(
                'SecondaryMailEnvelope' => $c->param('SecondaryMailEnvelope') );
        }
        else {
            $fetchmail->delete_prop('SecondaryMailEnvelope');
        }
    }

    my $smtpAuth = ($c->param('SMTPAuth') || 'public');
    if ($smtpAuth eq 'public') {
        $cdb->set_prop("qpsmtpd", "Authentication", "enabled" );
        $cdb->set_prop("sqpsmtpd", "Authentication", "enabled" );
    } elsif ($smtpAuth eq 'publicSSL') {
        $cdb->set_prop("qpsmtpd", "Authentication", "disabled" );
        $cdb->set_prop("sqpsmtpd", "Authentication", "enabled" );
    } else {
        $cdb->set_prop("qpsmtpd", "Authentication", "disabled" );
        $cdb->set_prop("sqpsmtpd", "Authentication", "disabled" );
    }

    unless ( system( "/sbin/e-smith/signal-event", "email-update" ) == 0 )
    {
	return $c->l('mai_ERROR_UPDATING_CONFIGURATION');
    }
    return 'OK';
}


sub change_settings_delivery {

    my ($c) = shift;

    my $EmailUnknownUser = ($c->param('EmailUnknownUser') || 'returntosender');

    $cdb->set_value('SMTPSmartHost', $c->param('SMTPSmartHost'));
    $cdb->set_value('DelegateMailServer', $c->param('DelegateMailServer'));
    $cdb->set_value('EmailUnknownUser', $EmailUnknownUser);

    my $proxy = $cdb->get('smtp-auth-proxy');
    my %props = $proxy->props;

    for ( qw(Userid Passwd status) )
    {
        $props{$_} = $c->param("SMTPAUTHPROXY_$_");
    }

    $proxy->merge_props(%props);

    unless ( system( "/sbin/e-smith/signal-event", "email-update" ) == 0 )
    {
	return $c->l('mai_ERROR_UPDATING_CONFIGURATION');
    }
    return 'OK';
}


sub change_settings_access {

    my $c = shift;

    my $pop3Access = ($c->param('POPAccess') || 'private');
    if ($pop3Access eq 'disabled') {
        $cdb->set_prop('pop3', "status", "disabled" );
        $cdb->set_prop('pop3s', "status", "disabled" );
    } else {
        $cdb->set_prop('pop3', "status", "enabled" );
        $cdb->set_prop('pop3s', "status", "enabled" );
    }
    if ($pop3Access eq 'public') {
        $cdb->set_prop('pop3', "access", "public" );
        $cdb->set_prop('pop3s', "access", "public" );
    } elsif ($pop3Access eq 'publicSSL') {
        $cdb->set_prop('pop3', "access", "private" );
        $cdb->set_prop('pop3s', "access", "public" );
    } else {
        $cdb->set_prop('pop3', "access", "private" );
        $cdb->set_prop('pop3s', "access", "private" );
    }

    my $imapAccess = ($c->param('IMAPAccess') || 'private');
    if ($imapAccess eq 'disabled') {
        $cdb->set_prop('imap', "status", "enabled" );
        $cdb->set_prop('imap', "access", "localhost" );
        $cdb->set_prop('imaps', "status", "disabled" );
    } elsif ($imapAccess eq 'public') {
        $cdb->set_prop('imap', "status", "enabled" );
        $cdb->set_prop('imap', "access", "public" );
        $cdb->set_prop('imaps', "status", "enabled" );
        $cdb->set_prop('imaps', "access", "public" );
    } elsif ($imapAccess eq 'publicSSL') {
        $cdb->set_prop('imap', "status", "enabled" );
        $cdb->set_prop('imap', "access", "private" );
        $cdb->set_prop('imaps', "status", "enabled" );
        $cdb->set_prop('imaps', "access", "public" );
    } else {
        $cdb->set_prop('imap', "status", "enabled" );
        $cdb->set_prop('imap', "access", "private" );
        $cdb->set_prop('imaps', "status", "enabled" );
        $cdb->set_prop('imaps', "access", "private" );
    }

    #------------------------------------------------------------
    # Set webmail state in configuration database, and access
    # type for SSL
    # PHP and MySQL should always be on, and are enabled by default
    # We don't do anything with them here.
    #------------------------------------------------------------

    my $webmail = ($c->param('WebMail') || 'disabled');
    if ( $webmail eq "enabled" ) {
      $cdb->set_prop('php', "status", $webmail );
      $cdb->set_prop('mariadb',"status", $webmail );
      $cdb->set_prop('imp',"status", $webmail );
      $cdb->set_prop('horde', "status", $webmail );
      $cdb->set_prop('imp',"access", "full" );
      $cdb->set_prop('horde',"access", "public" );
      $cdb->set_prop('horde',"HttpsOnly", "no" );
    }
    elsif ( $webmail eq "enabledSSL" ) {
      $cdb->set_prop('php',"status", "enabled" );
      $cdb->set_prop('mariadb',"status", "enabled" );
      $cdb->set_prop('imp',"status", 'enabled' );
      $cdb->set_prop('horde',"status", 'enabled' );
      $cdb->set_prop('imp',"access", "SSL" );
      $cdb->set_prop('horde',"access", "public" );
      $cdb->set_prop('horde',"HttpsOnly", "yes" );
    }

    elsif ( $webmail eq "localnetworkSSL" ) {
      $cdb->set_prop('php',"status", "enabled" );
      $cdb->set_prop('mariadb',"status", "enabled" );
      $cdb->set_prop('imp',"status", 'enabled' );
      $cdb->set_prop('horde',"status", 'enabled' );
      $cdb->set_prop('imp',"access", "SSL" );
      $cdb->set_prop('horde',"access", "private" );
      $cdb->set_prop('horde',"HttpsOnly", "yes" );
     }

    else {
      $cdb->set_prop('imp',"status", 'disabled' );
      $cdb->set_prop('horde',"status", 'disabled' );
    }

    unless ( system( "/sbin/e-smith/signal-event", "email-update" ) == 0 ) {
	return $c->l('mai_ERROR_UPDATING_CONFIGURATION');
    }

    return 'OK';
}


sub change_settings_filtering {

    my $c = shift;

    my $virus_status = ( $c->param('VirusStatus') || 'disabled' );
    $cdb->set_prop("qpsmtpd", 'VirusScan', $virus_status);

    for my $param ( qw(
			status 
			Sensitivity
			TagLevel
			RejectLevel
			SortSpam 
                        Subject
			SubjectTag) )
    {
	$cdb->set_prop('spamassassin', $param, $c->param("Spam$param"));
    }

    my $patterns_status = $c->adjust_patterns() ? 'enabled' : 'disabled';
    $cdb->set_prop("qpsmtpd", 'PatternsScan', $patterns_status);

    unless ( system( "/sbin/e-smith/signal-event", "email-update" ) == 0 )
    {
	return $c->l('mai_ERROR_UPDATING_CONFIGURATION');
    }

    return 'OK';

}


#sub blank_or_ip_number {

#    my ($c, $value) = @_;

#    return 'OK' unless (defined $value); # undef is blank
#    return 'OK' if ($value =~ /^$/); # blank is blank
#    return $c->call_fm_validation("ip_number",$value,''); # otherwise, validate the input

#}


sub nonblank_if_smtpauth {

    my ($c, $value) = @_;

    return "OK" unless ($c->param("SMTPAUTHPROXY_status") eq 'enabled');

    return ($value =~ /\S+/) ? "OK" : $c->l('mai_VALIDATION_SMTPAUTH_NONBLANK');

}


sub get_secondary_mail_use_envelope {

    my $use_envelope = $cdb->get_prop('fetchmail', 'SecondaryMailEnvelope');
    if ( defined $use_envelope ) {
        return ('on');
    } else {
        return ('off');
    }
}


sub validate_smarthost {
    my $fm = shift;
    my $smarthost = shift;
    
    return ('OK') if ( $smarthost =~ /^(\S+\.\S+)$/ );

    return ('OK') if ( $smarthost eq '' );
    
    return "INVALID_SMARTHOST";
    
}


1;
