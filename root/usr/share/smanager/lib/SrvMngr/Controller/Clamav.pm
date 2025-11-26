package SrvMngr::Controller::Clamav;

#----------------------------------------------------------------------
# heading     : System
# description : Antivirus (ClamAV)
# navigation  : 4000 600
#
# routes : end
#------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use esmith::ConfigDB::UTF8;

our $db;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %clm_datas = ();
    my $title     = $c->l('clm_FORM_TITLE');
    my $modul     = $c->render_to_string(inline => $c->l('clm_DESC_FILESYSTEM_SCAN_PERIOD'));
    $db = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    $clm_datas{'FilesystemScan'} = ($db->get_prop('clamav', 'FilesystemScan')) || 'disabled';
    $clm_datas{'Quarantine'}     = ($db->get_prop('clamav', 'Quarantine'))     || 'disabled';
    $clm_datas{'clam_versions'}  = get_clam_versions();
    $c->stash(title => $title, modul => $modul, clm_datas => \%clm_datas);
    $c->render(template => 'clamav');
} ## end sub main

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $http_clamav_status = $c->param('http_clamav_status') || 'disabled';
    my $smtp_clamav_status = $c->param('smtp_clamav_status') || '';
    my $result             = "";
    $c->change_settings();

    # Update the system
    system("/sbin/e-smith/signal-event clamscan-update") == 0
        or $result = $c->l('clm_ERROR_UPDATING_CONFIGURATION');

    if (!$result) {
        $result = $c->l('clm_SUCCESS');
        $c->flash(success => $result);
    } else {
        $c->flash(error => $result);
    }
    $c->redirect_to('/clamav');
} ## end sub do_update

sub change_settings {
    my $c                  = shift;
    $db = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    my $status             = $c->param('status');
    my $FilesystemScan     = ($c->param('FilesystemScan') || 'disabled');
    my $Quarantine         = ($c->param('Quarantine') || 'disabled');
    my $DatabaseMirror     = ($c->param('DatabaseMirror') || 'db.us.clamav.net');
    my $UpdateOfficeHrs    = ($c->param('UpdateOfficeHrs') || 'disabled');
    my $UpdateNonOfficeHrs = ($c->param('UpdateNonOfficeHrs') || 'disabled');
    my $UpdateWeekend      = ($c->param('UpdateWeekend') || 'disabled');
    my $HTTPProxyServer    = ($c->param('HTTPProxyServer') || '');
    my $HTTPProxyPort      = ($c->param('HTTPProxyPort') || '');
    my $HTTPProxyUsername  = ($c->param('HTTPProxyUsername') || '');
    my $HTTPProxyPassword  = ($c->param('HTTPProxyPassword') || '');
    my $clamav             = $db->get('clamav') || $db->new_record('clamav', { type => 'service' });
    $status ||= $clamav->prop('status');
    $clamav->merge_props(
        status             => $status,
        FilesystemScan     => $FilesystemScan,
        Quarantine         => $Quarantine,
        DatabaseMirror     => $DatabaseMirror,
        UpdateOfficeHrs    => $UpdateOfficeHrs,
        UpdateNonOfficeHrs => $UpdateNonOfficeHrs,
        UpdateWeekend      => $UpdateWeekend,
        HTTPProxyServer    => $HTTPProxyServer,
        HTTPProxyPort      => $HTTPProxyPort,
        HTTPProxyUsername  => $HTTPProxyUsername,
        HTTPProxyPassword  => $HTTPProxyPassword,
    );
} ## end sub change_settings

sub get_clam_versions {
    my $version = `/usr/bin/freshclam -V`;
    chomp $version;
    $version =~ s/^ClamAV //;
    return $version;
} ## end sub get_clam_versions
1;
