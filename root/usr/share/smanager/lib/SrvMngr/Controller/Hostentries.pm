package SrvMngr::Controller::Hostentries;

#----------------------------------------------------------------------
# heading     : Network
# description : Hostnames and addresses
# navigation  : 6000 200
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

#use esmith::FormMagick::Panel::hostentries;

use esmith::DomainsDB;
use esmith::AccountsDB;
use esmith::HostsDB;
use esmith::NetworksDB;
use HTML::Entities;
use Net::IPv4Addr qw(ipv4_in_network);

#use URI::Escape;

our $ddb = esmith::DomainsDB->open  || die "Couldn't open hostentries db";
our $cdb = esmith::ConfigDB->open   || die "Couldn't open configuration db";
our $hdb = esmith::HostsDB->open    || die "Couldn't open hosts db";
our $ndb = esmith::NetworksDB->open || die "Couldn't open networks db";

sub main {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my %hos_datas = ();
    my $title     = $c->l('hos_FORM_TITLE');
    my $notif     = '';

    $hos_datas{trt} = 'LIST';

    my %dom_hosts = ();

    foreach my $d ( @{ domains_list() } ) {
        $dom_hosts{$d} = { COUNT => 0, HOSTS => [] };

        if ( my @hosts = $hdb->get_hosts_by_domain($d) ) {
            $dom_hosts{$d}{'COUNT'} = scalar(@hosts);

            #    my @entries;
            push @{ $dom_hosts{$d}{'HOSTS'} }, host_data($_) foreach (@hosts);
        }
    }

    $c->stash(
        title     => $title,
        notif     => $notif,
        hos_datas => \%hos_datas,
        dom_hosts => \%dom_hosts
    );
    $c->render( template => 'hostentries' );

}

sub do_display {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my $rt       = $c->current_route;
    my $trt      = $c->param('trt') || 'LST';
    my $hostname = $c->param('Hostname') || '';

    $trt = 'ADD' if ( $rt eq 'hostentryadd' );
    $trt = 'LST' if ( $trt ne 'DEL' && $trt ne 'UPD' && $trt ne 'ADD' );

    my %hos_datas = ();
    my $title     = $c->l('hos_FORM_TITLE');
    my $notif     = '';

    $hos_datas{'trt'} = $trt;

    if ( $trt eq 'ADD' ) {

    }

    if ( $trt eq 'UPD' or $trt eq 'DEL' ) {

        my $rec = $hdb->get($hostname);
        if ($rec) {
            $hos_datas{hostname} = $rec->key;
            ( $hos_datas{name}, $hos_datas{domain} ) =
              split_hostname($hostname);
            $hos_datas{internalip} = $rec->prop('InternalIP') || '';
            $hos_datas{externalip} = $rec->prop('ExternalIP') || '';
            $hos_datas{macaddress} = $rec->prop('MACAddress') || '';
            $hos_datas{hosttype}   = $rec->prop('HostType');
            $hos_datas{comment} =
              HTML::Entities::encode( $rec->prop('Comment') );
        }
        else {
            $notif = "Hostname $hostname not found !";
        }
    }

    #if ( $trt eq 'DEL' ) {

    #    my $rec = $hdb->get($hostname);
    #    if ( $rec ) {
    #	get_hos_datas( $rec, %hos_datas );
    #    } else {
    #	$notif = "Hostname $hostname not found !"
    #    }
    #}

    if ( $trt eq 'LIST' ) {

    }

    $c->stash( title => $title, notif => $notif, hos_datas => \%hos_datas );
    $c->render( template => 'hostentries' );

}

sub do_update {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my $rt = $c->current_route;
    my $trt = ( $c->param('trt') || 'LIST' );

    my %hos_datas = ();
    my $title     = $c->l('hos_FORM_TITLE');
    my $notif     = '';
    my $result    = '';

    $hos_datas{'name'}       = lc $c->param('Name');
    $hos_datas{'domain'}     = lc $c->param('Domain');
    $hos_datas{'hostname'}   = $c->param('Hostname');
    $hos_datas{'comment'}    = $c->param('Comment');
    $hos_datas{'hosttype'}   = $c->param('Hosttype');
    $hos_datas{'internalip'} = $c->param('Internalip');
    $hos_datas{'macaddress'} = $c->param('Macaddress');
    $hos_datas{'externalip'} = $c->param('Externalip');
    my $hostname = "$hos_datas{'name'}.$hos_datas{'domain'}";
    if ( $trt eq 'ADD' ) {
		
		$hos_datas{'hostname'} = $hostname;

        # controls
        my $res = '';
        unless ( $hos_datas{'name'} =~ /^[a-z0-9][a-z0-9-]*$/ ) {
            $result .= $c->l('hos_HOSTNAME_VALIDATOR_ERROR') . '<br>';
        }

        unless ( $hos_datas{comment} =~ /^([a-zA-Z0-9][\_\.\-,A-Za-z0-9\s]*)$/
            || $hos_datas{comment} eq '' )
        {
            $result .= $c->l('hos_HOSTNAME_COMMENT_ERROR') . '<br>';
        }

        # Look for duplicate hosts.
        my $hostrec = undef;
        if ( $hostrec = $hdb->get($hostname) ) {
            $result .= $c->l(
                'hos_HOSTNAME_EXISTS_ERROR',
                {
                    fullHostName => $hostname,
                    type         => $hostrec->prop('HostType')
                }
            ) . '<br>',;
        }

        if ( !$result and $hos_datas{hosttype} ne 'Self' ) {
            if ( $hos_datas{hosttype} eq 'Local' ) {
                $hos_datas{'trt'} = 'ALC';    # ADD/LOCAL
            }
            else {
                $hos_datas{'trt'} = 'ARM';    # ADD/REMOVE
            }

            $c->stash( title => $title, notif => '', hos_datas => \%hos_datas );
            return $c->render( template => 'hostentries' );
        }

        #!#$result .= ' blocked';

        if ( !$result ) {
            $res = create_modify_hostentry( $c, $trt, %hos_datas );
            $result .= $res unless $res eq 'OK';
        }
        if ( !$result ) {
            $result = $c->l('hos_CREATE_OR_MODIFY_SUCCEEDED') . ' ' . $hostname;
            $trt    = 'SUC';
        }
    }

    if ( $trt eq 'UPD' ) {

        # controls
        my $res = '';

        #$res = validate_description( $c, $account );
        #$result .= $res unless $res eq 'OK';

        unless ( $hos_datas{comment} =~ /^([a-zA-Z0-9][\_\.\-,A-Za-z0-9\s]*)$/
            || $hos_datas{comment} eq '' )
        {
            $result .= $c->l('hos_HOSTNAME_COMMENT_ERROR') . '<br>';
        }

        if ( !$result and $hos_datas{hosttype} ne 'Self' ) {
            if ( $hos_datas{hosttype} eq 'Local' ) {
                $hos_datas{'trt'} = 'ULC';    # UPDATE/LOCAL
            }
            else {
                $hos_datas{'trt'} = 'URM';    # UPDATE/REMOVE
            }

            $c->stash( title => $title, notif => '', hos_datas => \%hos_datas );
            return $c->render( template => 'hostentries' );
        }

        #!#$result .= 'blocked';

        if ( !$result ) {
            $res = create_modify_hostentry( $c, $trt, %hos_datas );
            $result .= $res unless $res eq 'OK';
        }

        if ( !$result ) {
            $result = $c->l('hos_MODIFY_SUCCEEDED') . ' ' . $hostname;
            $trt    = 'SUC';
        }
    }

    if ( $trt =~ /^.LC$/ ) {

        # controls
        my $res = '';
        $res = ip_number( $c, $hos_datas{internalip} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = not_in_dhcp_range( $c, $hos_datas{internalip} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = not_taken( $c, $hos_datas{internalip} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = must_be_local( $c, $hos_datas{internalip} );
        $result .= $res . ' ' unless $res eq 'OK';

        $res = mac_address_or_blank( $c, $hos_datas{macaddress} );
        $result .= $res . ' ' unless $res eq 'OK';

        #!#$result .= 'blocked';

        if ( !$result ) {
            $res = create_modify_hostentry( $c, $trt, %hos_datas );
            $result .= $res unless $res eq 'OK';
        }

        if ( !$result ) {
            $result = $c->l('hos_MODIFY_SUCCEEDED') . ' ' . $hostname;
            $trt    = 'SUC';
        }
    }

    if ( $trt =~ /^.RM$/ ) {

        # controls
        my $res = '';
        $res = ip_number_or_blank( $c, $hos_datas{externalip} );
        $result .= $res . '<br>' unless $res eq 'OK';

        #!#$result .= 'blocked';

        if ( !$result ) {
            $res = create_modify_hostentry( $c, $trt, %hos_datas );
            $result .= $res unless $res eq 'OK';
        }

        if ( !$result ) {
            $result = $c->l('hos_MODIFY_SUCCEEDED') . ' ' . $hostname;
            $trt    = 'SUC';
        }

    }

    #if ( $trt eq 'ULC' ) {
    #}

    #if ( $trt eq 'URM' ) {
    #}

    if ( $trt eq 'DEL' ) {

        # controls
        my $res = '';

        #$res = validate_is_hostentry($c, $hostname);
        #$result .= $res unless $res eq 'OK';

        #!#$result .= 'blocked';

        if ( !$result ) {
            my $res = delete_hostentry( $c, $hos_datas{hostname} );
            $result .= $res unless $res eq 'OK';
        }
        if ( !$result ) {
            $result = $c->l('hos_REMOVE_SUCCEEDED') . ' ' . $hostname;
            $trt    = 'SUC';
        }
    }

    $hos_datas{'hostname'} = $hostname;
    $hos_datas{'trt'}      = $trt;

    $c->stash( title => $title, notif => $result, hos_datas => \%hos_datas );

    if ( $hos_datas{trt} ne 'SUC' ) {
        return $c->render( template => 'hostentries' );
    }
    $c->redirect_to('/hostentries');

}

sub create_modify_hostentry {

    my ( $c, $trt, %hos_datas ) = @_;

    my $hostname = $hos_datas{hostname};
    my $action;

    if ( $trt eq 'ADD' or $trt eq 'ALC' or $trt eq 'ARM' ) {
        $action = 'create';
    }
    if ( $trt eq 'UPD' or $trt eq 'ULC' or $trt eq 'URM' ) {
        $action = 'modify';
    }

    unless ($hostname) {
        return $c->l(
              $action eq 'create'
            ? $c->l('hos_ERROR_CREATING_HOST')
            : $c->l('hos_ERROR_MODIFYING_HOST')
        );
    }

    # Untaint and lowercase $hostname
    $hostname =~ /([\w\.-]+)/;
    $hostname = lc($1);

    my $rec = $hdb->get($hostname);
    if ( $rec and $action eq 'create' ) {
        return $c->l('hos_HOSTNAME_IN_USE_ERROR');
    }
    if ( not $rec and $action eq 'modify' ) {
        return $c->l('hos_NONEXISTENT_HOSTNAME_ERROR');
    }

    my %props = (
        type       => 'host',
        HostType   => $hos_datas{hosttype},
        ExternalIP => $hos_datas{externalip},
        InternalIP => $hos_datas{internalip},
        MACAddress => $hos_datas{macaddress},
        Comment    => $hos_datas{comment},
    );

    if ( $action eq 'create' ) {
        if ( $hdb->new_record( $hostname, \%props ) ) {
            if (
                system( "/sbin/e-smith/signal-event", "host-$action",
                    $hostname ) != 0
              )
            {
                return $c->l('hos_ERROR_WHILE_CREATING_HOST');
            }
        }
    }

    if ( $action eq 'modify' ) {
        if ( $rec->merge_props(%props) ) {
            if (
                system( "/sbin/e-smith/signal-event", "host-$action",
                    $hostname ) != 0
              )
            {
                rturn $c->l('hos_ERROR_WHILE_MODIFYING_HOST');
            }
        }
    }
    return 'OK';

}

sub delete_hostentry {

    my ( $c, $hostname ) = @_;

    # Untaint $hostname before use in system()
    $hostname =~ /([\w\.-]+)/;
    $hostname = $1;

    return ( $c->l('hos_ERROR_WHILE_REMOVING_HOST') ) unless ($hostname);

    my $rec = $hdb->get($hostname);
    return ( $c->l('hos_NONEXISTENT_HOST_ERROR') ) if ( not $rec );

    if ( $rec->delete() ) {
        if (
            system( "/sbin/e-smith/signal-event", "host-delete", "$hostname" )
            == 0 )
        {
            return 'OK';
        }
    }
    return ( $c->l('hos_ERROR_WHILE_DELETING_HOST') );
}

sub domains_list {

    my $d = esmith::DomainsDB->open_ro() or die "Couldn't open DomainsDB";
    my @domains;
    for ( $d->domains ) {
        my $ns = $_->prop("Nameservers") || 'localhost';
        push @domains, $_->key if ( $ns eq 'localhost' );
    }

    return \@domains;
}

sub host_data {

    my $host_record = shift;

    my $ht = $host_record->prop('HostType');
    my $ip =
        ( $ht eq 'Self' )   ? $cdb->get_value('LocalIP')
      : ( $ht eq 'Remote' ) ? $host_record->prop('ExternalIP')
      :                       $host_record->prop('InternalIP');

    my %data = (
        'IP'         => $ip,
        'HostName'   => $host_record->key(),
        'HostType'   => $host_record->prop('HostType'),
        'MACAddress' => ( $host_record->prop('MACAddress') || '' ),
        'Comment'    => ( $host_record->prop('Comment') || '' ),
        'static'     => ( $host_record->prop('static') || 'no' )
    );
    return \%data

}

sub hosttype_list {

    my $c = shift;

    return [
        [ $c->l('SELF')   => 'Self' ],
        [ $c->l('LOCAL')  => 'Local' ],
        [ $c->l('REMOTE') => 'Remote' ]
    ];
}

sub split_hostname {
    my $hostname = shift;
    return ( $hostname =~ /^([^\.]+)\.(.+)$/ );
}

sub mac_address_or_blank {
    my ( $c, $data ) = @_;
    return "OK" unless $data;
    return mac_address( $c, $data );
}

sub mac_address {

    #	from CGI::FormMagick::Validator::Network

    my ( $c, $data ) = @_;

    $_ = lc $data;    # easier to match on $_
    if ( not defined $_ ) {
        return $c->l('FM_MAC_ADDRESS1');
    }
    elsif (/^([0-9a-f][0-9a-f](:[0-9a-f][0-9a-f]){5})$/) {
        return "OK";
    }
    else {
        return $c->l('FM_MAC_ADDRESS2');
    }
}

sub ip_number_or_blank {

    # XXX - FIXME - we should push this down into CGI::FormMagick

    my $c  = shift;
    my $ip = shift;

    if ( !defined($ip) || $ip eq "" ) {
        return 'OK';
    }

    return ip_number( $c, $ip );
}

sub ip_number {

    #  from CGI::FormMagick::Validator qw( ip_number );

    my ( $c, $data ) = @_;

    return undef unless defined $data;

    return $c->l('FM_IP_NUMBER1') unless $data =~ /^[\d.]+$/;

    my @octets = split /\./, $data;
    my $dots = ( $data =~ tr/.// );

    return $c->l('FM_IP_NUMBER2') unless ( scalar @octets == 4 and $dots == 3 );

    foreach my $octet (@octets) {
        return $c->l( "FM_IP_NUMBER3", $octet ) if $octet > 255;
    }

    return 'OK';
}

sub not_in_dhcp_range {

    my $c       = shift;
    my $address = shift;

    my $status = $cdb->get('dhcpd')->prop('status') || "disabled";
    return 'OK' unless $status eq "enabled";

    my $start = $cdb->get('dhcpd')->prop('start');
    my $end   = $cdb->get('dhcpd')->prop('end');

    return ( esmith::util::IPquadToAddr($start) <=
             esmith::util::IPquadToAddr($address)
          && esmith::util::IPquadToAddr($address) <=
          esmith::util::IPquadToAddr($end) )
      ? $c->l('hos_ADDR_IN_DHCP_RANGE')
      : 'OK';
}

sub not_taken {

    my $c       = shift;
    my $localip = shift;

    my $server_localip = $cdb->get_value('LocalIP')    || '';
    my $server_gateway = $cdb->get_value('GatewayIP')  || '';
    my $server_extip   = $cdb->get_value('ExternalIP') || '';

    #$c->debug_msg("\$localip is $localip");
    #$c->debug_msg("\$server_localip is $server_localip");
    #$c->debug_msg("\$server_gateway is $server_gateway");
    #$c->debug_msg("\$server_extip is $server_extip");

    if ( $localip eq $server_localip ) {
        return $c->l('hos_ERR_IP_IS_LOCAL_OR_GATEWAY');
    }

    if ( $localip eq $server_gateway ) {
        return $c->l('hos_ERR_IP_IS_LOCAL_OR_GATEWAY');
    }

    if (   ( $cdb->get_value('SystemMode') ne 'serveronly' )
        && ( $server_extip eq $localip ) )
    {
        return $c->l('hos_ERR_IP_IS_LOCAL_OR_GATEWAY');
    }

    if ( $localip eq '127.0.0.1' ) {
        return $c->l('hos_ERR_IP_IS_LOCAL_OR_GATEWAY');
    }
    else {
        return 'OK';
    }
}

sub must_be_local {

    my $c       = shift;
    my $localip = shift;

    # Make sure that the IP is indeed local.
    #my $ndb = esmith::NetworksDB->open_ro;
    my @local_list = $ndb->local_access_spec;

    foreach my $spec (@local_list) {
        next if $spec eq '127.0.0.1';
        if ( eval { Net::IPv4Addr::ipv4_in_network( $spec, $localip ) } ) {
            return 'OK';
        }
    }

    # Not OK. The IP is not on any of our local networks.
    return $c->l('hos_ERR_IP_NOT_LOCAL');
}

1;
