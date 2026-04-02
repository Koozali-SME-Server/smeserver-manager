package SrvMngr::Controller::EmailSettingsCustomUI;
use strict;
use warnings;
use esmith::ConfigDB;

sub new {
    my ($class, %args) = @_;

    my $db = $args{db};
    $db ||= esmith::ConfigDB->open
        or die "Couldn't open ConfigDB\n";

    my $self = {
        db       => $db,

        services => {
            smtp_25 => {
                id          => 'smtp_25',
                DBKey       => 'qpsmtpd',
                label       => 'mai_SMTP_port_authenticate',
                description => 'Core SMTP service for mail delivery. Cannot be disabled.',
                type        => 'smtp',
                port        => 25,
                ui          => {
                    options      => [
                        {
                            value   => 'noauth',
                            label   => 'mai_No_Authentication',
                            set     => [
                                { prop => 'status',         value => 'enabled'  },
                                { prop => 'Authentication', value => 'disabled' },
                                { prop => 'access',         value => 'public'    },
                                { prop => 'AuthAccess',     value => 'private'  },
                            ],
                        },
                        {
                            value   => 'localAuth',
                            label   => 'mai_Authentication_allowed_(LAN)',
                            set     => [
                                { prop => 'status',         value => 'enabled'  },
                                { prop => 'Authentication', value => 'enabled' },
                                { prop => 'access',         value => 'public'    },
                                { prop => 'AuthAccess',     value => 'public'   },
                            ],
                        },
                        {
                            value   => 'publicAuth',
                            label   => 'mai_Authentication_allowed_(LAN_and_public)',
                            set     => [
                                { prop => 'status',         value => 'enabled'  },
                                { prop => 'Authentication', value => 'enabled' },
                                { prop => 'access',         value => 'public'    },
                                { prop => 'AuthAccess',     value => 'public'   },
                            ],
                        },
                    ],
                },
            },

            smtps_465 => {
                id          => 'smtps_465',
                DBKey       => 'sqpsmtpd',
                label       => 'mai_SMTPS_SSL/TLS',
                description => 'SMTP (SMTPS) for authenticated clients.',
                type        => 'smtps',
                port        => 465,
                ui          => {
                    options      => [
                        {
                            value   => 'public',
                            label   => 'mai_Enabled_for_local_and_public_access',
                            set     => [
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'public'  },
                            ],
                        },
                        {
                            value   => 'local',
                            label   => 'mai_Enabled_for_local_access_only',
                            set     => [
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'local'   },
                            ],
                        },
                        {
                            value   => 'disabled',
                            label   => 'Disabled',
                            set     => [
                                { prop => 'status', value => 'disabled' },
                                { prop => 'access',  value => 'disabled'   },
                            ],
                        },
                    ],
                },
            },

            submission_587 => {
                id          => 'submission_587',
                DBKey       => 'uqpsmtpd',
                label       => 'mai_Submission_port',
                description => 'Submission port for mail clients (STARTTLS/auth).',
                type        => 'submission',
                port        => 587,
                ui          => {
                    options      => [
                        {
                            value   => 'public',
                            label   => 'mai_Enabled_for_local_and_public_access',
                            set     => [
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'public'  },
                            ],
                        },
                        {
                            value   => 'local',
                            label   => 'mai_Enabled_for_local_access_only',
                            set     => [
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'local'   },
                            ],
                        },
                        {
                            value   => 'disabled',
                            label   => 'Disabled',
                            set     => [
                                { prop => 'status', value => 'disabled' },
                                { prop => 'access',  value => 'disabled'   },
                            ],
                        },
                    ],
                },
            },

            imap_143 => {
               id          => 'imap_143',
               DBKey       => 'imap',
               label       => 'mai_LABEL_IMAP_ACCESS_CONTROL',
               description => 'IMAP service used by mail clients.',
               type        => 'imap',
               ports       => [143, 993],
               ui          => {
                   options      => [
                       {
                           value   => 'disabled',
                           label   => 'Disabled',
                           default => 0,
                           set     => [
                               { key => 'imap',  prop => 'status', value => 'enabled' },
                               { key => 'imap',  prop => 'access', value => 'localhost' },
                               { key => 'imaps', prop => 'status', value => 'enabled' },
                               { key => 'imaps', prop => 'access', value => 'private' },
                           ],
                       },
                       {
                           value   => 'public',
                           label   => 'mai_Enabled_for_local_and_public_access',
                           default => 1,
                           set     => [
                               { key => 'imap',  prop => 'status', value => 'enabled' },
                               { key => 'imap',  prop => 'access', value => 'public' },
                               { key => 'imaps', prop => 'status', value => 'enabled' },
                               { key => 'imaps', prop => 'access', value => 'public' },
                           ],
                       },
                       {
                           value   => 'publicSSL',
                           label   => 'mai_Enabled_for_public_SSL_only',
                           default => 0,
                           set     => [
                               { key => 'imap',  prop => 'status', value => 'enabled' },
                               { key => 'imap',  prop => 'access', value => 'private' },
                               { key => 'imaps', prop => 'status', value => 'enabled' },
                               { key => 'imaps', prop => 'access', value => 'public' },
                           ],
                       },
                       {
                           value   => 'local',
                           label   => 'mai_Enabled_for_local_access_only',
                           default => 0,
                           set     => [
                               { key => 'imap',  prop => 'status', value => 'enabled' },
                               { key => 'imap',  prop => 'access', value => 'private' },
                               { key => 'imaps', prop => 'status', value => 'enabled' },
                               { key => 'imaps', prop => 'access', value => 'private' },
                           ],
                       },
                   ],
               },
            },            
            
            pop_110_995 => {
                id          => 'pop_110_995',
                DBKey       => 'pop3',
                label       => 'mai_LABEL_POP_ACCESS_CONTROL',
                description => 'POP service used by mail clients.',
                type        => 'pop',
                ports       => [110, 995],
                ui          => {
                    options      => [
                        {
                            value   => 'public',
                            label   => 'mai_Enabled_for_local_and_public_access',
                            set     => [
                                { key => 'pop3',  prop => 'status', value => 'enabled' },
                                { key => 'pop3s', prop => 'status', value => 'enabled' },
                                { key => 'pop3',  prop => 'access', value => 'public'  },
                                { key => 'pop3s', prop => 'access', value => 'public'  },
                            ],
                        },
                        {
                            value   => 'publicSSL',
                            label   => 'mai_Enabled_for_public_SSL_only',
                            set     => [
                                { key => 'pop3',  prop => 'status', value => 'enabled' },
                                { key => 'pop3s', prop => 'status', value => 'enabled' },
                                { key => 'pop3',  prop => 'access', value => 'private' },
                                { key => 'pop3s', prop => 'access', value => 'public'  },
                            ],
                        },
                        {
                            value   => 'local',
                            label   => 'mai_Enabled_for_local_access_only',
                            set     => [
                                { key => 'pop3',  prop => 'status', value => 'enabled' },
                                { key => 'pop3s', prop => 'status', value => 'enabled' },
                                { key => 'pop3',  prop => 'access', value => 'private' },
                                { key => 'pop3s', prop => 'access', value => 'private' },
                            ],
                        },
                        {
                            value   => 'disabled',
                            label   => 'Disabled',
                            set     => [
                                { key => 'pop3',  prop => 'status', value => 'disabled' },
                                { key => 'pop3s', prop => 'status', value => 'disabled' },
                                { key => 'pop3',  prop => 'access', value => 'disabled' },
                                { key => 'pop3s', prop => 'access', value => 'disabled' },
                            ],
                        },
                    ],
                },
            }, 
                       
            webmail => {
                id          => 'webmail',
                DBKey       => 'roundcube',
                label       => 'mai_LABEL_WEBMAIL_ACCESS_CONTROL',
                description => 'Webmail access using Roundcube.',
                type        => 'webmail',
                ui          => {
                    options      => [
                        {
                            value   => 'enabledSSL',
                            label   => 'mai_Enabled_for_local_and_public_access',
                            set     => [
                                { key => 'php81-php-fpm', prop => 'status', value => 'enabled' },
                                { key => 'mariadb',       prop => 'status', value => 'enabled' },
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'public'  },
                            ],
                        },
                        {
                            value   => 'localnetworkSSL',
                            label   => 'mai_Enabled_for_local_access_only',
                            set     => [
                                { key => 'php81-php-fpm', prop => 'status', value => 'enabled' },
                                { key => 'mariadb',       prop => 'status', value => 'enabled' },
                                { prop => 'status', value => 'enabled' },
                                { prop => 'access',  value => 'private' },
                            ],
                        },
                        {
                            value   => 'disabled',
                            label   => 'Disabled',
                            set     => [
                                { prop => 'status', value => 'disabled' },
                            ],
                        },
                    ],
                },
            },
        },
    };

    return bless $self, $class;
}

sub l {
    my ($text) = @_;
    return $text;
}

# Return the service definition hash for a given service name.
sub _service {
    my ($self, $service) = @_;
    return $self->{services}{$service};
}

# Return the localized menu options for a service, including labels and defaults.
sub get_menu_options {
    my ($self, $service) = @_;
    my $svc = $self->_service($service) or return [];

    my $opts = $svc->{ui}{options} || [];
    return [
        map {
            +{
                value   => $_->{value},
                label   => l($_->{label}),
                default => $_->{default} ? 1 : 0,
            }
        } @$opts
    ];
}

# Return the localized display label for a service.
sub get_label {
    my ($self, $service) = @_;
    my $svc = $self->_service($service) or return;
    return $svc->{label};
}

# Return the localized description text for a service.
sub get_description {
    my ($self, $service) = @_;
    my $svc = $self->_service($service) or return;
    return $svc->{description};
}

# MAY NOT BNEEDED vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Read the current Status value for a service from the e-smith DB.
sub get_current_status {
    my ($self, $service) = @_;
    my $svc = $self->_service($service) or return;
    return $self->{db}->get_prop($svc->{DBKey}, $svc->{DBStatus});
}

# Write the Status value for a service to the e-smith DB and return the updated value.
sub set_status {
    my ($self, $service, $value) = @_;
    my $svc = $self->_service($service) or return;
    $self->{db}->set_prop($svc->{DBKey}, $svc->{DBStatus}, $value);
    return $self->{db}->get_prop($svc->{DBKey}, $svc->{DBStatus});
}

# Read the current Access value for a service from the e-smith DB.
sub get_current_access {
    my ($self, $service) = @_;
    my $svc = $self->_service($service) or return;
    return $self->{db}->get_prop($svc->{DBKey}, $svc->{DBAccess});
}

# Write the Access value for a service to the e-smith DB and return the updated value.
sub set_current_access {
    my ($self, $service, $value) = @_;
    my $svc = $self->_service($service) or return;
    $self->{db}->set_prop($svc->{DBKey}, $svc->{DBAccess}, $value);
    return $self->{db}->get_prop($svc->{DBKey}, $svc->{DBAccess});
}
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## Apply the selected UI option by writing one or more e-smith DB properties.
#sub apply_option {
    #my ($self, $service, $option_value) = @_;

    #my $svc = $self->_service($service) or return;
    #my $options = $svc->{ui}{options} || [];

    #my ($opt) = grep { $_->{value} eq $option_value } @$options;
    #return unless $opt;

    #for my $change (@{ $opt->{set} || [] }) {
        #$self->{db}->set_prop($svc->{DBKey}, $change->{prop}, $change->{value});
    #}

    #return 1;
#}

# Apply a selected menu option by writing each of its set rules to the e-smith DB.
# If a rule has no key, fall back to the service's top-level DBKey.
sub apply_option {
    my ($self, $service, $option_value) = @_;

    my $svc = $self->_service($service) or return;
    my $opts = $svc->{ui}{options} || [];

    my ($opt) = grep { defined $_->{value} && $_->{value} eq $option_value } @$opts;
    return unless $opt;

    for my $change (@{ $opt->{set} || [] }) {
        my $key = $change->{key} // $svc->{DBKey};
        my $prop = $change->{prop};
        my $value = $change->{value};

        next unless defined $key && defined $prop;
        $self->{db}->set_prop($key, $prop, $value);
    }

    return 1;
}

# Return select_field-compatible options for a given service.
sub get_select_options {
    my ($self, $service) = @_;

    my $svc = $self->_service($service) or return [];

    my $opts = $svc->{ui}{options} || [];

    return [
        map {
            [
                l($_->{label}),
                $_->{value},
                (
                    $_->{selected} ? (selected => 'selected') : (),
                    $_->{disabled} ? (disabled => 'disabled') : (),
                ),
            ]
        } @$opts
    ];
}

## Find the menu option whose set rules match the supplied property/value pairs,
## and return the full option structure.
#sub get_menu_option_by_props {
    #my ($self, $service, %want) = @_;

    #my $svc = $self->_service($service) or return;
    #my $opts = $svc->{ui}{options} || [];

    #OPTION:
    #for my $opt (@$opts) {
        #my $set = $opt->{set} || [];
        #my %have = map { $_->{prop} => $_->{value} } @$set;

        #for my $k (keys %want) {
            #next OPTION unless defined $have{$k} && $have{$k} eq $want{$k};
        #}

        #return $opt;
    #}

    #return;
#}

    # Find the menu option whose set rules match the supplied DB property values.
    # If a rule has no key, fall back to the service's top-level DBKey.
    # Find the menu option whose set rules match the supplied DB property values.
    # If nothing matches, return a dummy option with mismatch details.
use Data::Dumper;
sub get_menu_option_by_props {
    my ($self, $service, %want) = @_;

    my $debug = $ENV{GUI_DEBUG_MATCHER} // 0;
    my $trace = sub {
        return unless $debug;
        warn "[MATCH] " . join('', @_) . "\n";
    };

    my $svc = $self->_service($service);
    return _not_matched($service, undef, undef, undef, "service not found")
        unless $svc && ref($svc) eq 'HASH';

    my $opts  = $svc->{ui}{options} || [];
    my $dbkey = $svc->{DBKey} // $service;

    my @failures;

    OPTION:
    for my $idx (0 .. $#$opts) {
        my $opt = $opts->[$idx];
        next unless ref($opt) eq 'HASH';

        my $set = $opt->{set} || [];
        my %have;

        $trace->("checking option[$idx] value=" . ($opt->{value} // '') . " label=" . ($opt->{label} // ''));

        for my $j (0 .. $#$set) {
            my $change = $set->[$j];
            next unless ref($change) eq 'HASH';

            my $key  = defined $change->{key} ? $change->{key} : $dbkey;
            my $prop = $change->{prop};
            my $want_val = $change->{value};

            $trace->("  set[$j] key=" . ($key // 'undef')
                . " prop=" . ($prop // 'undef')
                . " expect=" . (defined $want_val ? $want_val : 'undef'));

            next OPTION unless defined $key && defined $prop;

            my $have_val = $self->{db}->get_prop($key, $prop);

            $trace->("  compare key=$key prop=$prop want="
                . (defined $want_val ? $want_val : 'undef')
                . " have=" . (defined $have_val ? $have_val : 'undef'));

            if (!defined $have_val || !defined $want_val || $have_val ne $want_val) {
                push @failures, {
                    key      => $key,
                    prop     => $prop,
                    expected => $want_val,
                    got      => $have_val,
                    reason   => 'value mismatch',
                    option   => $opt->{label} // $opt->{value} // $idx,
                };
                next OPTION;
            }
        }

        $trace->("matched option[$idx]");
        return $opt;
    }

    my $best = _pick_best_mismatch(@failures);
    $trace->("no match, best mismatch=" . Dumper($best));

    return _not_matched(
        $best->{key},
        $best->{prop},
        $best->{expected},
        $best->{got},
        _format_mismatch($best),
    );
}

sub _pick_best_mismatch {
    my (@args) = @_;

    my $trace = '';
    if (@args && ref($args[-1]) eq 'CODE') {
        $trace = pop @args;
    }
    my $debug = 0;
    if (@args && !ref($args[-1])) {
        $debug = pop @args;
    }

    my @failures = grep { ref($_) eq 'HASH' } @args;

    return {
        key      => undef,
        prop     => undef,
        expected => undef,
        got      => undef,
        reason   => 'no failures recorded',
    } unless @failures;

    my %score;
    for my $f (@failures) {
        my $k = join '/', ($f->{key} // ''), ($f->{prop} // '');
        $score{$k}++;
    }

    my ($best_key) = sort {
        $score{$b} <=> $score{$a}
            ||
        $a cmp $b
    } keys %score;

    for my $f (@failures) {
        my $k = join '/', ($f->{key} // ''), ($f->{prop} // '');
        return $f if $k eq $best_key;
    }

    return $failures[0];
}

sub _format_mismatch {
    my ($m) = @_;

    return 'DB not matched' unless $m && ref($m) eq 'HASH';

    return sprintf(
        'DB mismatch for %s/%s: expected %s, got %s',
        $m->{key}      // '-',
        $m->{prop}     // '-',
        defined $m->{expected} ? $m->{expected} : 'undef',
        defined $m->{got}      ? $m->{got}      : 'undef',
    );
}

sub _not_matched {
    my ($key, $prop, $expected, $got, $text) = @_;

    return {
        value         => 'DB not matched',
        label         => 'DB not matched',
        mismatch      => {
            key      => $key,
            prop     => $prop,
            expected => $expected,
            got      => $got,
        },
        mismatch_text => $text // 'DB not matched',
    };
}

    sub get_current_menu_option {
        my ($self, $service) = @_;

        my $svc = $self->_service($service) or return {
            value    => 'DB not matched',
            label    => 'DB not matched',
            mismatch => { key => $service, prop => undef, expected => undef, got => undef },
        };

        my $dbkey = $svc->{DBKey} or return {
            value    => 'DB not matched',
            label    => 'DB not matched',
            mismatch => { key => $service, prop => undef, expected => undef, got => undef },
        };

        my $opts = $svc->{ui}{options} || [];
        return {
            value    => 'DB not matched',
            label    => 'DB not matched',
            mismatch => { key => $dbkey, prop => undef, expected => undef, got => undef },
        } unless @$opts;

        $self->{db}->reload;

        my %want;
        my %seen;

        for my $opt (@$opts) {
            for my $change (@{ $opt->{set} || [] }) {
                my $key  = $change->{key} // $dbkey;
                my $prop = $change->{prop};
                next unless defined $key && defined $prop;
                next if $seen{$key}{$prop}++;

                $want{$key}{$prop} = $self->{db}->get_prop($key, $prop);
            }
        }

        my $match = $self->get_menu_option_by_props($service, %want);
        return $match if $match;

        return {
            value    => 'DB not matched',
            label    => 'DB not matched',
            mismatch => { key => $dbkey, prop => undef, expected => undef, got => undef },
        };
    }

    sub get_current_menu_label {
        my ($self, $service) = @_;
        my $opt = $self->get_current_menu_option($service);

        return $opt->{label} if $opt->{value} ne 'DB not matched';

        return $opt->{label} . ' (' .
            ($opt->{mismatch}{key} // '-') . '/' .
            ($opt->{mismatch}{prop} // '-') . ')';
    }

1;