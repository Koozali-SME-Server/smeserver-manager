package SrvMngr::Controller::Remoteaccess;

#----------------------------------------------------------------------
# heading     : Network
# description : Remote access
# navigation  : 6000 400
#----------------------------------------------------------------------
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session ip_number subnet_mask get_reg_mask);

use esmith::ConfigDB;
use esmith::util;
use File::Basename;
use Exporter;
use Carp;
use Socket qw( inet_aton );

#our @ISA = qw(esmith::FormMagick Exporter);

our @EXPORT =
  qw( networkAccess_list passwordLogin_list get_ssh_permit_root_login get_ssh_access get_telnet_mode
  get_ftp_access  get_ftp_password_login_access
  get_value get_prop get_ssh_password_auth
  validate_network_and_mask ip_number_or_blank subnet_mask_or_blank
  get_ipsecrw_sessions pptp_and_dhcp_range
  );

#		get_pptp_sessions

our $db = esmith::ConfigDB->open || warn "Couldn't open configuration database";

sub main {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my $title     = $c->l('rma_FORM_TITLE');
    my $notif     = '';
    my %rma_datas = ();

	$db = esmith::ConfigDB->open || warn "Couldn't open configuration database";

    #$rma_datas{ipsecrwSess}  = $c->get_ipsecrw_sessions();
    #$rma_datas{pptpSessions} = $c->get_pptp_sessions();
    $rma_datas{sshAccess}                 = $c->get_ssh_access();
    $rma_datas{sshPermitRootLogin}        = $c->get_ssh_permit_root_login();
    $rma_datas{sshPasswordAuthentication} = $c->get_ssh_password_auth();
    $rma_datas{sshTCPPort}                = $c->get_ssh_port();
    $rma_datas{ftpAccess}                 = $c->get_ftp_access();
    $rma_datas{ftpPasswordAccess}         = $c->get_ftp_password_login_access();

    #$rma_datas{telnetAccess} = $c->get_telnet_access;

    $c->stash( title => $title, notif => $notif, rma_datas => \%rma_datas );
    $c->render( template => 'remoteaccess' );

}

sub do_action {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my $title = $c->l('rma_FORM_TITLE');
    my ( $result, $res, $trt ) = '';
    my %rma_datas = ();

	$db = esmith::ConfigDB->open || warn "Couldn't open configuration database";

    $rma_datas{ipsecrwSess}  = ( $c->param('IpsecrwSess')  || '' );
    $rma_datas{ipsecrwReset} = ( $c->param('IpsecrwReset') || '' );

    #$rma_datas{pptpSessions} = ($c->param ('PptpSessions') || '0');

    $rma_datas{validFromNetwork} = ( $c->param('ValidFromNetwork') || '' );
    $rma_datas{validFromMask}    = ( $c->param('ValidFromMask')    || '' );
##	my @remove = $q->param('validFromRemove');  ???????? the first one only !!
    my @vals = $c->param('Remove_nets');
    $rma_datas{remove_nets} = join ',', @vals;

    $rma_datas{sshaccess} = ( $c->param('SshAccess') || 'off' );
    $rma_datas{sshPermitRootLogin} =
      ( $c->param('SshPermitRootLogin') || 'no' );
    $rma_datas{sshPasswordAuthentication} =
      ( $c->param('SshPasswordAuthentication') || 'no' );
    $rma_datas{sshTCPPort} = ( $c->param('SshTCPPort') || '22' );

    $rma_datas{ftpAccess} = ( $c->param('FtpAccess') || 'off' );
    $rma_datas{ftpPasswordAccess} =
      ( $c->param('FtpPasswordAccess') || 'private' );

    $rma_datas{telnetAccess} = ( $c->param('TelnetAccess') || 'off' );

    # validate
    my $v = $c->validation;
    return $c->render('remoteaccess') unless $v->has_data;

    #$v->optional('PptpSessions')->num(0, 999)->is_valid;
    if ( $c->param('ValidFromNetwork') ne "" ) {
        $v->optional('ValidFromNetwork')->size( 7, 15 )->is_valid;
    }
    if ( $c->param('ValidFromMask') ne "" ) {
        $v->optional('ValidFromMask')->size( 7, 15 )->is_valid;
    }
    $v->required('SshTCPPort')->num( 1, 65535 )->is_valid;

    $result .= 'field validation error' if $v->has_error;

    if ( !$result ) {

        # controls
        #$res = pptp_and_dhcp_range( $c, $rma_datas{pptpSessions} );
        #$result .= $res . ' ' unless $res eq 'OK';

        $res = ip_number_or_blank( $c, $rma_datas{validFromNetwork} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = subnet_mask_or_blank( $c, $rma_datas{validFromMask} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = validate_network_and_mask(
            $c,
            $rma_datas{validFromNetwork},
            $rma_datas{validFromMask}
        );
        $result .= $res . ' ' unless $res eq 'OK';

        #$result .= ' blocked for testing !' . $rma_datas{remove_nets};
    }

    if ( !$result ) {
        $res = change_settings( $c, %rma_datas );
        $result .= $res unless $res eq 'OK';
    }
    
    if ( $result eq "" ) {
        $result = $c->l('rma_SUCCESS');
        $trt    = 'SUC';
    }
    $c->stash( title => $title, notif => $result, rma_datas => \%rma_datas );

    #return $c->render( template => 'remoteaccess' );

    if ( $trt eq 'SUC' ) {
		$c->stash( title => $title,modul => $result);
        return $c->render( template => 'module' );
    }

    return $c->render( template => 'remoteaccess' );
    #$c->redirect_to('/remoteaccess');

}

sub networkAccess_list {
    my $c = shift;
    return [
        [ $c->l('rma_NO_ACCESS')         => 'off' ],
        [ $c->l('NETWORKS_ALLOW_LOCAL')  => 'private' ],
        [ $c->l('NETWORKS_ALLOW_PUBLIC') => 'public' ]
    ];
}

sub passwordLogin_list {
    my $c = shift;
    return [
        [ $c->l('rma_PASSWORD_LOGIN_PRIVATE') => 'private' ],
        [ $c->l('rma_PASSWORD_LOGIN_PUBLIC')  => 'public' ]
    ];
}

sub get_prop {

    my ( $c, $item, $prop ) = @_;
    warn "You must specify a record key"    unless $item;
    warn "You must specify a property name" unless $prop;
    my $record = $db->get($item) or warn "Couldn't get record for $item";
    return $record ? $record->prop($prop) : undef;
}

sub get_value {

    my $c    = shift;
    my $item = shift;
    return ( $db->get($item)->value() );
}

sub get_ftp_access {

    my $status = get_prop( '', 'ftp', 'status' ) || 'disabled';
    return 'off' unless $status eq 'enabled';

    my $access = get_prop( '', 'ftp', 'access' ) || 'private';
    return ( $access eq 'public' ) ? 'normal' : 'private';
}

#sub get_pptp_sessions {
#  my $status = get_prop('','pptpd','status');
#  if (defined($status) && ($status eq 'enabled')) {
#    return(get_prop('','pptpd','sessions') || 'no');
#  return '0';
#}

sub get_ssh_permit_root_login {
    return ( get_prop( '', 'sshd', 'PermitRootLogin' ) || 'no' );
}

sub get_ssh_password_auth {
    return ( get_prop( '', 'sshd', 'PasswordAuthentication' ) || 'yes' );
}

sub get_ssh_access {

    my $status = get_prop( '', 'sshd', 'status' );
    if ( defined($status) && ( $status eq 'enabled' ) ) {
        my $access = get_prop( '', 'sshd', 'access' );
        $access = ( $access eq 'public' ) ? 'public' : 'private';
        return ($access);
    }
    else {
        return ('off');
    }
}

sub get_ssh_port {
    return ( get_prop( '$c', 'sshd', 'TCPPort' ) || '22' );
}

sub get_ftp_password_login_access {

    my $status = get_prop( '', 'ftp', 'status' ) || 'disabled';
    return 'private' unless $status eq 'enabled';

    my $access = get_prop( '', 'ftp', 'LoginAccess' ) || 'private';

    return ( $access eq 'public' ) ? 'public' : 'private';
}

sub get_telnet_mode {

    my $telnet = $db->get('telnet');
    return ('off') unless $telnet;
    my $status = $telnet->prop('status') || 'disabled';
    return ('off') unless $status eq 'enabled';
    my $access = $telnet->prop('access') || 'private';
    return ( $access eq "public" ) ? "public" : "private";
}

sub get_ipsecrw_sessions {

    my $status = $db->get('ipsec')->prop('RoadWarriorStatus');
    if ( defined($status) && ( $status eq 'enabled' ) ) {
        return ( $db->get('ipsec')->prop('RoadWarriorSessions') || '0' );
    }
    else {
        return ('0');
    }
}

sub get_ipsecrw_status {

    return undef unless ( $db->get('ipsec') );
    return $db->get('ipsec')->prop('RoadWarriorStatus');

}

sub pptp_and_dhcp_range {

    my $c           = shift;
    my $val         = shift || 0;
    my $dhcp_status = $db->get_prop( 'dhcpd', 'status' ) || 'disabled';
    my $dhcp_end    = $db->get_prop( 'dhcpd', 'end' )    || '';
    my $dhcp_start  = $db->get_prop( 'dhcpd', 'start' )  || '';

    if ( $dhcp_status eq 'enabled' ) {
        my $ip_start = unpack 'N', inet_aton($dhcp_start);
        my $ip_end   = unpack 'N', inet_aton($dhcp_end);
        my $ip_count = $ip_end - $ip_start;
        return 'OK' if ( $val < $ip_count );
        return $c->l(
'rma_NUMBER_OF_PPTP_CLIENTS_MUST_BE_LESSER_THAN_NUMBER_OF_IP_IN_DHCP_RANGE'
        );
    }
    else {
        return 'OK';
    }
}

sub _get_valid_from {

    my $c = shift;

    my $rec = $db->get('httpd-admin');
    return undef unless ($rec);
    my @vals = ( split ',', ( $rec->prop('ValidFrom') || '' ) );
    return @vals;
}

sub ip_number_or_blank {

    my $c  = shift;
    my $ip = shift;

    if ( !defined($ip) || $ip eq "" ) {
        return 'OK';
    }
    return ip_number( $c, $ip );
}

sub subnet_mask_or_blank {

    my $c    = shift;
    my $mask = shift;

    if ( !defined($mask) || $mask eq "" ) {
        return "OK";
    }

    chomp $mask;

    return ( subnet_mask($mask) ne 'OK' )
      ? $c->l('rma_INVALID_SUBNET_MASK') . " (" . $mask . ")"
      : 'OK';
}

sub validate_network_and_mask {

    my $c    = shift;
    my $net  = shift || "";
    my $mask = shift || "";

    if ( $net xor $mask ) {
        return $c->l(
            'rma_ERR_INVALID_PARAMS' . " (" . $net . "/" . $mask . ")" );
    }
    return 'OK';
}

sub change_settings {

    my ( $c, %rma_datas ) = @_;

    #------------------------------------------------------------
    # good; go ahead and change the access.
    #------------------------------------------------------------

    my $rec = $db->get('telnet');
    if ($rec) {
        if ( $rma_datas{telnetAccess} eq "off" ) {
            $rec->set_prop( 'status', 'disabled' );
        }
        else {
            $rec->set_prop( 'status', 'enabled' );
            $rec->set_prop( 'access', $rma_datas{telnetAccess} );
        }
    }

    $rec = $db->get('sshd') || $db->new_record( 'sshd', { type => 'service' } );
    $rec->set_prop( 'TCPPort', $rma_datas{sshTCPPort} );
    $rec->set_prop( 'status',
        ( $rma_datas{sshaccess} eq "off" ? 'disabled' : 'enabled' ) );
    $rec->set_prop( 'access',          $rma_datas{sshaccess} );
    $rec->set_prop( 'PermitRootLogin', $rma_datas{sshPermitRootLogin} );
    $rec->set_prop( 'PasswordAuthentication',
        $rma_datas{sshPasswordAuthentication} );

    $rec = $db->get('ftp');
    if ($rec) {
        if ( $rma_datas{ftpAccess} eq "off" ) {
            $rec->set_prop( 'status',      'disabled' );
            $rec->set_prop( 'access',      'private' );
            $rec->set_prop( 'LoginAccess', 'private' );
        }
        elsif ( $rma_datas{ftpAccess} eq "normal" ) {
            $rec->set_prop( 'status',      'enabled' );
            $rec->set_prop( 'access',      'public' );
            $rec->set_prop( 'LoginAccess', $rma_datas{ftpPasswordAccess} );
        }
        else {
            $rec->set_prop( 'status',      'enabled' );
            $rec->set_prop( 'access',      'private' );
            $rec->set_prop( 'LoginAccess', $rma_datas{ftpPasswordAccess} );
        }
    }

    #	if ($rma_datas{pptpSessions} == 0) {
    #	$db->get('pptpd')->set_prop('status', 'disabled');
    #    } else {
    #	$db->get('pptpd')->set_prop('status', 'enabled');
    #	$db->get('pptpd')->set_prop('sessions', $rma_datas{pptpSessions});
    #    }

    if ( $rma_datas{validFromNetwork} && $rma_datas{validFromMask} ) {
        unless (
            add_new_valid_from(
                $c,
                $rma_datas{validFromNetwork},
                $rma_datas{validFromMask}
            )
          )
        {
            return $c->l('rma_ERROR_UPDATING_CONFIGURATION') . 'new net';
        }
    }

    if ( $rma_datas{remove_nets} ) {
        unless ( remove_valid_from( $c, $rma_datas{remove_nets} ) ) {
            return $c->l('rma_ERROR_UPDATING_CONFIGURATION') . 'del net';
        }
    }

    # reset ipsec roadwarrior CA,server,client certificates
    if ( $rma_datas{ipsecrwReset} ) {
        system( '/sbin/e-smith/roadwarrior', 'reset_certs' ) == 0
          or return $c->l('rma_ERROR_UPDATING_CONFIGURATION') . 'rst ipsec';
    }

    if ( $rma_datas{ipsecrwSess} ) {
        set_ipsecrw_sessions( $c, $rma_datas{ipsecrwSess} );
    }

    unless (
        system( "/sbin/e-smith/signal-event", "remoteaccess-update" ) == 0 )
    {
        return $c->l('rma_ERROR_UPDATING_CONFIGURATION');
    }

    return 'OK';
}

sub set_ipsecrw_sessions {

    my $c        = shift;
    my $sessions = shift;

    if ( defined $sessions ) {
        $db->get('ipsec')->set_prop( 'RoadWarriorSessions', $sessions );
        if ( int($sessions) > 0 ) {
            $db->get('ipsec')->set_prop( 'RoadWarriorStatus', 'enabled' );
        }
    }
    return '';
}

sub add_new_valid_from {

    my $c    = shift;
    my $net  = shift;
    my $mask = shift;

    # we transform bit mask to regular mask
    $mask = get_reg_mask( $net, $mask );

    my $rec = $db->get('httpd-admin');
    return $c->error('ERR_NO_RECORD') unless $rec;

    my $prop = $rec->prop('ValidFrom') || '';

    my @vals = split /,/, $prop;
    return '' if ( grep /^$net\/$mask$/, @vals );    # already have this entry

    if ( $prop ne '' ) {
        $prop .= ",$net/$mask";
    }
    else {
        $prop = "$net/$mask";
    }

    $rec->set_prop( 'ValidFrom', $prop );

    return 1;
}

sub remove_valid_from {

    my $c           = shift;
    my $remove_nets = shift;

    my @remove = split /,/, $remove_nets;

    #	my @remove = $c->param('Remove_nets');
    my @vals = $c->_get_valid_from();

    foreach my $entry (@remove) {

        return undef unless $entry;

        my ( $net, $mask ) = split( /\//, $entry );

        unless (@vals) {
            print STDERR
              "ERROR: unable to load ValidFrom property from conf db\n";
            return undef;
        }

        # what if we don't have a mask because someone added an entry from
        # the command line? by the time we get here, the panel will have
        # added a 32 bit mask, so we don't know for sure if the value in db
        # is $net alone or $net/255.255.255.255. we have to check for both
        # in this special case...
        @vals = ( grep { $entry ne $_ && $net ne $_ } @vals );
    }

    my $prop;
    if (@vals) {
        $prop = join ',', @vals;
    }
    else {
        $prop = '';
    }

    $db->get('httpd-admin')->set_prop( 'ValidFrom', $prop );

    return 1;
}

1;