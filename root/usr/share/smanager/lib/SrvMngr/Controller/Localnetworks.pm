package SrvMngr::Controller::Localnetworks;

#----------------------------------------------------------------------
# heading     : Network
# description : Local networks
# navigation  : 6000 500
# 
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session subnet_mask get_reg_mask ip_number);

#use Data::Dumper;
use esmith::util;
use esmith::HostsDB;

my $network_db = esmith::NetworksDB->open() || die("Couldn't open networks db");
my $ret = "OK";

sub main {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my %ln_datas = ();
    $ln_datas{return} = "";
    my $title = $c->l('ln_LOCAL NETWORKS');
    my $modul = '';

    $ln_datas{trt} = 'LIST';

    my @localnetworks;
    if ($network_db) {
        @localnetworks = $network_db->get_all_by_prop( type => 'network' );
    }

    $c->stash(
        title         => $title,
        modul         => $modul,
        ln_datas      => \%ln_datas,
        localnetworks => \@localnetworks
    );
    $c->render( template => 'localnetworks' );

}

sub do_display {

    my $c = shift;
    $c->app->log->info( $c->log_req );

    my $rt           = $c->current_route;
    my $trt          = ( $c->param('trt') || 'LIST' );

    $trt = 'DEL'  if ( $rt eq 'localnetworksdel' );
    $trt = 'ADD'  if ( $rt eq 'localnetworksadd' );
    $trt = 'ADD1'  if ( $rt eq 'localnetworksadd1' );
    $trt = 'DEL1' if ( $rt eq 'localnetworksdel1' );

    my %ln_datas = ();
    my $title    = $c->l('ln_LOCAL NETWORKS');
    my $modul    = '';

 
    if ( $trt eq 'ADD' ) {
		#Add a network - called from the list panel
		# Nothing to do here...as just need fields to input data.

    }

   if ( $trt eq 'ADD1' ) {
		#Add a network - called after new network details filled in
        my %ret = add_network($c);	
        #Return to list page if success	
        if ((index($ret{ret},"SUCCESS") != -1))  {
			$trt = "LIST";
		} else {
			#Error - return to Add page
			$trt = "ADD";
		}	
        $network_db = esmith::NetworksDB->open() || die("Failed to open Networkdb-3");  #Refresh the network DB 
		$c->stash(ret=>\%ret);	 #stash it away for the template
    }

    if ( $trt eq 'DEL1' ) {
		#After Remove clicked on Delete network panel
        my $network_db = esmith::NetworksDB->open() || die("Failed to open Networkdb-1");
        my $localnetwork = $c->param("localnetwork");
        my $delete_hosts = $c->param("deletehost")||"1";  #default to deleting them.
	    my $rec = $network_db->get($localnetwork)||die("Failed to find network on db:$localnetwork");
        if ( $rec and $rec->prop('type') eq 'localnetwork' ) {
            $ln_datas{localnetwork} = $localnetwork;
        }
        my %ret = remove_network($localnetwork,$delete_hosts);
        
        $network_db = esmith::NetworksDB->open() || die("Failed to open Networkdb-2");  #Refresh the network DB 
        my @localnetworks;
        if ($network_db) {
            @localnetworks = $network_db->get_all_by_prop( type => 'network' );
        }
        # Load up ln_datas with values need by template
		$ln_datas{subnet}      = $rec->prop('Mask');
		$ln_datas{router}      = $rec->prop('Router');
        $c->stash( ln_datas => \%ln_datas, localnetworks => \@localnetworks ,ret =>\%ret);
    }

    if ( $trt eq 'DEL' ) {
		#Initial delete panel requiring confirmation
    	my $localnetwork = $c->param("localnetwork") || '';
    	$c->stash(localnetwork=>$localnetwork);
        my $rec = $network_db->get($localnetwork) || die("Failed to get local network in db::$localnetwork");
        my $subnet = $rec->prop('Mask');
        $ln_datas{subnet} = $subnet;
        $ln_datas{router} = $rec->prop('Router');
        my $numhosts = hosts_on_network($localnetwork,$subnet);
        $ln_datas{localnetwork} = $localnetwork;
        $ln_datas{deletehosts} = $numhosts>0?1:0;
     }

    if ( $trt eq 'LIST' ) {
		#List all the networks
        my @localnetworks;
        if ($network_db) {
            @localnetworks = $network_db->get_all_by_prop( type => 'network' );
        }
        $c->stash( localnetworks => \@localnetworks );
	## $c->redirect_to('/localnetworks');
    }

    $ln_datas{'trt'} = $trt;
    $c->stash( title => $title, modul => $modul, ln_datas => \%ln_datas );
    $c->render( template => 'localnetworks' );

}

sub remove_network {
    my $network    = shift; 	
    my $network_db = esmith::NetworksDB->open();
    my $record     = $network_db->get($network);
    my $delete_hosts = shift;    

    if ( my $record = $network_db->get($network) ) {
        my $subnet = $record->prop('Mask');
        my $router = $record->prop('Router');
        $record->set_prop( type => 'network-deleted' );

        # Untaint $network before use in system()
        $network =~ /(.+)/;
        $network = $1;
        if ( system( "/sbin/e-smith/signal-event", "network-delete", $network )  == 0 )   {
            if ($delete_hosts) {
                my @hosts_to_delete = hosts_on_network( $network, $subnet );
                foreach my $host (@hosts_to_delete) {
                    $host->delete;
                }
            }
            $record->delete;
            return (ret=>'ln_SUCCESS_REMOVED_NETWORK',vars=>"$network,$subnet,$router");
        }
        else {
            return (ret=>"ln_ERROR_DELETING_NETWORK");
        }
    }
    else {
        return (ret=>"ln_NO_SUCH_NETWORK");
    }
}

sub hosts_on_network {
    my $network = shift;
    my $netmask = shift;

    die if not $network and $netmask;

    my $cidr       = "$network/$netmask";
    my $hosts      = esmith::HostsDB->open() || die("Couldn't open hosts db");
    my @localhosts = grep { $_->prop('HostType') eq 'Local' } $hosts->hosts;
    my @hosts_on_network = ();
    foreach my $host (@localhosts) {
        my $ip = $host->prop('InternalIP') || "";
        if ($ip) {
            if ( Net::IPv4Addr::ipv4_in_network( $cidr, $ip ) ) {
                push @hosts_on_network, $host;
            }
        }
    }
    return @hosts_on_network if wantarray;
    return scalar @hosts_on_network;
}

sub add_network
{
    my ($fm)           = @_;
    my $networkAddress = $fm->param('networkAddress');
    my $networkMask    = $fm->param('networkMask');
    my $networkRouter  = $fm->param('networkRouter');

    #Validate Ips and subnet mask

    my $res = ip_number($fm, $networkAddress);
    return (ret=>'ln_INVALID_IP_ADDRESS', vars=>"Network Address $res") unless $res eq 'OK';

    $res = subnet_mask( $networkMask );
    return (ret=>'ln_INVALID_SUBNET_MASK', vars=>"$networkMask" ) unless $res eq 'OK';

    $res = ip_number($fm, $networkRouter);
    return (ret=>'ln_INVALID_IP_ADDRESS' , vars=>"Routeur Address $res") unless $res eq 'OK';

    # we transform bit mask to regular mask
    $networkMask = get_reg_mask( $networkAddress, $networkMask );

    my $network_db = esmith::NetworksDB->open()
      || esmith::NetworksDB->create();
    my $config_db = esmith::ConfigDB->open();

    my $localIP      = $config_db->get('LocalIP');
    my $localNetmask = $config_db->get('LocalNetmask');

    my ( $localNetwork, $localBroadcast ) =
      esmith::util::computeNetworkAndBroadcast( $localIP->value(),
        $localNetmask->value() );

    my ( $routerNetwork, $routerBroadcast ) =
      esmith::util::computeNetworkAndBroadcast( $networkRouter,
        $localNetmask->value() );

    # Note to self or future developers:
    # the following tests should probably be validation routines
    # in the form itself, but it just seemed too fiddly to do that
    # at the moment.  -- Skud 2002-04-11
    # I agree --bjr 2020-04-18
    
 	
    if ( $routerNetwork ne $localNetwork )
    {
       return (ret=>'ln_NOT_ACCESSIBLE_FROM_LOCAL_NETWORK');
    }

    my ( $network, $broadcast ) =
      esmith::util::computeNetworkAndBroadcast( $networkAddress, $networkMask );

    if ( $network eq $localNetwork )
    {
        return (ret=>'ln_NETWORK_ALREADY_LOCAL');
    }

    if ( $network_db->get($network) )
    {
        return (ret=>'ln_NETWORK_ALREADY_ADDED');
    }

    $network_db->new_record(
        $network,
        {
            Mask   => $networkMask,
            Router => $networkRouter,
            type   => 'network',
        }
    );

    # Untaint $network before use in system()
    $network =~ /(.+)/;
    $network = $1;
    system( "/sbin/e-smith/signal-event", "network-create", $network ) == 0
      or ( return (ret=>'ln_ERROR_CREATING_NETWORK' ));

    my ( $totalHosts, $firstAddr, $lastAddr ) =
      esmith::util::computeHostRange( $network, $networkMask );

    my $msg;
    if ( $totalHosts == 1 )
    {
        return (ret=>'ln_SUCCESS_SINGLE_ADDRESS',vars=>"$network,$networkMask,$networkRouter");
    }
    elsif (( $totalHosts == 256 )
        || ( $totalHosts == 65536 )
        || ( $totalHosts == 16777216 ) )
    {
         return ( ret=>'ln_SUCCESS_NETWORK_RANGE',vars=>"$network,$networkMask,$networkRouter,$totalHosts,$firstAddr,$lastAddr");
    }
    else
    {  	my $simpleMask = esmith::util::computeLocalNetworkPrefix( $network, $networkMask );
        return ( ret => 'ln_SUCCESS_NONSTANDARD_RANGE',
    	    vars=>"$network,$networkMask,$networkRouter,$totalHosts,$firstAddr,$lastAddr,$simpleMask");
    }
}
