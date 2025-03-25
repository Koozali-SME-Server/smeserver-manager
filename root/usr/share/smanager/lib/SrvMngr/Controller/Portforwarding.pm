package SrvMngr::Controller::Portforwarding;

#----------------------------------------------------------------------
# heading     : Network
# description : Port forwarding
# navigation  : 6000 600
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

#use Regexp::Common qw /net/;
#use Data::Dumper;
use esmith::util;
use esmith::HostsDB;
#our $db = esmith::ConfigDB->open || die "Can't open configuration database: $!\n";
#our $tcp_db = esmith::ConfigDB->open('portforward_tcp') || die "Can't open portforward_tcp database: $!\n";
#our $udp_db = esmith::ConfigDB->open('portforward_udp') || die "Can't open portforward_udp database: $!\n";
my ($cdb,$tcp_db,$udp_db);

my %ret = ();
use constant FALSE => 0;
use constant TRUE  => 1;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %pf_datas = ();
    $pf_datas{return} = "";
    my $title = $c->l('pf_FORM_TITLE');
    my $modul = '';
	$cdb = esmith::ConfigDB->open || die "Can't open configuration database: $!\n";
	$tcp_db = esmith::ConfigDB->open('portforward_tcp') || die "Can't open portforward_tcp database: $!\n";
	$udp_db = esmith::ConfigDB->open('portforward_udp') || die "Can't open portforward_udp database: $!\n";
    $pf_datas{trt} = 'LIST';
    my @tcpforwards = $tcp_db->get_all;
    my @udpforwards = $udp_db->get_all;
    my $empty       = 1 if not @tcpforwards and not @udpforwards;
    $c->stash(
        title       => $title,
        modul       => $modul,
        pf_datas    => \%pf_datas,
        tcpforwards => \@tcpforwards,
        udpforwards => \@udpforwards,
        empty       => $empty
    );
    $c->render(template => 'portforwarding');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');
	my $cdb = esmith::ConfigDB->open || die "Can't open configuration database: $!\n";
	my $tcp_db = esmith::ConfigDB->open('portforward_tcp') || die "Can't open portforward_tcp database: $!\n";
	my $udp_db = esmith::ConfigDB->open('portforward_udp') || die "Can't open portforward_udp database: $!\n";
    $trt = 'DEL'  if ($rt eq 'portforwardingdel');
    $trt = 'ADD'  if ($rt eq 'portforwardingadd');
    $trt = 'ADD1' if ($rt eq 'portforwardingadd1');
    $trt = 'DEL1' if ($rt eq 'portforwardingdel1');
    my %pf_datas = ();
    my $title    = $c->l('pf_FORM_TITLE');
    my $modul    = '';

    if ($trt eq 'ADD') {

        # Add a portforward- called from the list panel
        # Nothing to do here...as just need template to display fields to input data.
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'ADD1') {

        #Add a port forward - called after new pf details filled in
        my %ret = add_portforward($c);

        #Return to list page if success
        if ((index($ret{ret}, "SUCCESS") != -1)) {
            $trt = "LIST";
        } else {

            #Error - return to Add page
            $trt = "ADD";
        }
        $c->stash(ret => \%ret);
    } ## end if ($trt eq 'ADD1')

    if ($trt eq 'DEL1') {
        ##After Remove clicked on Delete network panel
        my $sport = $c->param("sport") || '';
        my $proto = $c->param("proto") || '';

        #work out which protocol
        my $fdb;

        if ($proto eq 'TCP') {
            $fdb = $tcp_db;
        } else {
            $fdb = $udp_db;
        }

        #check that the sport is in the db
        my $entry = $fdb->get($sport) || die("Unable to find sport and proto $sport $proto");
        $entry->delete;
        system("/sbin/e-smith/signal-event", "portforwarding-update") == 0
            or (die($c->l('pf_ERR_NONZERO_RETURN_EVENT')));
        $trt = "LIST";
        my %ret = (ret => "pf_SUCCESS");
        $c->stash(ret => \%ret);
    } ## end if ($trt eq 'DEL1')

    if ($trt eq 'DEL') {
        ##Initial delete panel requiring confirmation
        my $sport = $c->param("sport") || '';
        my $proto = $c->param("proto") || '';
        $c->stash(sport => $sport);

        #work out which protocol
        my $fdb;

        if ($proto eq 'TCP') {
            $fdb = $tcp_db;
        } else {
            $fdb = $udp_db;
        }

        #pull out details and pass to template
        my $entry = $fdb->get($sport) || die("Unable to find sport and proto $sport $proto");
        $pf_datas{proto} = $proto;
        $pf_datas{sport} = $sport;
        $pf_datas{dhost} = $entry->prop('DestHost');
        $pf_datas{dport} = $entry->prop('DestPort') || '';
        $pf_datas{cmmnt} = $entry->prop('Comment') || '';
        $pf_datas{allow} = $entry->prop('AllowHosts') || '';
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'LIST') {

        #List all the port forwards
        # Open them again as maybe written to above 
        $tcp_db = esmith::ConfigDB->open('portforward_tcp') || die "Can't open portforward_tcp database: $!\n";
		$udp_db = esmith::ConfigDB->open('portforward_udp') || die "Can't open portforward_udp database: $!\n";

        my @tcpforwards = $tcp_db->get_all;
        my @udpforwards = $udp_db->get_all;
        my $empty       = 1 if not @tcpforwards and not @udpforwards;
        $c->stash(
            tcpforwards => \@tcpforwards,
            udpforwards => \@udpforwards,
            empty       => $empty
        );

        #my %forwards = (TCP=>@tcpforwards,UDP=>@udpforwards);
        #$c->stash(portforwarding => %forwards);
    } ## end if ($trt eq 'LIST')
    $pf_datas{'trt'} = $trt;
    $c->stash(title => $title, modul => $modul, pf_datas => \%pf_datas);
    $c->render(template => 'portforwarding');
} ## end sub do_display

sub add_portforward {
    my $c     = shift;
    my $sport = $c->param("sport") || '';
    my $proto = $c->param("proto") || '';

    #work out which protocol
    my $fdb;

    if ($proto eq 'TCP') {
        $tcp_db = esmith::ConfigDB->open('portforward_tcp') || die "Can't open portforward_tcp database: $!\n";
        $fdb = $tcp_db;
    } else {
        $udp_db = esmith::ConfigDB->open('portforward_udp') || die "Can't open portforward_udp database: $!\n";
        $fdb = $udp_db;
    }

    #Get the other values
    my $dport = $c->param("dport");
    my $dhost = get_destination_host($c);
    my $cmmnt = $c->param("cmmnt") || "";
    my $allow = $c->param("allow") || "";
    my $deny  = (($c->param("allow")) ? "0.0.0.0/0" : "");
    $proto =~ s/^\s+|\s+$//g;
    $sport =~ s/^\s+|\s+$//g;
    $dport =~ s/^\s+|\s+$//g;
    $dhost =~ s/^\s+|\s+$//g;

    #Validate the values
    %ret = validate_source_port($c);
    unless (index($ret{ret}, "SUCCESS") != -1) { return %ret; }
    %ret = validate_allowed_hosts($c);
    if (index($ret{ret}, "SUCCESS") == -1) { return %ret; }
    %ret = validate_destination_port($c);
    if (index($ret{ret}, "SUCCESS") == -1) { return %ret; }
    %ret = validate_destination_host($c);
    if (index($ret{ret}, "SUCCESS") == -1) { return %ret; }

    # and then write it to the DB and tell the exec about it.
    my $entry = $fdb->get($sport) || $fdb->new_record($sport, { type => 'forward' });
    $entry->set_prop('DestHost',   $dhost);
    $entry->set_prop('DestPort',   $dport) if $dport;
    $entry->set_prop('Comment',    $cmmnt);
    $entry->set_prop('AllowHosts', $allow);
    $entry->set_prop('DenyHosts',  $deny);
    system("/sbin/e-smith/signal-event", "portforwarding-update") == 0
        or (return (ret => 'pf_ERR_NONZERO_RETURN_EVENT'));
    my %ret = (ret => "pf_SUCCESS");
    return %ret;
} ## end sub add_portforward

sub get_destination_host {
    my $q           = shift;
    my $dhost       = $q->param("dhost");
    my $localip     = $cdb->get_prop('InternalInterface', 'IPAddress');
    my $external_ip = $cdb->get_prop('ExternalInterface', 'IPAddress') || $localip;

    if ($dhost =~ /^(127.0.0.1|$localip|$external_ip)$/i) {

        # localhost token gets expanded at runtime to current external IP
        $dhost = 'localhost';
    } ## end if ($dhost =~ /^(127.0.0.1|$localip|$external_ip)$/i)
    return $dhost;
} ## end sub get_destination_host

sub validate_source_port {
    my $q     = shift;
    my $sport = $q->param('sport');
    $sport =~ s/^\s+|\s+$//g;

    # If this is a port range, split it up and validate it individually.
    my @ports = ();

    if ($sport =~ /-/) {
        @ports = split /-/, $sport;

        if (@ports > 2) {

            #$self->debug_msg("found more than 2 ports: @ports");
            return (ret => 'pf_ERR_BADPORT');
        } ## end if (@ports > 2)
    } else {
        push @ports, $sport;
    }

    #$self->debug_msg("the ports array is: @ports");
    foreach my $port (@ports) {

        #$self->debug_msg("looping on port $port");
        if (!isValidPort($port)) {

            #$self->debug_msg("returning: " . $self->localise('ERR_BADPORT'));
            return (ret => 'pf_ERR_BADPORT');
        }
    } ## end foreach my $port (@ports)

    # Now, lets screen any duplicates.
    my $protocol = $q->param('protocol');
    my @forwards = ();

    # Grab the existing rules for this protocol.
    if ($protocol eq 'TCP') {
        @forwards = map { $_->key } $tcp_db->get_all;
    } elsif ($protocol eq 'UDP') {
        @forwards = map { $_->key } $udp_db->get_all;
    }

    foreach my $psport (@forwards) {
        if (detect_collision($sport, $psport)) {
            return (ret => 'pf_ERR_PORT_COLLISION');
        }
    } ## end foreach my $psport (@forwards)
    return (ret => "pf_SUCCESS");
} ## end sub validate_source_port

sub detect_collision {
    my $port_a = shift;
    my $port_b = shift;

    # If they're both single ports, see if they're the same.
    if (($port_a !~ /-/) && ($port_b !~ /-/)) {
        return $port_a eq $port_b;
    }

    # If port_a is not a range but port_b is, is a in b?
    elsif ($port_a !~ /-/) {
        my ($b1, $b2) = split /-/, $port_b;
        return (($port_a >= $b1) && ($port_a <= $b2));
    } elsif ($port_b !~ /-/) {
        my ($a1, $a2) = split /-/, $port_a;
        return (($port_b >= $a1) && ($port_b <= $a2));
    } else {

        # They're both ranges. Do they overlap?
        my ($a1, $a2) = split /-/, $port_a;
        my ($b1, $b2) = split /-/, $port_b;

        # They can overlap in two ways. Either a1 is in b, or b1 is in a.
        if (($a1 >= $b1) && ($a1 <= $b2)) {
            return TRUE;
        } elsif (($b1 >= $a1) && ($b1 <= $a2)) {
            return TRUE;
        }
        return FALSE;
    } ## end else [ if (($port_a !~ /-/) &&...)]
} ## end sub detect_collision

sub validate_destination_port {
    my $c     = shift;
    my $dport = $c->param('dport');
    $dport =~ s/^\s+|\s+$//g;

    # If the dport is empty, that's ok.
    return (ret => 'pf_SUCCESS') if not $dport;

    # If this is a port range, split it up and validate it individually.
    my @ports = ();

    if ($dport =~ /-/) {
        @ports = split /-/, $dport;

        if (@ports > 2) {

            #$self->debug_msg("found more than 2 ports: @ports");
            return (ret => 'pf_ERR_BADPORT');
        } ## end if (@ports > 2)
    } else {
        push @ports, $dport;
    }

    #$self->debug_msg("the ports array is: @ports");
    foreach my $port (@ports) {

        #$self->debug_msg("looping on port $port");
        if (!isValidPort($port)) {

            #$self->debug_msg("returning: " . $self->localise('ERR_BADPORT'));
            return (ret => 'pf_ERR_BADPORT');
        }
    } ## end foreach my $port (@ports)
    return (ret => 'pf_SUCCESS');
} ## end sub validate_destination_port

sub isValidPort() {
    my $port = shift;
    return FALSE unless defined $port;

    if (   ($port =~ /^\d+$/)
        && ($port > 0)
        && ($port < 65536))
    {
        return TRUE;
    } else {
        return FALSE;
    }
} ## end sub isValidPort

sub validate_destination_host {
    my $c     = shift;
    my $dhost = $c->param('dhost');
    $dhost =~ s/^\s+|\s+$//g;
    my $localip = $cdb->get_prop('InternalInterface', 'IPAddress');
    my $external_ip = $cdb->get_prop('ExternalInterface', 'IPAddress') || $localip;

    if ($dhost =~ /^(localhost|127.0.0.1|$localip|$external_ip)$/i) {

        # localhost token gets expanded at runtime to current external IP
        $c->param(-name => 'dhost', -value => 'localhost');
        return (ret => 'pf_SUCCESS');
    } ## end if ($dhost =~ /^(localhost|127.0.0.1|$localip|$external_ip)$/i)
    my $systemmode = $cdb->get_value('SystemMode');

    if ($systemmode eq 'serveronly') {
        return (ret => 'pf_IN_SERVERONLY');
    }

    if (isValidIP($dhost)) {
        return (ret => 'pf_SUCCESS');
    } else {
        return (ret => 'pf_ERR_BADIP');
    }
} ## end sub validate_destination_host

sub validate_allowed_hosts {
    my $c     = shift;
    my $ahost = $c->param('allow');
    $ahost =~ s/^\s+|\s+$//g;
    my %valid_ahost_list = (ret => "pf_SUCCESS");

    foreach (split(/[\s,]+/, $ahost)) {
        my $valid_ipnet = 0;
        $valid_ipnet = 1 if ($_ =~ m/^\d+\.\d+\.\d+\.\d+$/);
        $valid_ipnet = 1 if ($_ =~ m/^\d+\.\d+\.\d+\.\d+\/\d+$/);
        %valid_ahost_list = (ret => "pf_ERR_BADAHOST") if ($valid_ipnet != 1);
    } ## end foreach (split(/[\s,]+/, $ahost...))
    return %valid_ahost_list;
} ## end sub validate_allowed_hosts
1;