package SrvMngr::Controller::Review;

#----------------------------------------------------------------------
# heading     : Investigation
# description : Review configuration
# navigation  : 7000 600
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use SrvMngr qw(gen_locale_date_string);
use esmith::ConfigDB::UTF8;
use esmith::DomainsDB::UTF8;
use esmith::NetworksDB::UTF8;

#use SrvMngr::Review_sub qw(print_page);
#use smeserver::Panel::review;
our $db;
our $domains ;
our $networks;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    $db       = esmith::ConfigDB::UTF8->open_ro   || die "Couldn't open config db";
    my $title     = $c->l('rvw_FORM_TITLE');
    my $modul     = $c->render_to_string(inline => $c->l('rvw_DESCRIPTION'));
    my %rvw_datas = ();
    $rvw_datas{'servermode'} = (get_value('', 'SystemMode') || '');
    $rvw_datas{'localip'}          = get_value('$c', 'LocalIP') . '/' . get_value('$c', 'LocalNetmask');
    $rvw_datas{'publicip'}         = $c->get_public_ip_address($c);
    $rvw_datas{'gateway'}          = $c->render_to_string(inline => print2_gateway_stanza($c));
    $rvw_datas{'serveronly'}       = $c->render_to_string(inline => print2_serveronly_stanza($c));
    $rvw_datas{'addlocalnetworks'} = get_local_networks($c);
    $rvw_datas{'dhcpserver'}       = $c->render_to_string(inline => print2_dhcp_stanza($c));
    $rvw_datas{'dnsserver'}        = (get_value('', 'LocalIP') || '');
    $rvw_datas{'webserver'}        = 'www.' . (get_local_domain());
    my $port = $db->get_prop("squid", "TransparentPort") || 3128;
    $rvw_datas{'proxyserver'}    = 'proxy.' . get_local_domain() . ":$port";
    $rvw_datas{'ftpserver'}      = 'ftp.' . get_local_domain();
    $rvw_datas{'smtpserver'}     = 'mail.' . get_local_domain();
    $rvw_datas{'domainname'}     = (get_value('', 'DomainName') || '');
    $rvw_datas{'virtualdomains'} = $c->render_to_string(inline => gen2_domains($c));
    $rvw_datas{'primarywebsite'} = 'http://www.' . get_value('', 'DomainName');
    $rvw_datas{'servermanager'}  = 'https://' . (get_value('', 'SystemName') || 'localhost') . '/server-manager/';
    $rvw_datas{'usermanager'}    = 'https://' . (get_value('', 'SystemName') || 'localhost') . '/user-password/';
    $rvw_datas{'emailaddresses'} = $c->render_to_string(inline => gen2_email_addresses($c));

    #$c->stash( releaseVersion => $c->session->{releaseVersion}, copyRight => $c->session->{copyRight},
    #PwdSet => $c->session->{PwdSet}, Unsafe => $c->session->{Unsafe},
    $c->stash(
        title     => $title,
        modul     => $modul,
        rvw_datas => \%rvw_datas,
    );
    $c->render(template => 'review');
} ## end sub main

=head2 gen2_email_addresses

    Returns a string of the various forms of email addresses that work 
    on an SMEServer (mojo v.)

=cut

sub gen2_email_addresses {
    my $c           = shift;
    my $domain      = get_value($c, 'DomainName');
    my $useraccount = $c->l("rvw_EMAIL_USERACCOUNT");
    my $firstname   = $c->l("rvw_EMAIL_FIRSTNAME");
    my $lastname    = $c->l("rvw_EMAIL_LASTNAME");
    my $out
        = "<I>"
        . $useraccount
        . "</I>\@"
        . $domain . "<BR>" . "<I>"
        . $firstname
        . "</I>.<I>"
        . $lastname
        . "</I>\@"
        . $domain . "<BR>" . "<I>"
        . $firstname
        . "</I>_<I>"
        . $lastname
        . "</I>\@"
        . $domain . "<BR>";
    return $out;
} ## end sub gen2_email_addresses

=head2 gen2_domains 

    Returns a string of the domains this SME Server serves or a localized string
    saying "no domains defined" (mojo ver)

=cut

sub gen2_domains {
    my $c          = shift;
    $domains  = esmith::DomainsDB::UTF8->open_ro  || die "Couldn't open domains";
    my @virtual    = $domains->get_all_by_prop(type => 'domain');
    my $numvirtual = @virtual;

    if ($numvirtual == 0) {
        $c->localise("NO_VIRTUAL_DOMAINS");
    } else {
        my $out = "";
        my $domain;

        foreach $domain (sort @virtual) {
            if ($out ne "") {
                $out .= "<BR>";
            }
            $out .= $domain->key;
        } ## end foreach $domain (sort @virtual)
        return $out;
    } ## end else [ if ($numvirtual == 0) ]
} ## end sub gen2_domains

=head2 get2_local_networks

Return a <br> delimited string of all the networks this SMEServer is 
serving.	(mojo ver)

=cut

sub get2_local_networks {
    my $c           = shift;
    $networks = esmith::NetworksDB::UTF8->open_ro || die "Couldn't open networks";
    my @nets        = $networks->get_all_by_prop('type' => 'network');
    my $numNetworks = @nets;

    if ($numNetworks == 0) {
        return $c->l('rvw_NO_NETWORKS');
    } else {
        my $out = "";

        foreach my $network (sort @nets) {
            if ($out ne "") {
                $out .= "<BR>";
            }
            $out .= $network->key . "/" . get_net_prop($c, $network->key, 'Mask');

            if (defined get_net_prop($c, $network->key, 'Router')) {
                $out .= " via " . get_net_prop($c, $network->key, 'Router');
            }
        } ## end foreach my $network (sort @nets)
        return $out;
    } ## end else [ if ($numNetworks == 0)]
} ## end sub get2_local_networks

sub get_net_prop {
  my $fm = shift;
  my $item = shift;
  my $prop = shift;
  $networks = esmith::NetworksDB::UTF8->open_ro || die "Couldn't open networks";
  my $record = $networks->get($item);
  if ($record) {
    return $record->prop($prop);
  }
  else {
    return '';
  }

}


sub get_local_networks {
    my $fm = shift;
    $networks = esmith::NetworksDB::UTF8->open_ro || die "Couldn't open networks";
    my @nets = $networks->get_all_by_prop('type' => 'network');

    my $numNetworks = @nets;
    if ($numNetworks == 0) {
        return  $fm->localise('NO_NETWORKS');
    }
    else {
        my $out = "";
        foreach my $network (sort @nets) {
            if ($out ne "") {
                $out .= "<BR>";
            }

            $out .= $network->key."/" . get_net_prop($fm, $network->key, 'Mask');

            if ( defined get_net_prop($fm, $network->key, 'Router') ) {
                $out .= " via " . get_net_prop ($fm, $network->key, 'Router'); 
            }
        }
        return $out;
    }

}

sub get_local_domain
{
    return (get_value('','DomainName'));
}


=head2 print2_gateway_stanza

If this system is a server gateway, show the external ip and gateway ip (mojo ver)

=cut

sub print2_gateway_stanza {
    my $c = shift;

    if (get_value($c, 'SystemMode') =~ /servergateway/) {
        my $ip = get_value($c, 'ExternalIP');
        my $static
            = (get_value($c, 'AccessType') eq 'dedicated')
            && (get_value($c, 'ExternalDHCP') eq 'off')
            && (get_prop($c, 'pppoe', 'status') eq 'disabled');

        if ($static) {
            $ip .= "/" . get_value($c, 'ExternalNetmask');
        }
        my $out = $c->l('rvw_EXTERNAL_IP_ADDRESS_SUBNET_MASK') . ':' . $ip;

        if ($static) {
            $out .= $c->l('rvw_GATEWAY') . ':' . get_value($c, 'GatewayIP');
        }
        return $out;
    } ## end if (get_value($c, 'SystemMode'...))
} ## end sub print2_gateway_stanza

=head2 print2_serveronly_stanza

If this system is a standalone server with net access, show the external
gateway IP	(mojo ver)

=cut

sub print2_serveronly_stanza {
    my $c = shift;

    if (   (get_value($c, 'SystemMode') eq 'serveronly')
        && get_value($c, 'AccessType')
        && (get_value($c, 'AccessType') ne "off"))
    {
        return (get_value($c, 'GatewayIP'));
    } ## end if ((get_value($c, 'SystemMode'...)))
} ## end sub print2_serveronly_stanza

=head2 print2_dhcp_stanza 

Prints out the current state of dhcp service	(mojo ver)


=cut

sub print2_dhcp_stanza {
    my $c = shift;
    my $out = (get_prop($c, 'dhcpd', 'status') || 'disabled');

    if (get_prop($c, 'dhcpd', 'status') eq 'enabled') {
        $out .= '<br>' . $c->l('rvw_BEGINNING_OF_DHCP_ADDRESS_RANGE') . ':';
        $out .= (get_prop($c, 'dhcpd', 'start') || '') . '<br>';
        $out .= $c->l('rvw_END_OF_DHCP_ADDRESS_RANGE') . ':';
        $out .= (get_prop($c, 'dhcpd', 'end') || '');
    } ## end if (get_prop($c, 'dhcpd'...))
    return $out;
} ## end sub print2_dhcp_stanza

sub get_value {
  my $fm = shift;
  my $item = shift;
  $db       = esmith::ConfigDB::UTF8->open_ro   || die "Couldn't open config db";
  my $record = $db->get($item);
  if ($record) {
    return $record->value();
  }
  else {
    return '';
  }
  
}

sub get_prop {
  my $fm = shift if (ref($_[0]) ); # If we're being called in a formmagick context
				 # The first argument will always be a fm.
				 #otherwise, we don't want to grab it
  my $item = shift;
  my $prop = shift;
  $db       = esmith::ConfigDB::UTF8->open_ro   || die "Couldn't open config db";
  my $record = $db->get($item);
  if ($record) {
    return $record->prop($prop);
  }
  else {
    return '';
  }

}

sub get_public_ip_address
{
    my $self = shift;
    $db       = esmith::ConfigDB::UTF8->open_ro   || die "Couldn't open config db";
    my $sysconfig = $db->get('sysconfig');
    if ($sysconfig)
    {
        my $publicIP = $sysconfig->prop('PublicIP');
        if ($publicIP)
        {
            return $publicIP;
        }
    }
    return undef;
}


1;
