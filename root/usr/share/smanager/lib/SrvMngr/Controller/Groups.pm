package SrvMngr::Controller::Groups;

#----------------------------------------------------------------------
# heading     : User management
# description : GROUPS
# navigation  : 2000 200
#----------------------------------------------------------------------
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
#use esmith::FormMagick::Panel::groups;
use esmith::AccountsDB;
our $cdb = esmith::ConfigDB->open   || die "Couldn't open configuration db";
our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %grp_datas = ();
    my $title     = $c->l('grp_FORM_TITLE');
    $grp_datas{trt} = 'LST';
    my @groups;

    if ($adb) {
        @groups = $adb->groups();
    }
    $c->stash(title => $title, grp_datas => \%grp_datas, groups => \@groups);
    $c->render(template => 'groups');
} ## end sub main

sub do_display {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LST');
    my $group     = $c->param('group');
    my %grp_datas = ();
    my $title     = $c->l('grp_FORM_TITLE');
    $grp_datas{'trt'} = $trt;

    if ($trt eq 'ADD') {

        #nothing
    }

    if ($trt eq 'UPD') {
        my %members = ();
        my %users   = ();
        my $rec     = $adb->get($group);

        if ($rec and $rec->prop('type') eq 'group') {
            $grp_datas{group}       = $group;
            $grp_datas{description} = $rec->prop('Description') || '';
            %members                = @{ $c->gen_members_list($group) };
        } ## end if ($rec and $rec->prop...)
        $c->stash(members => \%members, users => \%users);
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'DEL') {
        my %members = ();
        my %ibays   = ();
        my $rec     = $adb->get($group);

        if ($rec and $rec->prop('type') eq 'group') {
            $grp_datas{group}       = $group;
            $grp_datas{description} = $rec->prop('Description') || '';
            %members                = @{ $c->gen_members_list($group) };
            %ibays                  = @{ $c->gen_ibays_list($group) };
        } ## end if ($rec and $rec->prop...)
        $c->stash(members => \%members, ibays => \%ibays);
    } ## end if ($trt eq 'DEL')

    if ($trt eq 'LST') {
        my @groups;

        if ($adb) {
            @groups = $adb->groups();
        }
        $c->stash(groups => \@groups);
    } ## end if ($trt eq 'LST')
    $c->stash(title => $title, grp_datas => \%grp_datas);
    $c->render(template => 'groups');
} ## end sub do_display

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $rt        = $c->current_route;
    my $trt       = ($c->param('trt') || 'LST');
    my $groupName = $c->param('groupName') || '';
    my $title     = $c->l('grp_FORM_TITLE');
    my ($res, $result) = '';
    my %grp_datas = ();
    $grp_datas{'trt'}   = $trt;
    $grp_datas{'group'} = $groupName;
    my @members = ();

    if ($trt eq 'ADD') {
        my $groupDesc = $c->param('groupDesc');
        @members = @{ $c->every_param('groupMembers') };
        my $members = join(",", @members);

        # controls
        $res = $c->validate_group($groupName);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = $c->validate_group_length($groupName);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = $c->validate_group_naming_conflict($groupName);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = $c->validate_description($groupDesc);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = $c->validate_group_has_members(@members);
        $result .= $res . '<br>' unless $res eq 'OK';
        my %props = ('type', 'group', 'Description', $groupDesc, 'Members', $members);
        $res = '';

        if (!$result) {
            $adb->new_record($groupName, \%props);

            # Untaint groupName before use in system()
            ($groupName) = ($groupName =~ /^([a-z][\-\_\.a-z0-9]*)$/);
            system("/sbin/e-smith/signal-event", "group-create", "$groupName") == 0
                or $result .= $c->l('qgp_CREATE_ERROR') . "\n";
        } ## end if (!$result)

        if (!$result) {
            $result = $c->l('grp_CREATED_GROUP') . ' ' . $groupName;
            $res    = 'OK';
        }
    } ## end if ($trt eq 'ADD')

    if ($trt eq 'UPD') {
        my $groupDesc = $c->param('groupDesc');
        @members = @{ $c->every_param('groupMembers') };
        my $members = join(",", @members);

        # controls
        $res = '';
        $res = validate_description($c, $groupDesc);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = validate_group_has_members($c, @members);
        $result .= $res . '<br>' unless $res eq 'OK';
        $res = '';

        if (!$result) {
            $adb->get($groupName)->set_prop('Members',     $members);
            $adb->get($groupName)->set_prop('Description', $groupDesc);

            # Untaint groupName before use in system()
            ($groupName) = ($groupName =~ /^([a-z][\-\_\.a-z0-9]*)$/);
            system("/sbin/e-smith/signal-event", "group-modify", "$groupName") == 0
                or $result .= $c->l('qgp_MODIFY_ERROR') . "\n";
        } ## end if (!$result)

        if (!$result) {
            $result = $c->l('grp_MODIFIED_GROUP') . ' ' . $groupName;
            $res    = 'OK';
        }
    } ## end if ($trt eq 'UPD')

    if ($trt eq 'DEL') {
        if ($groupName =~ /^([a-z][\-\_\.a-z0-9]*)$/) {
            $groupName = $1;
        } else {
            $result .= $c->l('grp_ERR_INTERNAL_FAILURE') . ':' . $groupName;
        }
        my $rec = $adb->get($groupName);
        $result .= $c->l('grp_ERR_INTERNAL_FAILURE') . ':' . $groupName unless ($rec);
        $res = '';

        if (!$result) {
            $res = delete_group($c, $groupName);
            $result .= $res unless $res eq 'OK';

            if (!$result) {
                $result = $c->l('grp_DELETED_GROUP') . ' ' . $groupName;
                $res    = 'OK';
            }
        } ## end if (!$result)
    } ## end if ($trt eq 'DEL')

    # common parts
    if ($res ne 'OK') {
        $c->stash(error => $result);
        my %members = @{ $c->gen_members_list($groupName) };
        $c->stash(title => $title, members => \%members, grp_datas => \%grp_datas);
        return $c->render('groups');
    } ## end if ($res ne 'OK')
    my $message = "'Groups' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash(success => $result);
    $c->redirect_to('/groups');
} ## end sub do_update

sub delete_group {
    my ($c, $groupName) = @_;

    # Update the db account (1)
    $adb->get($groupName)->set_prop('type', 'group-deleted');

    # Untaint groupName before use in system()
    ($groupName) = ($groupName =~ /^([a-z][\-\_\.a-z0-9]*)$/);
    return (system("/sbin/e-smith/signal-event", "group-delete", "$groupName") || !$adb->get($groupName)->delete())
        ? $c->l('DELETE_ERROR')
        : 'OK';
} ## end sub delete_group

sub gen_members_list {
    my ($c, $group) = @_;
    my @members = ();
    my $rec     = $adb->get($group);
    @members = split(/,/, $rec->prop('Members')) if ($rec);
    my %names;

    foreach my $m (@members) {
        my $name;

        if ($m eq 'admin') {
            $name = "Administrator";
        } else {
            $name = $adb->get($m)->prop('FirstName') . " " . $adb->get($m)->prop('LastName');
        }
        $names{$m} = $name;
    } ## end foreach my $m (@members)
    @members = %names;
    return \@members;
} ## end sub gen_members_list

sub gen_ibays_list {
    my ($c, $group) = @_;
    my %names;

    foreach my $ibay ($adb->ibays) {
        if ($ibay->prop('Group') eq $group) {
            $names{ $ibay->key } = $ibay->prop('Name');
        }
    } ## end foreach my $ibay ($adb->ibays)
    my @ibays = %names;
    return \@ibays;
} ## end sub gen_ibays_list

sub gen_users_list {
    my $c = shift;
    my @users = sort { $a->key() cmp $b->key() } $adb->users();
    my %names;

    foreach my $user (@users) {
        $names{ $user->key } = $user->prop('FirstName') . " " . $user->prop('LastName');
    }
    return \%names;
} ## end sub gen_users_list

=head1 VALIDATION

=head2 validate_is_group FM GROUP

returns OK if GROUP is a current group. otherwisee returns "NOT_A_GROUP"

=begin testing

#ok($panel->validate_is_group('root') eq 'OK', "Root is a group");
ok($panel->validate_is_group('ro2ot') eq 'NOT_A_GROUP', "Ro2ot is not a group");

=end testing

=cut

sub validate_is_group () {
    my $c      = shift;
    my $group  = shift;
    my @groups = $adb->groups();
    my %groups = map { $_->key => 1 } @groups;

    unless (exists $groups{$group}) {
        return ($c->l('grp_NOT_A_GROUP'));
    }
    return ("OK");
} ## end sub validate_is_group

=head2 validate_group_naming_conflict FM GROUPNAME 

Returns "OK" if this group's name doesn't conflict with anything
Returns "PSEUDONYM_CONFLICT" if this name conflicts with a pseudonym
Returns "NAME_CONFLICT" if this group name conflicts with anything else

ok (undef, 'need testing for validate_naming_Conflicts');
=cut

sub validate_group_naming_conflict {
    my $c         = shift;
    my $groupName = shift;
    my $account   = $adb->get($groupName);
    my $type;

    if (defined $account) {
        $type = $account->prop('type');
    } elsif (defined getpwnam($groupName) || defined getgrnam($groupName)) {
        $type = "system";
    } else {
        return ('OK');
    }
    return ($c->l('grp_ACCOUNT_CONFLICT', $groupName, $type));
} ## end sub validate_group_naming_conflict

=head2 validate_group FM groupname

Returns OK if the group name contains only valid characters
Returns GROUP_NAMING otherwise

=being testing

ok(validate_group('','foo') eq 'OK', 'foo is a valid group);
ok(validate_group('','f&oo') eq 'GROUP_CONTAINS_INVALD', 'f&oo is not a valid group);

=end testing

=cut

sub validate_group {
    my $c         = shift;
    my $groupName = shift;

    unless ($groupName =~ /^([a-z][\-\_\.a-z0-9]*)$/) {
        return $c->l('grp_GROUP_NAMING');
    }
    return ('OK');
} ## end sub validate_group

=head2 validate_group_length FM GROUPNAME

returns 'OK' if the group name is shorter than the maximum group name length
returns 'GROUP_TOO_LONG' otherwise

=begin testing

ok(($panel->validate_group_length('foo') eq 'OK'), "a short groupname passes");
ok(($panel->validate_group_length('fooooooooooooooooo') eq 'GROUP_TOO_LONG'), "a long groupname fails");

=end testing

=cut

sub validate_group_length {
    my $c                  = shift;
    my $groupName          = shift;
    my $maxGroupNameLength = (
          $cdb->get('maxGroupNameLength')
        ? $cdb->get('maxGroupNameLength')->prop('type')
        : ""
        )
        || 12;

    if (length $groupName > $maxGroupNameLength) {
        return $c->l('grp_GROUP_TOO_LONG', $maxGroupNameLength);
    } else {
        return ('OK');
    }
} ## end sub validate_group_length

=head2 validate_group_has_members FM MEMBERS

Validates that the cgi parameter MEMBERS is an array with at least one entry
Returns OK if true. Otherwise, returns NO_MEMBERS


=begin testing

ok(validate_group_has_members('',qw(foo bar)) eq 'OK', "We do ok with a group with two members");

ok(validate_group_has_members('',qw()) eq 'NO_MEMBERS', "We do ok with a group with no members"); 
ok(validate_group_has_members('')  eq 'NO_MEMBERS', "We do ok with a group with undef members");

=end testing

=cut

sub validate_group_has_members {
    my $c       = shift;
    my @members = (@_);
    my $count   = @members;

    if ($count == 0) {
        return ($c->l('grp_NO_MEMBERS'));
    } else {
        return ('OK');
    }
} ## end sub validate_group_has_members

=pod

=head2 validate_description ($description).
Checks the supplied description. Period is allowed in description

=cut

sub validate_description {
    my ($c, $description) = @_;

    if ($description =~ /^([\-\'\w][\-\'\w\s\.]*)$/) {
        return ('OK');
    } else {
        return ($c->l('FM_ERR_UNEXPECTED_DESC'));
    }
} ## end sub validate_description
1
