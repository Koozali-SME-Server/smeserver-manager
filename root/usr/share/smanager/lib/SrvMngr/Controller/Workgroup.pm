package SrvMngr::Controller::Workgroup;

#----------------------------------------------------------------------
# heading     : Network
# description : Samba workgroup
# navigation  : 6000 700
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);

use esmith::FormMagick::Panel::workgroup;

our $db = esmith::ConfigDB->open || die "Couldn't open config db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my %wkg_datas = ();
    my $title = $c->l('wkg_FORM_TITLE');
    my $modul = '';

    $wkg_datas{'Workgroup'} = ($db->get_prop('smb','Workgroup')) || '';
    $wkg_datas{'ServerName'} = ($db->get_prop('smb','ServerName')) || '';
    $wkg_datas{'ServerRole'} = ($db->get_prop('smb','ServerRole')) || '';
    $wkg_datas{'RoamingProfiles'} = ($db->get_prop('smb','RoamingProfiles')) || '';

    $c->stash( title => $title, modul => $modul, wkg_datas => \%wkg_datas );
    $c->render(template => 'workgroup');
};


sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my $result = "";

    my $workgroup = ($c->param('Workgroup') || 'no');
    my $servername = ($c->param('ServerName') || 'WS');
    my $roamingprofiles = ($c->param('RoamingProfiles') || 'no');
    my $serverrole = ($c->param('ServerRole') || 'WS');

    # controls
    my $res = validate2_workgroup($c, $workgroup, $servername);
    $result .= $res unless $res eq 'OK';

    $res = validate2_servername($c, $servername);
    $result .= $res unless $res eq 'OK';

    if ($result eq '') {
        $db->get('smb')->set_prop('Workgroup', $workgroup);
	$db->get('smb')->set_prop('ServerRole', $serverrole);
        $db->get('smb')->set_prop('ServerName', $servername);
        $db->get('smb')->set_prop('RoamingProfiles', $roamingprofiles);
    }
    
    system( "/sbin/e-smith/signal-event", "workgroup-update" ) == 0
	or $result = $c->l('ERROR_UPDATING') . " system";

    my $title = $c->l('wkg_FORM_TITLE');

    if ( $result eq '' ) { $result = $c->l('wkg_SUCCESS'); }

    $c->stash( title => $title, modul => $result );
    $c->render(template => 'module');

};


sub validate2_servername {
    my $c = shift;
    my $servername = shift;

    return ('OK') if ( $servername =~ /^([a-zA-Z][\-\w]*)$/ );

    return $c->l('INVALID_SERVERNAME');
}


sub validate2_workgroup {
    my $c = shift;
    my $workgroup = lc(shift);
    my $servername = lc(shift);
#    my $workgroup = $c->l(shift);
#    my $servername = $c->l(shift);

    return $c->l('INVALID_WORKGROUP') unless ( $workgroup =~ /^([a-zA-Z0-9][\-\w\.]*)$/ );
    return $c->l('INVALID_WORKGROUP_MATCHES_SERVERNAME') if ( $servername eq $workgroup);
    return ('OK'); 

}


1;
