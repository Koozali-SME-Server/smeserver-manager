package SrvMngr::Controller::Directory;

#----------------------------------------------------------------------
# heading     : User management
# description : Directory
# navigation  : 2000 300
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

our $db = esmith::ConfigDB->open() || die "Couldn't open config db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %dir_datas = ();
    my $title     = $c->l('dir_FORM_TITLE');
    my $modul     = $c->render_to_string(inline => $c->l('dir_DESCRIPTION'));
    $dir_datas{'root'}        = get_ldap_base();
    $dir_datas{'access'}      = ($db->get_prop('ldap', 'access')) || 'private';
    $dir_datas{'department'}  = ($db->get_prop('ldap', 'defaultDepartment')) || '';
    $dir_datas{'company'}     = ($db->get_prop('ldap', 'defaultCompany')) || '';
    $dir_datas{'street'}      = ($db->get_prop('ldap', 'defaultStreet')) || '';
    $dir_datas{'city'}        = ($db->get_prop('ldap', 'defaultCity')) || '';
    $dir_datas{'phonenumber'} = ($db->get_prop('ldap', 'defaultPhoneNumber')) || '';
    $c->stash(title => $title, modul => $modul, dir_datas => \%dir_datas);
    $c->render(template => 'directory');
} ## end sub main

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $access      = $c->param('access');
    my $department  = $c->param('department');
    my $company     = $c->param('company');
    my $street      = $c->param('street');
    my $city        = $c->param('city');
    my $phonenumber = $c->param('phonenumber');
    my $existing    = $c->param('existing');
    my $result      = "";
    $db->get('ldap')->set_prop('access',             $access);
    $db->get('ldap')->set_prop('defaultDepartment',  $department);
    $db->get('ldap')->set_prop('defaultCompany',     $company);
    $db->get('ldap')->set_prop('defaultStreet',      $street);
    $db->get('ldap')->set_prop('defaultCity',        $city);
    $db->get('ldap')->set_prop('defaultPhoneNumber', $phonenumber);

    if ($existing eq 'update') {
        my $ac = esmith::AccountsDB->open() || die "Couldn't open accounts db";
        my @users = $ac->users();

        foreach my $user (@users) {
            $user->set_prop('Phone',   $phonenumber);
            $user->set_prop('Company', $company);
            $user->set_prop('Dept',    $department);
            $user->set_prop('City',    $city);
            $user->set_prop('Street',  $street);
        } ## end foreach my $user (@users)
    } ## end if ($existing eq 'update')
    #
    # Update the system
    #
    system("/sbin/e-smith/signal-event ldap-update") == 0
        or $result = $c->l('ERROR_UPDATING_CONFIGURATION');
    my $title = $c->l('dir_FORM_TITLE');
    if ($result eq '') { $result = $c->l('dir_SUCCESS'); }
    $c->stash(title => $title, modul => $result);
    $c->render(template => 'module');
} ## end sub do_update

sub get_ldap_base {
    return esmith::util::ldapBase(get_value('','DomainName'));
}

sub get_value {
    my $fm = shift;
    my $item = shift;

    my $record = $db->get($item);
    if ($record) {
        return $record->value();
    }
    else {
        return '';
    }
}
1;
