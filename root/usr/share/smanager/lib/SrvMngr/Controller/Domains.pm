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
use SrvMngr qw(theme_list init_session ip_number ip_number_or_blank);
use esmith::DomainsDB::UTF8;
use esmith::AccountsDB::UTF8;

our ($ddb,$cdb,$adb);
our $REGEXP_DOMAIN = qq([a-zA-Z0-9\-\.]+);

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %dom_datas = ();
    my $title     = $c->l('dom_FORM_TITLE');
    $ddb = esmith::DomainsDB::UTF8->open  || die "Couldn't open domains db";
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open configuration db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    $dom_datas{trt} = 'LST';
    my @domains;

    for ($ddb->domains()) {
        my $ns = $_->prop('Nameservers') || 'internet';
        push @domains,
            {
            Domain => $_->key,
            $_->props,
            Nameservers => $ns,
            };
    } ## end for ($ddb->domains())
    $dom_datas{forwarder} = $cdb->get_prop('dnscache', 'Forwarder');
    $dom_datas{forwarder2} = $cdb->get_prop('dnscache', 'Forwarder2') || '';
    $c->stash(title => $title, dom_datas => \%dom_datas, domains => \@domains);
    $c->render(template => 'domains');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt     = $c->current_route;
    my $trt    = $c->param('trt');
    my $domain = $c->param('Domain') || '';
    $ddb = esmith::DomainsDB::UTF8->open  || die "Couldn't open domains db";
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open configuration db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";

    #$trt = 'DEL' if ( $rt eq 'domaindel1' );
    #$trt = 'UPD' if ( $rt eq 'domainupd1' );
    #$trt = 'UP2' if ( $rt eq 'domainup21' );
    #$trt = 'ADD' if ( $rt eq 'domainadd1' );
    my %dom_datas = ();
    my $title     = $c->l('dom_FORM_TITLE');
    my $result    = '';
    $dom_datas{'trt'} = $trt;

    if ($trt ne 'ADD' and $trt ne 'UPD' and $trt ne 'UP2' and $trt ne 'DEL') {
        $result = "Trt unknown ( $trt ) !";
    }

    if ($trt eq 'ADD') {

        #nothing
    }

    if ($trt eq 'UPD') {
        my $rec = $ddb->get($domain);

        if ($rec) {
            $dom_datas{domain}      = $domain;
            $dom_datas{description} = $rec->prop('Description') || '';
            $dom_datas{content}     = $rec->prop('Content') || '';
            $dom_datas{nameservers} = $rec->prop('Nameservers') || 'internet';
        } else {
            $result = "Domain $domain not found !";
        }
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'UP2') {
        $dom_datas{forwarder}  = $cdb->get_prop('dnscache', 'Forwarder')  || '';
        $dom_datas{forwarder2} = $cdb->get_prop('dnscache', 'Forwarder2') || '';
    }

    if ($trt eq 'DEL') {
        my $rec = $ddb->get($domain);

        if ($rec) {
            $dom_datas{domain} = $domain;
            $dom_datas{description} = $rec->prop('Description') || '';
        }
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'LST') {
        my @domains;

        if ($adb) {
            @domains = $ddb->domains();
        }
        $c->stash(domains => \@domains);
    } ## end if ($trt eq 'LST')

    if (!$result) {
        $c->stash(error => $result);
    }
    $c->stash(title => $title, dom_datas => \%dom_datas);
    $c->render(template => 'domains');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = $c->param('trt');
    $ddb = esmith::DomainsDB::UTF8->open  || die "Couldn't open domains db";
    $cdb = esmith::ConfigDB::UTF8->open   || die "Couldn't open configuration db";
    $adb = esmith::AccountsDB::UTF8->open || die "Couldn't open accounts db";
    my %dom_datas = ();
    my ($res, $result) = ('') x 2;

    my $domain = $c->param('Domain');
    my $description = $c->param('Description');
    $res    = 'OK';
    $result = '';

    if (($trt eq 'ADD') or ($trt eq 'UPD')) {
        # Validation: stop at the first error.
        for my $check (
            sub { $c->validate_Domain($domain) },
            sub { $c->validate_Description($description) },
        ) {
            $res = $check->();

            if ($res ne 'OK') {
               $result = $c->l($res,$domain);
               last;
            }
        }
    }

    if ($trt eq 'ADD') {
        if (!$result) {
            $res = $c->create_modify_domain('create', $domain);
            $result .= $res unless $res eq 'OK';
        }

        if (!$result) {
            $result = $c->l('dom_SUCCESSFULLY_CREATED') . " $domain";
        }
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD') {
        if (!$result) {
            $res = $c->create_modify_domain('modify', $domain);
            $result .= $res unless $res eq 'OK';
        }

        if (!$result) {
            $result = $c->l('dom_SUCCESSFULLY_MODIFIED') . " $domain";
        }
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'UP2') {
        my $forwarder  = $c->param('Forwarder');
        my $forwarder2 = $c->param('Forwarder2');

        # controls
        $res = $c->ip_number_or_blank($forwarder);
        $result .= $res unless $res eq 'OK';
        $res = $c->ip_number_or_blank($forwarder2);
        $result .= $res unless $res eq 'OK';

        #$result .= 'blocked';
        $res = '';

        if (!$result) {
            $res = $c->modify_dns($forwarder, $forwarder2);
            $result .= $res unless $res eq 'OK';
        }

        if (!$result) {
            $result = $c->l('SUCCESS') . " $forwarder $forwarder2";
        }
    } ## end if ($trt eq 'UP2')

    if ($trt eq 'DEL') {

        # controls
        #$res = validate_is_domain($c, $domain);
        #$result .= $res unless $res eq 'OK';
        #$result .= 'blocked';
        $res = '';

        if (!$result) {
            $res = $c->delete_domain($domain);
            $result .= $res unless $res eq 'OK';
        }

        if (!$result) {
            $result = $c->l('dom_SUCCESSFULLY_DELETED') . " $domain";
        }
    } ## end if ($trt eq 'DEL')

    # common parts
    if ($res ne 'OK') {
        my $title = $c->l('dom_FORM_TITLE');
        $dom_datas{'domain'} = $domain;
        $dom_datas{'trt'}    = $trt;
        $c->stash(error => $result );
        $c->stash(title => $title, dom_datas => \%dom_datas);
        return $c->render('domains');
    } ## end if ($res ne 'OK')
    my $message = "'Domains' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('/domains');
} ## end sub do_update

sub create_modify_domain {
    my ($c, $action, $domain) = @_;
    $domain = $1 if ($domain =~ /^($REGEXP_DOMAIN)$/);

    unless ($domain) {
        return (
            $c->l(
                $action eq 'create'
                ? 'dom_ERROR_CREATING_DOMAIN'
                : 'dom_ERROR_MODIFYING_DOMAIN'
                )
                . ' Ctl'
        );
    } ## end unless ($domain)
    $ddb = esmith::DomainsDB::UTF8->open  || die "Couldn't open domains db";
    my $rec = $ddb->get($domain);

    if ($rec and $action eq 'create') {
        return $c->l('dom_DOMAIN_IN_USE_ERROR');
    }

    if (not $rec and $action eq 'modify') {
        return $c->l('dom_NONEXISTENT_DOMAIN_ERROR',$domain);
    }
    $rec ||= $ddb->new_record($domain, { type => 'domain' });
    my %props;
    $props{$_} = $c->param($_) for (qw(Content Description Nameservers));
    $rec->merge_props(%props);

    if (system("/sbin/e-smith/signal-event", "domain-$action", "$domain") != 0) {
        return (
            $c->l(
                $action eq 'create'
                ? 'dom_ERROR_CREATING_DOMAIN'
                : 'dom_ERROR_MODIFYING_DOMAIN'
                )
                . " Exe $action"
        );
    } ## end if (system("/sbin/e-smith/signal-event"...))
    return 'OK';
} ## end sub create_modify_domain

sub delete_domain {
    my ($c, $domain) = @_;
    $domain = $1 if ($domain =~ /^($REGEXP_DOMAIN)$/);
    return ($c->l('dom_ERROR_WHILE_REMOVING_DOMAIN') . ' Ctl') unless ($domain);
    my $rec = $ddb->get($domain);
    return ($c->l('dom_NONEXISTENT_DOMAIN_ERROR',$domain)) if (not $rec);
    $rec->set_prop('type', 'domain-deleted');

    if (system("/sbin/e-smith/signal-event", "domain-delete", "$domain") != 0) {
        return ($c->l('dom_ERROR_WHILE_REMOVING_DOMAIN',$domain) . 'Exe');
    }
    $rec->delete;
    return 'OK';
} ## end sub delete_domain

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

    unless (system("/sbin/e-smith/signal-event", "dns-update") == 0) {
        return $c->l('dom_ERROR_UPDATING');
    }
    return 'OK';
} ## end sub modify_dns

sub existing_accounts_list {
    my $c = shift;
    my @existingAccounts = ([ 'Administrator' => 'admin' ]);

    foreach my $a ($adb->get_all) {
        if ($a->prop('type') =~ /(user|group)/) {
            push @existingAccounts, [ $a->key => $a->key ];
        }

        if ($a->prop('type') eq "domain") {
            my $target = $adb->get($a->prop('Account'));

            unless ($target) {
                warn "WARNING: domain (" . $a->key . ") => missing Account(" . $a->prop('Account') . ")\n";
                next;
            }
            push @existingAccounts, [ $a->key, $a->key ]
                unless ($target->prop('type') eq "domain");
        } ## end if ($a->prop('type') eq...)
    } ## end foreach my $a ($adb->get_all)
    return (\@existingAccounts);
} ## end sub existing_accounts_list

sub content_options_list {
    my $c = shift;
    my @options = ([ $c->l('dom_PRIMARY_SITE') => 'Primary' ]);

    foreach ($adb->ibays) {
        push @options, [ $_->prop('Name') => $_->key ]
            if ($_->key ne 'Primary');
    }
    return \@options;
} ## end sub content_options_list

sub get_content_value {
    my $c      = shift;
    my $domain = shift;
    return $domain ? $ddb->get_prop($domain, 'Content') : 'Primary';
} ## end sub get_content_value

sub get_description_value {
    my $c = shift;
    my $domain = $c->param('Domain') || undef;
    return $ddb->get_prop($domain, 'Description');
} ## end sub get_description_value

sub nameserver_options_list {
    my $c      = shift;
    my $domain = $c->param('Domain') || undef;
    my @opts   = qw(localhost internet);

    my $has_forwarder = $cdb->get_prop('dnscache', 'Forwarder');
    push @opts, 'corporate' if $has_forwarder;

    my $ns = ($ddb->get_prop($domain, 'Nameservers') || 'internet');
    push @opts, $ns unless scalar grep {/^$ns$/} @opts;

    my %ns_label_key = (
        localhost => 'dom_localhost',
        internet  => 'dom_internet',
    );
    $ns_label_key{corporate} = 'dom_corporate' if $has_forwarder;

    my @options;
    foreach (@opts) {
        my $label = $ns_label_key{$_} ? $c->l( $ns_label_key{$_} ) : $_;   # raw fallback for a legacy/custom value
        push @options, [ $label => $_ ];
    }
    return \@options;
} ## end sub nameserver_options_list

sub get_nameserver_value {
    my $c = shift;
    $ddb = esmith::DomainsDB::UTF8->open  || die "Couldn't open domains db";
    my $domain = $c->param('Domain') || undef;
    return ($ddb->get_prop($domain, 'Nameservers') || 'internet');
} ## end sub get_nameserver_value

sub validate_Domain {
    my $c      = shift;
    my $domain = lc shift;
    return ($domain =~ /^($REGEXP_DOMAIN)$/)
        ? 'OK'
        : 'dom_DOMAIN_NAME_VALIDATION_ERROR';
} ## end sub validate_Domain

sub validate_Description {
    my $c           = shift;
    my $description = shift;
    return ($description =~ /^([\-\'\w][\-\'\w\s\.]*)$/)
        ? 'OK'
        : 'dom_DOMAIN_DESCRIPTION_VALIDATION_ERROR';
} ## end sub validate_Description

1;
