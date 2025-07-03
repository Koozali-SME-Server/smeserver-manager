package SrvMngr::Controller::Localnetworks;

#----------------------------------------------------------------------
# heading     : Network
# description : Local networks
# navigation  : 6000 500
#
#$if_admin->get('/localnetworks')->to('localnetworks#main')->name('localnetworks');
#$if_admin->post('/localnetworks')->to('localnetworks#do_display')->name('localnetworks');
#$if_admin->post('/localnetworksa')->to('localnetworks#do_display')->name('localnetworksadd');
#$if_admin->post('/localnetworksb')->to('localnetworks#do_display')->name('localnetworksadd1');
#$if_admin->get('/localnetworksd')->to('localnetworks#do_display')->name('localnetworksdel');
#$if_admin->post('/localnetworkse')->to('localnetworks#do_display')->name('localnetworksdel1');
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session subnet_mask get_reg_mask ip_number);
use esmith::util;
use esmith::HostsDB::UTF8;
use esmith::NetworksDB::UTF8;
use esmith::ConfigDB::UTF8;
my $ret = "OK";
our ($network_db,$config_db);

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %ln_datas = ();
    $ln_datas{return} = "";
    my $title = $c->l('ln_LOCAL NETWORKS');
    $network_db = esmith::NetworksDB::UTF8->open() || die("Couldn't open networks db");
    my $modul = '';
    $ln_datas{trt} = 'LIST';
    my @localnetworks;

    if ($network_db) {
        @localnetworks = $network_db->get_all_by_prop(type => 'network');
    }
    $c->stash(
        title         => $title,
        modul         => $modul,
        ln_datas      => \%ln_datas,
        localnetworks => \@localnetworks
    );
    $c->render(template => 'localnetworks');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');
    $network_db = esmith::NetworksDB::UTF8->open() || die("Couldn't open networks db");
    $trt = 'DEL'  if ($rt eq 'localnetworksdel');
    $trt = 'ADD'  if ($rt eq 'localnetworksadd');
    $trt = 'ADD1' if ($rt eq 'localnetworksadd1');
    $trt = 'DEL1' if ($rt eq 'localnetworksdel1');
    $c->app->log->info("Localnetworks:trt:$trt");
    my %ln_datas = ();
    my $title    = $c->l('ln_LOCAL NETWORKS');
    my $modul    = '';

    if ($trt eq 'ADD') {

        #Add a network - called from the list panel
        # Nothing to do here...as just need fields to input data.
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'ADD1') {

        #Add a network - called after new network details filled in
        my %ret = add_network($c);
        $network_db   = esmith::NetworksDB::UTF8->open();

        #Return to list page if success
        if ((index($ret{ret}, "SUCCESS") != -1)) {
            $trt = "LIST";
        } else {
            #Error - return to Add page
            $trt = "ADD";
        }
	#$network_db = esmith::NetworksDB::UTF8->open() || die("Failed to open Networkdb-3");    #Refresh the network DB
        $c->stash(ret => \%ret);    #stash it away for the template
    } ## end if ($trt eq 'ADD1')

    if ($trt eq 'DEL1') {

        #After Remove clicked on Delete network panel
		#$network_db   = esmith::NetworksDB::UTF8->open() || die("Failed to open Networkdb-1");
        my $localnetwork = $c->param("localnetwork");
        my $delete_hosts = $c->param("deletehost") || "1"; #default to deleting them.
        $c->app->log->info("Localnetworks:deleting $localnetwork");
        my ($rec,%ret);
        if ($rec = $network_db->get($localnetwork)){  #|| die("Failed to find network on db:$localnetwork");
			if ($rec and $rec->prop('type') eq 'localnetwork') {
				$ln_datas{localnetwork} = $localnetwork;
			}
			%ret = $c->remove_network($localnetwork, $delete_hosts);
		} else {
			$c->app->log->info("Local network: delete failed to find network in db: $localnetwork");
			%ret = ();
		}
		#$network_db = esmith::NetworksDB::UTF8->open() || die("Failed to open Networkdb-2");        #Refresh the network DB
        my @localnetworks;

        if ($network_db) {
            @localnetworks = $network_db->get_all_by_prop(type => 'network');
        }

        # Load up ln_datas with values need by template
        if ($rec){
			$ln_datas{subnet} = $rec->prop('Mask');
			$ln_datas{router} = $rec->prop('Router');
		}
        $c->stash(ln_datas => \%ln_datas, localnetworks => \@localnetworks, ret => \%ret);
    } ## end if ($trt eq 'DEL1')

    if ($trt eq 'DEL') {

        #Initial delete panel requiring confirmation
        my $localnetwork = $c->param("localnetwork") || '';
        my ($rec,%ret);
        $c->stash(localnetwork => $localnetwork);
        if ($rec = $network_db->get($localnetwork)){
			my $subnet = $rec->prop('Mask');
			$ln_datas{subnet} = $subnet;
			$ln_datas{router} = $rec->prop('Router');
			my $numhosts =$c->hosts_on_network($localnetwork, $subnet);
			$ln_datas{localnetwork} = $localnetwork;
			$ln_datas{deletehosts} = $numhosts > 0 ? 1 : 0;
		} else {
			$c->app->log->info("Local network:Initial Failed to find network in Db: $localnetwork");
			$c->flash('error',$c->l('ln_Failed to find network in Db'));
			$trt = 'LIST';
		}
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'LIST') {

        #List all the networks
        my @localnetworks;

        if ($network_db) {
            @localnetworks = $network_db->get_all_by_prop(type => 'network');
        }
        $c->stash(localnetworks => \@localnetworks);
        ## $c->redirect_to('/localnetworks');
    } ## end if ($trt eq 'LIST')
    $ln_datas{'trt'} = $trt;
    $c->stash(title => $title, modul => $modul, ln_datas => \%ln_datas);
    $c->render(template => 'localnetworks');
} ## end sub do_display

sub remove_network {
	my $c = shift;
    my $network      = shift;
    $network_db   = esmith::NetworksDB::UTF8->open();
    my $record       = $network_db->get($network);
    my $delete_hosts = shift;

    if (my $record = $network_db->get($network)) {
        my $subnet = $record->prop('Mask');
        my $router = $record->prop('Router');
        $record->set_prop(type => 'network-deleted');

        # Untaint $network before use in system()
        $network =~ /(.+)/;
        $network = $1;

        if (system("/sbin/e-smith/signal-event", "network-delete", $network) == 0) {
            if ($delete_hosts) {
                my @hosts_to_delete = $c->hosts_on_network($network, $subnet);

                foreach my $host (@hosts_to_delete) {
                    $host->delete;
                }
            } ## end if ($delete_hosts)
            $record->delete;
            return (ret => 'ln_SUCCESS_REMOVED_NETWORK', vars => "$network,$subnet,$router");
        } else {
            return (ret => "ln_ERROR_DELETING_NETWORK");
        }
    } else {
        return (ret => "ln_NO_SUCH_NETWORK");
    }
} ## end sub remove_network

sub hosts_on_network {
	my $c = shift;
    my $network = shift;
    my $netmask = shift;
    die if not $network and $netmask;
    my $cidr             = "$network/$netmask";
    my $hosts            = esmith::HostsDB::UTF8->open() || die("Couldn't open hosts db");
    my @localhosts       = grep { $_->prop('HostType') eq 'Local' } $hosts->hosts;
    my @hosts_on_network = ();

    foreach my $host (@localhosts) {
        my $ip = $host->prop('InternalIP') || "";

        if ($ip) {
            if (Net::IPv4Addr::ipv4_in_network($cidr, $ip)) {
                push @hosts_on_network, $host;
            }
        } ## end if ($ip)
    } ## end foreach my $host (@localhosts)
    return @hosts_on_network if wantarray;
    return scalar @hosts_on_network;
} ## end sub hosts_on_network

sub add_network {
    my ($c)           = @_;
    my $networkAddress = $c->param('networkAddress');
    my $networkMask    = $c->param('networkMask');
    my $networkRouter  = $c->param('networkRouter');
    
    #Start by checking that the network does not already exist
    

    #Validate Ips and subnet mask
    my $res = ip_number($c, $networkAddress);
    return (ret => 'ln_INVALID_IP_ADDRESS', vars => "Network Address $res") unless $res eq 'OK';
    $res = subnet_mask($networkMask);
    return (ret => 'ln_INVALID_SUBNET_MASK', vars => "$networkMask") unless $res eq 'OK';
    $res = ip_number($c, $networkRouter);
    return (ret => 'ln_INVALID_IP_ADDRESS', vars => "Routeur Address $res") unless $res eq 'OK';

    # we transform bit mask to regular mask
    $networkMask = get_reg_mask($networkAddress, $networkMask);
    my $network_db = esmith::NetworksDB::UTF8->open()
        || esmith::NetworksDB::UTF8->create();
    my $config_db    = esmith::ConfigDB::UTF8->open();
    my $localIP      = $config_db->get('LocalIP');
    my $localNetmask = $config_db->get('LocalNetmask');
    my ($localNetwork, $localBroadcast)
        = esmith::util::computeNetworkAndBroadcast($localIP->value(), $localNetmask->value());
    my ($routerNetwork, $routerBroadcast)
        = esmith::util::computeNetworkAndBroadcast($networkRouter, $localNetmask->value());

    # Note to self or future developers:
    # the following tests should probably be validation routines
    # in the form itself, but it just seemed too fiddly to do that
    # at the moment.  -- Skud 2002-04-11
    # I agree --bjr 2020-04-18
    my ($network, $broadcast) = esmith::util::computeNetworkAndBroadcast($networkAddress, $networkMask);

    if ($routerNetwork ne $localNetwork) {
        return (ret => 'ln_NOT_ACCESSIBLE_FROM_LOCAL_NETWORK', vars => "$network,$networkMask,$networkRouter");
    }

    if ($network eq $localNetwork) {
        return (ret => 'ln_NETWORK_ALREADY_LOCAL', vars => "$network,$networkMask,$networkRouter");
    }

    if ($network_db->get($network)) {
        return (ret => 'ln_NETWORK_ALREADY_ADDED', vars => "$network,$networkMask,$networkRouter");
    }
    $res = $network_db->new_record(
        $network,
        {   Mask   => $networkMask,
            Router => $networkRouter,
            type   => 'network',
        }
    );
    if (! $res) {
		#Record already existed
		$c->app->log->info("Local Network:Network already exists:$network");
		#return success message 
	} else {
		#Only call underlying batch if new record created
		# Untaint $network before use in system()
		$network =~ /(.+)/;
		$network = $1;
		system("/sbin/e-smith/signal-event", "network-create", $network) == 0
			or (return (ret => 'ln_ERROR_CREATING_NETWORK', vars => "$network,$networkMask,$networkRouter"));
	}
    my ($totalHosts, $firstAddr, $lastAddr) = esmith::util::computeHostRange($network, $networkMask);
    my $msg;

    if ($totalHosts == 1) {
        return (ret => 'ln_SUCCESS_SINGLE_ADDRESS', vars => "$network,$networkMask,$networkRouter");
    } elsif (($totalHosts == 256)
        || ($totalHosts == 65536)
        || ($totalHosts == 16777216))
    {
        return (
            ret  => 'ln_SUCCESS_NETWORK_RANGE',
            vars => "$network,$networkMask,$networkRouter,$totalHosts,$firstAddr,$lastAddr"
        );
    } else {
        my $simpleMask = esmith::util::computeLocalNetworkPrefix($network, $networkMask);
        return (
            ret  => 'ln_SUCCESS_NONSTANDARD_RANGE',
            vars => "$network,$networkMask,$networkRouter,$totalHosts,$firstAddr,$lastAddr,$simpleMask"
        );
    } ## end else [ if ($totalHosts == 1) ]
} ## end sub add_network
1;