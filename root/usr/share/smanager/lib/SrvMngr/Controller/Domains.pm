package SrvMngr::Controller::Domains;

#----------------------------------------------------------------------
# heading     : Network
# description : Domains
# navigation  : 6000 300
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

#use esmith::FormMagick::Panel::domains;

use esmith::DomainsDB;
use esmith::AccountsDB;
#use URI::Escape;


our $ddb = esmith::DomainsDB->open || die "Couldn't open domains db";
our $cdb = esmith::ConfigDB->open || die "Couldn't open configuration db";
our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";

our $REGEXP_DOMAIN = qq([a-zA-Z0-9\-\.]+);


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %dom_datas = ();
    my $title = $c->l('dom_FORM_TITLE');

    $dom_datas{trt} = 'LST';

    my @domains;
    for ($ddb->domains())
    {
        my $ns = $_->prop('Nameservers') || 'internet';

        push @domains, 
            { Domain => $_->key, $_->props,
              Nameservers => $ns,
            }
    }
    $dom_datas{forwarder} = $cdb->get_prop('dnscache', 'Forwarder'); 
    $dom_datas{forwarder2} = $cdb->get_prop('dnscache', 'Forwarder2') || ''; 

    $c->stash( title => $title, dom_datas => \%dom_datas, domains => \@domains );
    $c->render(template => 'domains');

};


sub do_display {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = $c->param('trt');
    my $domain = $c->param('Domain') || '';

    #$trt = 'DEL' if ( $rt eq 'domaindel1' );
    #$trt = 'UPD' if ( $rt eq 'domainupd1' );
    #$trt = 'UP2' if ( $rt eq 'domainup21' );
    #$trt = 'ADD' if ( $rt eq 'domainadd1' );

    my %dom_datas = ();
    my $title = $c->l('dom_FORM_TITLE');
    my $result = '';

    $dom_datas{'trt'} = $trt;
    if ( $trt ne 'ADD' and $trt ne 'UPD' and $trt ne 'UP2' and $trt ne 'DEL' ) {
		$result = "Trt unknown ( $trt ) !"
	}

	if ( $trt eq 'ADD' ) {
	    #nothing
	}

	if ( $trt eq 'UPD' ) {
	
	    my $rec = $ddb->get($domain);
	    if ( $rec ) {
    		$dom_datas{domain} = $domain;
    		$dom_datas{description} = $rec->prop('Description') || '';
    		$dom_datas{content} = $rec->prop('Content') || '';
    		$dom_datas{nameservers} = $rec->prop('Nameservers') || 'internet';
	    } else {
		$result = "Domain $domain not found !"
	    }
	}

	if ( $trt eq 'UP2' ) {
	
	    $dom_datas{forwarder} = $cdb->get_prop('dnscache', 'Forwarder') || ''; 
	    $dom_datas{forwarder2} = $cdb->get_prop('dnscache', 'Forwarder2') || ''; 

	}

        if ( $trt eq 'DEL' ) {

	    my $rec = $ddb->get($domain);
	    if ( $rec ) {
    		$dom_datas{domain} = $domain;
    		$dom_datas{description} = $rec->prop('Description') || '';
	    }
        }

        if ( $trt eq 'LST' ) {
	    my @domains;
	    if ($adb) {
	        @domains = $ddb->domains();
	    }
	    $c->stash( domains => \@domains );

	}

    if ( ! $result ) {
	$c->stash( error => $result );
    }
    $c->stash( title => $title, dom_datas => \%dom_datas );
    $c->render( template => 'domains' );

};


sub do_update {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = $c->param('trt');

    my %dom_datas = ();
    my ($res, $result) = '';

    #my $domain = uri_unescape($c->param('domain'));
    my $domain = $c->param('Domain');

    if ( $trt eq 'ADD' ) {

        my $account = $c->param('Account');

	# controls (validate ?????)
	#? validate_new_domain_name( $c, $domain, $account );
	#$result .= $res unless $res eq 'OK';

	#$result .= ' blocked';
	
	$res = '';
	if ( ! $result ) {
	    $res = $c->create_modify_domain( 'create', $domain );
	    $result .= $res unless $res eq 'OK';
	}
	
	if ( ! $result ) {
	    $result = $c->l('dom_SUCCESSFULLY_CREATED') . " $domain"; 
	}
    }

    if ( $trt eq 'UPD' ) {

        my $description = $c->param('Description');
        my $content = $c->param('Content');
        my $nameservers = $c->param('Nameservers');

	# controls
	#$res = validate_description( $c, $account );
	#$result .= $res unless $res eq 'OK';

	#$result .= 'blocked';

	$res = '';
	if ( ! $result ) {
	    $res = $c->create_modify_domain( 'modify', $domain );
	    $result .= $res unless $res eq 'OK';
	}

	if ( ! $result ) { 
		$result = $c->l('dom_SUCCESSFULLY_MODIFIED') . " $domain"; 
	}
    }


    if ( $trt eq 'UP2' ) {

        my $forwarder = $c->param('Forwarder');
        my $forwarder2 = $c->param('Forwarder2');

	# controls

	$res = $c->ip_number_or_blank( $forwarder );
	$result .= $res unless $res eq 'OK';

	$res = $c->ip_number_or_blank( $forwarder2 );
	$result .= $res unless $res eq 'OK';
	
	#$result .= 'blocked';
	
	$res = '';
	if ( ! $result ) {
	    $res = $c->modify_dns( $forwarder, $forwarder2 );
	    $result .= $res unless $res eq 'OK';
	}
	if ( ! $result ) { 
	    $result = $c->l('SUCCESS') . " $forwarder $forwarder2"; 
	}
    }


    if ( $trt eq 'DEL' ) {

	# controls
	#$res = validate_is_domain($c, $domain);
	#$result .= $res unless $res eq 'OK';
	
	#$result .= 'blocked';
	
	$res = '';
	if ( ! $result ) {
	    $res = $c->delete_domain( $domain );
	    $result .= $res unless $res eq 'OK';
	}
	if ( ! $result ) { 
	    $result = $c->l('dom_SUCCESSFULLY_DELETED') . " $domain"; 
	}
    }

    # common parts

    if ($res ne 'OK') {
	my $title = $c->l('dom_FORM_TITLE');
	$dom_datas{'domain'} = $domain;
	$dom_datas{'trt'} = $trt;

	$c->stash( error => $result . "($res)" );
	$c->stash( title => $title, dom_datas => \%dom_datas );
	return $c->render( 'domains' );
    }

    my $message = "'Domains' updates ($trt) DONE";
    $c->app->log->info($message);

    $c->flash( success => $result );
    $c->redirect_to('/domains');

};


sub create_modify_domain {

    my ($c, $action, $domain) = @_;

    $domain = $1 if ($domain =~ /^($REGEXP_DOMAIN)$/);
    unless ($domain) {
        return ($c->l($action eq 'create' ? 'dom_ERROR_CREATING_DOMAIN'
                                        : 'dom_ERROR_MODIFYING_DOMAIN') . ' Ctl');
    }

    my $rec = $ddb->get($domain);
    if ($rec and $action eq 'create') {
        return $c->l('dom_DOMAIN_IN_USE_ERROR');
    }
    if (not $rec and $action eq 'modify') {
        return $c->l('dom_NONEXISTENT_DOMAIN_ERROR');
    }

    $rec ||= $ddb->new_record($domain, { type => 'domain' });
    my %props;
    $props{$_} = $c->param($_) for ( qw(Content Description Nameservers) );
    $rec->merge_props(%props);

    if ( system( "/sbin/e-smith/signal-event", 
                        "domain-$action", "$domain" ) != 0 ) {
        return ($c->l($action eq 'create' ? 'dom_ERROR_CREATING_DOMAIN'
                                       : 'dom_ERROR_MODIFYING_DOMAIN') . " Exe $action");
    }

    return 'OK';
}


sub delete_domain {

    my ($c, $domain) = @_;

    $domain = $1 if ($domain =~ /^($REGEXP_DOMAIN)$/);
    return ($c->l('dom_ERROR_WHILE_REMOVING_DOMAIN') . ' Ctl') unless ($domain);

    my $rec = $ddb->get($domain);
    return ($c->l('dom_NONEXISTENT_DOMAIN_ERROR')) if (not $rec);

    $rec->set_prop('type', 'domain-deleted');

    if (system("/sbin/e-smith/signal-event", "domain-delete", "$domain") != 0) {
	return ($c->l('dom_ERROR_WHILE_REMOVING_DOMAIN') . 'Exe');
    }

    $rec->delete;
    return 'OK';
}


sub modify_dns {

    my ($c, $forwarder, $forwarder2) = @_;

    my $dnscache = $cdb->get('dnscache');

    ($forwarder, $forwarder2) = ($forwarder2, '')
        if ($forwarder2 and not $forwarder);

    if ($forwarder) {
	$dnscache->set_prop('Forwarder', $forwarder);
    } else {
	$dnscache->delete_prop('Forwarder');
    }
    
    if ($forwarder2) {
	$dnscache->set_prop('Forwarder2', $forwarder2);
    } else {
	$dnscache->delete_prop('Forwarder2');
    }

    unless ( system( "/sbin/e-smith/signal-event", "dns-update" ) == 0 )
    {
        return $c->l('dom_ERROR_UPDATING');
    }

    return 'OK';
}


sub existing_accounts_list {

    my $c = shift;

    my @existingAccounts = ( ['Administrator' => 'admin']);

    foreach my $a ($adb->get_all) {
        if ($a->prop('type') =~ /(user|group)/) {
            push @existingAccounts, [ $a->key => $a->key ];
        }
        if ($a->prop('type') eq "domain") {
            my $target = $adb->get($a->prop('Account'));

            unless ($target)
            {
                warn "WARNING: domain (" . $a->key . ") => missing Account(" 
			. $a->prop('Account')  . ")\n";
                next;
            }

            push @existingAccounts, [ $a->key, $a->key ]
                unless ($target->prop('type') eq "domain");
        }
    }

    return(\@existingAccounts);
}


sub content_options_list {

    my $c = shift;

    my @options = ( [ $c->l('dom_PRIMARY_SITE') => 'Primary' ]);

    foreach ($adb->ibays) {
	push @options, [ $_->prop('Name') => $_->key ]
		if ($_->key ne 'Primary');
    }

    return \@options
}


sub get_content_value
{
    my $c = shift;
    my $domain = shift;

    return $domain ? $ddb->get_prop($domain, 'Content') : 'Primary';
}


sub get_description_value
{
    my $c = shift;

    my $domain = $c->param('Domain') || undef;

    return $ddb->get_prop($domain, 'Description');
}


sub nameserver_options_list {

    my $c = shift;
    my $domain = $c->param('Domain') || undef;

    my @opts = qw(localhost internet);
    push @opts, 'corporate' if ($cdb->get_prop('dnscache', 'Forwarder'));
    my $ns = ($ddb->get_prop($domain, 'Nameservers') || 'internet');
    push @opts, $ns unless scalar grep { /^$ns$/ } @opts;

    my @options;
    foreach (@opts) {
	push @options, [ $c->l( "dom_$_" ) => $_ ];
    }

    return \@options;
}


sub get_nameserver_value {
    my $c = shift;

    my $domain = $c->param('Domain') || undef;

    return ($ddb->get_prop($domain, 'Nameservers') || 'internet');
}


sub validate_Domain
{
    my $c = shift;
    my $domain = lc shift;

    return ($domain =~ /^($REGEXP_DOMAIN)$/) ? 'OK' :
                            'DOMAIN_NAME_VALIDATION_ERROR';
}


sub validate_Description
{
    # XXX - FIXME - NOTREACHED
    # We used to use the Description in the Appletalk volume name
    # which meant it needed validation. I don't see any reason to
    # do this any more
    
    my $c = shift;
    my $description = shift;

    return ($description =~ /^([\-\'\w][\-\'\w\s\.]*)$/) ? 'OK' :
                    'DOMAIN_DESCRIPTION_VALIDATION_ERROR';
}


sub ip_number_or_blank {

    # XXX - FIXME - we should push this down into CGI::FormMagick

    my $c = shift;
    my $ip = shift;

    if (!defined($ip) || $ip eq "")
    {
        return 'OK';
    }
    
    return ip_number( $c, $ip ); 
}


sub ip_number {

#  from CGI::FormMagick::Validator qw( ip_number );

    my ($c, $data) = @_;

    return undef unless defined $data;

    return $c->l('FM_IP_NUMBER1') unless $data =~ /^[\d.]+$/;

    my @octets = split /\./, $data;
    my $dots = ($data =~ tr/.//);

    return $c->l('FM_IP_NUMBER2') unless (scalar @octets == 4 and $dots == 3);

    foreach my $octet (@octets) {
        return $c->l("FM_IP_NUMBER3", $octet) if $octet > 255;
    }

    return 'OK';
}



1;
