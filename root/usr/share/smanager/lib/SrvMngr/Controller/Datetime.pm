package SrvMngr::Controller::Datetime;

#----------------------------------------------------------------------
# heading     : System
# description : Date and time
# navigation  : 4000 300
# routes : end
#------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use esmith::util;
use SrvMngr qw( gen_locale_date_string );
use esmith::ConfigDB::UTF8;
our $cdb ;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %dat_datas = ();
    my $title     = $c->l('dat_FORM_TITLE');
    my $modul     = $c->l('dat_INITIAL_DESC');
    $dat_datas{ntpstatus} = 'disabled';
    $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    my $rec = $cdb->get('ntpd');

    if ($rec) {
        $dat_datas{'ntpserver'} = $rec->prop('NTPServer') || '';

        if ($rec->prop('status') eq 'enabled') {
            $dat_datas{ntpstatus} = 'enabled'
                unless ($rec->prop('SyncToHWClockSupported') || 'yes') eq 'yes' and $dat_datas{ntpserver} =~ m#^\s*$#;
        }
    } ## end if ($rec)
    (   $dat_datas{weekday}, $dat_datas{monthname}, $dat_datas{month},  $dat_datas{day}, $dat_datas{year},
        $dat_datas{hour},    $dat_datas{minute},    $dat_datas{second}, $dat_datas{ampm}
        )
        = split /\|/,
        `/bin/date '+%A|%B|%-m|%-d|%Y|%-I|%M|%S|%p'`;

    # get rid of trailing carriage return on last field
    chop($dat_datas{ampm});
    $dat_datas{'now_string'} = gen_locale_date_string;
    $c->stash(title => $title, modul => $modul, dat_datas => \%dat_datas);
    $c->render('datetime');
} ## end sub main

sub do_update {
    my $c         = shift;
    my %dat_datas = ();
    my $title     = $c->l('dat_FORM_TITLE');
    my $modul     = $c->l('dat_INITIAL_DESC');
    my $result;
    my $success;
    my $old_ntpstatus = $c->param('Old_ntpstatus');
    $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    $dat_datas{ntpstatus} = $c->param('Ntpstatus');

    if ($dat_datas{ntpstatus} ne $old_ntpstatus) {
        if ($dat_datas{ntpstatus} eq 'disabled') {
            (   $dat_datas{weekday}, $dat_datas{monthname}, $dat_datas{month},
                $dat_datas{day},     $dat_datas{year},      $dat_datas{hour},
                $dat_datas{minute},  $dat_datas{second},    $dat_datas{ampm}
                )
                = split /\|/,
                `/bin/date '+%A|%B|%-m|%-d|%Y|%-I|%M|%S|%p'`;

            # get rid of trailing carriage return on last field
            chop($dat_datas{ampm});
        } else {
            $dat_datas{ntpserver} = ($cdb->get_prop('ntpd', 'NTPServer')) || '';
        }
        $dat_datas{now_string} = gen_locale_date_string();
        $c->stash(title => $title, modul => $modul, dat_datas => \%dat_datas);
        return $c->render('datetime');
    } ## end if ($dat_datas{ntpstatus...})

    if ($dat_datas{ntpstatus} eq 'enabled') {

        # update ntpserver
        $dat_datas{ntpserver} = $c->param('Ntpserver') || '';

        if ($dat_datas{ntpserver} eq "pool.ntp.org") {
            $result .= $c->l('dat_INVALID_NTP_ADDR');
        } elsif ($dat_datas{ntpserver} =~ /^([a-zA-Z0-9\.\-]+)$/) {
            $dat_datas{ntpserver} = $1;

            #        } elsif ( $dat_datas{ntpserver} =~ /^\s*$/ ) {
            #            $dat_datas{ntpserver} = "";
        } else {
            $result .= $c->l('dat_INVALID_NTP_ADDR');
        }

        if (!$result) {
            $success = update_ntpserver($c, $dat_datas{ntpserver});
        }
    } else {

        # set Locale time & clean ntpserver
        #my $servername = ($c->param('ServerName') || 'WS');
        if (!$result) {
            $result = validate_change_datetime($c);

            if ($result eq 'OK') {
                $success = $c->l('dat_UPDATING_CLOCK');
                $result  = '';
                disable_ntp();
                $success .= '<br>' . $c->l('dat_SERVER_DISABLED_DESC');
            } ## end if ($result eq 'OK')
        } ## end if (!$result)
    } ## end else [ if ($dat_datas{ntpstatus...})]

    if ($result) {
        $c->stash(error => $result);
        $c->stash(title => $title, modul => $modul, dat_datas => \%dat_datas);
        return $c->render('datetime');
    } ## end if ($result)

    #$result = $c->l('dat_SUCCESS');
    my $message = "'Datetime' update DONE";
    $c->app->log->info($message);
    $c->flash(success => $success);
    $c->redirect_to('/datetime');
} ## end sub do_update

sub validate_change_datetime {
    my $c = shift;
    $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";

    #--------------------------------------------------
    # Untaint parameters and check for validity
    #--------------------------------------------------
    my $timezone = $c->param('Timezone');

    if ($timezone =~ /^([\w\-]+\/?[\w\-+]*)$/) {
        $timezone = $1;
    } else {
        $timezone = "US/Eastern";
    }
    my $month = $c->param('Month');

    if ($month =~ /^(\d{1,2})$/) {
        $month = $1;
    } else {
        $month = "1";
    }

    if (($month < 1) || ($month > 12)) {
        return $c->l('dat_INVALID_MONTH') . " $month. " . $c->l('dat_MONTH_BETWEEN_1_AND_12');
    }
    my $day = $c->param('Day');

    if ($day =~ /^(\d{1,2})$/) {
        $day = $1;
    } else {
        $day = "1";
    }

    if (($day < 1) || ($day > 31)) {
        return $c->l('dat_INVALID_DAY') . " $day. " . $c->l('dat_BETWEEN_1_AND_31');
    }
    my $year = $c->param('Year');

    if ($year =~ /^(\d{4})$/) {
        $year = $1;
    } else {
        $year = "2000";
    }

    if (($year < 1900) || ($year > 2200)) {
        return $c->l('dat_INVALID_YEAR') . " $year. " . $c->l('dat_FOUR_DIGIT_YEAR');
    }
    my $hour = $c->param('Hour');

    if ($hour =~ /^(\d{1,2})$/) {
        $hour = $1;
    } else {
        $hour = "12";
    }

    if (($hour < 1) || ($hour > 12)) {
        return $c->l('dat_INVALID_HOUR') . " $hour. " . $c->l('dat_BETWEEN_1_AND_12');
    }
    my $minute = $c->param('Minute');

    if ($minute =~ /^(\d{1,2})$/) {
        $minute = $1;
    } else {
        $minute = "0";
    }

    if (($minute < 0) || ($minute > 59)) {
        return $c->l('datINVALID_MINUTE') . " $minute. " . $c->l('dat_BETWEEN_0_AND_59');
    }
    my $second = $c->param('Second');

    if ($second =~ /^(\d{1,2})$/) {
        $second = $1;
    } else {
        $second = "0";
    }

    if (($second < 0) || ($second > 59)) {
        return $c->l('dat_INVALID_SECOND') . " $second. " . $c->l('dat_BETWEEN_0_AND_59');
    }
    my $ampm = $c->param('Ampm');

    if ($ampm =~ /^(AM|PM)$/) {
        $ampm = $1;
    } else {
        $ampm = "AM";
    }

    # convert to 24 hour time
    $hour = $hour % 12;

    if ($ampm eq "PM") {
        $hour = $hour + 12;
    }

    #--------------------------------------------------
    # Store time zone in configuration database
    #--------------------------------------------------
    my $old  = $cdb->get('UnsavedChanges')->value;
    my $rec  = $cdb->get('TimeZone');

    unless ($rec) {
        $rec = $cdb->new_record('TimeZone', undef);
    }
    $rec->set_value($timezone);
    $cdb->get('UnsavedChanges')->set_value($old);

    #--------------------------------------------------
    # Signal event to change time zone, system time
    # and hardware clock
    #--------------------------------------------------
    my $newdate = sprintf "%02d%02d%02d%02d%04d.%02d", $month, $day, $hour, $minute, $year, $second;
    esmith::util::backgroundCommand(2, "/sbin/e-smith/signal-event", "timezone-update", $newdate);
    return 'OK';
} ## end sub validate_change_datetime

sub update_ntpserver {
    my $c         = shift;
    my $ntpserver = shift;
    my $msg;

    #------------------------------------------------------------
    # Looks good; go ahead and change the parameters.
    #------------------------------------------------------------
    my $old = $cdb->get('UnsavedChanges')->value;
    my $rec = $cdb->get('ntpd');

    if ($rec) {
        $rec->set_prop('status',    'enabled');
        $rec->set_prop('NTPServer', $ntpserver);
    } else {
        $rec = $cdb->new_record('ntpd',
            { type => 'service', status => 'enabled', SyncToHWClockSupported => 'yes', NTPServer => $ntpserver });
    }
    $cdb->get('UnsavedChanges')->set_value($old);
    $msg = $c->l('dat_SETTINGS_CHANGED');

    if ($ntpserver =~ /^\s*$/) {
        $rec->set_prop('status', ($rec->prop('SyncToHWClockSupported') || 'yes') eq 'yes' ? 'enabled' : 'disabled');
        $rec->set_prop('NTPServer', '');
        $msg = $c->l('dat_INVALID_NTP_SERVER') if ($rec->prop('SyncToHWClockSupported') || 'yes') ne 'yes';
    } ## end if ($ntpserver =~ /^\s*$/)
    esmith::util::backgroundCommand(2, "/sbin/e-smith/signal-event", "timeserver-update");
    return $msg;
} ## end sub update_ntpserver

sub disable_ntp {

    # make sure that the parameters are set for disabled
    my $old = $cdb->get('UnsavedChanges')->value;
    my $rec = $cdb->get('ntpd');

    if ($rec) {
        $rec->set_prop('status', ($rec->prop('SyncToHWClockSupported') || 'yes') eq 'yes' ? 'enabled' : 'disabled');
        $rec->set_prop('NTPServer', '');
    } else {
        $rec = $cdb->new_record('ntpd',
            { type => 'service', status => 'enabled', SyncToHWClockSupported => 'yes', NTPServer => '' });
    }
    $cdb->get('UnsavedChanges')->set_value($old);
} ## end sub disable_ntp

sub getTimezone {

    #--------------------------------------------------
    # Figure out time zone by looking first looking at
    # the configuration database value of TimeZone.
    # If that is not defined, try and get it from /etc/localtime.
    # If that doesn't work, default to US/Eastern.
    #--------------------------------------------------
    my $localtime;
    my $timezonedefault = "US/Eastern";

    if (defined $cdb->get('TimeZone')) {
        $timezonedefault = $cdb->get('TimeZone')->value;
    } else {

        if (defined($localtime = readlink '/etc/localtime')) {
            my $pos = index $localtime, 'zoneinfo/';

            if ($pos > -1) {
                $timezonedefault = substr $localtime, ($pos + 9);
            }
        } ## end if (defined($localtime...))
    } ## end else [ if (defined $cdb->get(...))]
    return $timezonedefault;
} ## end sub getTimezone

sub getZone_list {
    my $c = shift;

    #--------------------------------------------------
    # Get a sorted list of time zones
    #--------------------------------------------------
    $ENV{BASH_ENV} = '';

    if (!open(ZONES, "cd /usr/share/zoneinfo; /usr/bin/find . -type f -or -type l | /bin/grep '^./[A-Z]' |")) {
        warn($c->l('COULD_NOT_OPEN_TZ_FILE') . $! . '.');
        return undef;
    }
    my $zone;
    my @zones = ();

    while (defined($zone = <ZONES>)) {
        chop($zone);
        $zone =~ s/^.\///;
        push @zones, $zone;
    } ## end while (defined($zone = <ZONES>...))
    close ZONES;
    my @zt = sort @zones;
    return \@zt;
} ## end sub getZone_list

sub getMonth_list {
    my $c = shift;
    return [
        [ $c->l('dat_JANUARY')   => '1' ],
        [ $c->l('dat_FEBRUARY')  => '2' ],
        [ $c->l('dat_MARCH')     => '3' ],
        [ $c->l('dat_APRIL')     => '4' ],
        [ $c->l('dat_MAY')       => '5' ],
        [ $c->l('dat_JUNE')      => '6' ],
        [ $c->l('dat_JULY')      => '7' ],
        [ $c->l('dat_AUGUST')    => '8' ],
        [ $c->l('dat_SEPTEMBER') => '9' ],
        [ $c->l('dat_OCTOBER')   => '10' ],
        [ $c->l('dat_NOVEMBER')  => '11' ],
        [ $c->l('dat_DECEMBER')  => '12' ]
    ];
} ## end sub getMonth_list

sub getYear_list {
    my $c= shift;
    my @yearArray;
    # could use also `/bin/date '+%Y'`
    my $start=2025-40; my $max=2025+40;
    for ( my $i = $start; $i <= $max; $i++ ) {

        push @yearArray,$i;
    }

    my @yearList = sort @yearArray;
    return \@yearList;

} ## end sub getYear_list

1;
