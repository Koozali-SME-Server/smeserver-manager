package SrvMngr::Model::Main;

use strict;
use warnings;
use utf8;

use esmith::ConfigDB::UTF8;
use esmith::AccountsDB::UTF8;
use esmith::util;

use Net::LDAP qw/LDAP_INVALID_CREDENTIALS/;
our ($cdb,$adb);


sub init_data {

    my %datas = ();

    $cdb = esmith::ConfigDB::UTF8->open_ro() or die("can't open Config DB");
    my $sysconfig = $cdb->get("sysconfig");

    $datas{'lang'} = $sysconfig->prop('Language') || 'en_US';

    ## convert xx_XX lang format to xx-xx + delete .UTFxx + lowercase
    $datas{'lang'} =~ s/_(.*)\..*$/-${1}/;		# just keep 'en-us'
#    $datas{'lang'} = lc( substr( $datas{'lang'},0,2 ));	# just keep 'en'

    $datas{'releaseVersion'} = $sysconfig->prop("ReleaseVersion") || '??';
    $datas{'copyRight'} = 'All rights reserved';

    $datas{'PwdSet'} = ($cdb->get('PasswordSet')->value eq "yes") || '0' ;

    $datas{'SystemName'} = $cdb->get("SystemName")->value;
    $datas{'DomainName'} = $cdb->get("DomainName")->value;

    my $rec = $cdb->get("smanager");
    $datas{'Access'} = $rec->prop('access') || 'private';

    return \%datas;
}


sub reconf_needed {

    $cdb = esmith::ConfigDB::UTF8->open_ro() or die("can't open Config DB");
    #my $unsafe = ($cdb->get('bootstrap-console') and $cdb->get('bootstrap-console')->prop('Run') eq 'yes') ||
    #     ($cdb->get('UnsavedChanges') and $cdb->get('UnsavedChanges')->value eq 'yes') || '0';
	my $unsafe = ($cdb->get('UnsavedChanges') and $cdb->get('UnsavedChanges')->value eq 'yes') || '0';   
    return $unsafe;
}


sub check_credentials {

    my ($c, $username, $password) = @_;
    return unless $username || $password;

    $cdb = esmith::ConfigDB::UTF8->open_ro() or die("can't open Configuration DB");
    my $l = $cdb->get('ldap');
    my $status = $l->prop('status') || "disabled";
    unless ($status eq "enabled" ) {
	warn "Couldn't connect. LDAP service not enabled!\n";
        return;
    }

    my $domain = $cdb->get('DomainName')->value;
    my $base = esmith::util::ldapBase ($domain);

    #  secure & localhost !?
    my $LDAP_server = 'ldaps://localhost';

    my $ldap = Net::LDAP->new( $LDAP_server )
        or warn("Couldn't connect to LDAP server $LDAP_server: $@"), return;

    # this is where we check the password
    my $DN = "uid=$username,ou=Users,$base";

    my $login = $ldap->bind( $DN, password => $password );

    # return 1 on success, 0 on failure with the ternary operator
    return $login->code == LDAP_INVALID_CREDENTIALS ? 0 : 1;
}


sub check_adminalias {

    # is an alias required for admin ? return it or undef
    my $c = shift;

    my $alias;
    $cdb = esmith::ConfigDB::UTF8->open_ro() or die("can't open Configuration DB");
    if (defined $cdb->get('AdminAlias')) {
	$alias = $cdb->get('AdminAlias')->value;
    }
    return undef unless $alias;

    $adb = esmith::AccountsDB::UTF8->open_ro() or die("can't open Accounts DB");
    my $arec = $adb->get( $alias );
    return undef unless $arec;

    # $alias pseudo exists AND points to admin AND is removable (not known pseudos) => OK
    return ( $arec && $arec->prop('type') eq 'pseudonym' && $arec->prop('Account') eq 'admin'
	&& ($arec->prop('Removable') || 'yes') ne 'no' ) ? $alias : undef;

}


1;
