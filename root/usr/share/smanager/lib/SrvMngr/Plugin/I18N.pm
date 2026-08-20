package SrvMngr::Plugin::I18N;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use I18N::LangTags;
use I18N::LangTags::Detect;

our $VERSION = '1.9';

	# Directory tree of compiled .mo files, checked in preference to the
	# static per-module .pm lexicon when one exists for a given module/
	# language pair (see _Handler::_mo_file / _load_module below). The
	# actual default lives in _Handler::_mo_file - $self->{mo_root} is
	# never populated from $conf here, so this dead top-level statement
	# (which referenced $conf before it existed in this scope) is removed.

#export MOJO_LOG_LEVEL='debug';

# "Can we have Bender burgers again?
#  No, the cat shelter’s onto me."
sub register {
	my ($plugin, $app, $conf) = @_;
	
	$app->log->level('debug');

	# Initialize
	my $namespace = $conf->{namespace} || ( (ref $app) . '::I18N' );
	my $default   = $conf->{default  } || 'en';
	$default =~ tr/-A-Z/_a-z/;
	$default =~ tr/_a-z0-9//cd;

	my $langs     = $conf->{support_url_langs};
	my $hosts     = $conf->{support_hosts    };

	# Default Handler
	my $handler   = sub {
		shift->stash->{i18n} =
			SrvMngr::Plugin::I18N::_Handler->new(namespace => $namespace, default => $default)
		;
	};

	# Add hook
$app->hook(
    before_dispatch => sub {
        my $self = shift;
        
        #$self->app->log->warn('I18N before_dispatch reached');

        #$self->app->log->debug('I18N before_dispatch start');
        #$self->app->log->debug('  path=' . ($self->req->url->path->to_string // ''));
        #$self->app->log->debug('  accept_language=' . ($self->req->headers->accept_language // ''));
        #$self->app->log->debug('  host=' . ($self->req->headers->header('X-Host') || $self->req->headers->host || ''));

        # Handler
        $handler->( $self );

        #$self->app->log->debug('  after handler: i18n class=' . ref($self->stash('i18n')));
        #$self->app->log->debug('  after handler: namespace=' . ($self->stash('i18n')->{namespace} // 'undef'));
        #$self->app->log->debug('  after handler: handle=' . (
            #$self->stash('i18n')->{handle}
            #? ref($self->stash('i18n')->{handle})
            #: 'undef'
        #));

        # Header detection
        my @languages = $conf->{no_header_detect}
            ? ()
            : I18N::LangTags::implicate_supers(
                I18N::LangTags::Detect->http_accept_langs(
                    $self->req->headers->accept_language
                )
            )
        ;

        #$self->app->log->debug('  languages from header=' . join(',', @languages));

        # Host detection
        my $host = $self->req->headers->header('X-Host') || $self->req->headers->host;
        if ($conf->{support_hosts} && $host) {
            $self->app->log->debug("  host before normalize=$host");
            $host =~ s/^www\.//;
            if (my $lang = $conf->{support_hosts}->{ $host }) {
                $self->app->log->debug("  host maps to language=$lang");
                unshift @languages, $lang;
            }
        }

        # Set default language
        $self->stash(lang_default => $languages[0]) if $languages[0];
        #$self->app->log->debug('  lang_default=' . ($self->stash('lang_default') // 'undef'));

        # URL detection
        if (my $path = $self->req->url->path) {
            my $part = $path->parts->[0];
            #$self->app->log->debug('  first path part=' . ($part // 'undef'));

            if ($part && $langs && grep { $part eq $_ } @$langs) {
                return if $self->res->code;

                #$self->app->log->debug("  language found in URL=$part");
                unshift @languages, $part;
                $self->stash(lang => $part);

                shift @{$path->parts};
                $path->trailing_slash(0);
                #$self->app->log->debug('  path rewritten=' . $path->to_string);
            }
        }

        #$self->app->log->debug('  final languages=' . join(',', @languages) . ", default=$default");

        # Languages
        $self->languages(@languages, $default);

        #$self->app->log->debug('  after languages: i18n class=' . ref($self->stash('i18n')));
        #$self->app->log->debug('  after languages: namespace=' . ($self->stash('i18n')->{namespace} // 'undef'));
        #$self->app->log->debug('  after languages: language=' . ($self->stash('i18n')->{language} // 'undef'));
        #$self->app->log->debug('  after languages: handle=' . (
            #$self->stash('i18n')->{handle}
            #? ref($self->stash('i18n')->{handle})
            #: 'undef'
        #));
    }
);

	# Add "i18ns" helper
	$app->helper(i18ns => sub {
		my $self = shift;

		$handler->( $self ) unless $self->stash('i18n');

		$self->stash->{i18n}->i18namespace(@_);
	});

	# Add "languages" helper
	$app->helper(languages => sub {
		my $self = shift;

		$handler->( $self ) unless $self->stash('i18n');

		$self->stash->{i18n}->languages(@_);
	});

	# Add "l" helper
	$app->helper(l => sub {
		my $self = shift;

		$handler->( $self ) unless $self->stash('i18n');

		$self->stash->{i18n}->localize(@_);
	});

	# Reimplement "url_for" helper
	my $mojo_url_for = *Mojolicious::Controller::url_for{CODE};

	my $i18n_url_for = sub {
		my $self = shift;
		my $url  = $self->$mojo_url_for(@_);

		# Absolute URL
		return $url if $url->is_abs;

		# Discard target if present
		shift if (@_ % 2 && !ref $_[0]) || (@_ > 1 && ref $_[-1]);

		# Unveil params
		my %params = @_ == 1 ? %{$_[0]} : @_;

		# Detect lang
		if (my $lang = $params{lang} || $self->stash('lang')) {
			my $path = $url->path || [];

			# Root
			if (!$path->[0]) {
				$path->parts([ $lang ]);
			}

			# No language detected
			elsif ( ref $langs ne 'ARRAY' or not scalar grep { $path->contains("/$_") } @$langs ) {
				unshift @{ $path->parts }, $lang;
			}
		}

		$url;
	};

	{
		no strict 'refs';
		no warnings 'redefine';

		*Mojolicious::Controller::url_for = $i18n_url_for;
	}
}

package SrvMngr::Plugin::I18N::_Handler;
use Mojo::Base -base;
use File::Basename qw(dirname basename);

use constant DEBUG => $ENV{MOJO_I18N_DEBUG} || 0;

# "Robot 1-X, save my friends! And Zoidberg!"
sub i18namespace {
	my $self = shift;

	my ($namespace, $language) = @_;
	return $self->{namespace} unless $namespace && $language;

	$language =~ s/-/_/g if $language;
	$language = $self->{language} unless $language;

	# Load Lang Module
	$self->_load_module($namespace => $language);

	if (my $handle = $namespace->get_handle($language)) {
		$handle->fail_with(sub { $_[1] });
		$self->{handle}   = $handle;
		$self->{language} = $handle->language_tag;
		$self->{namespace} = $namespace;
	}
	return $self;
}

sub languages {
	my ($self, @languages) = @_;

	unless (@languages) {
		my $lang = $self->{language};

		# lang such as en-us
		$lang =~ s/_/-/g;

		return $lang;
	}

	# Handle
	my $namespace = $self->{namespace};

	# Load Lang Module
	$self->_load_module($namespace => $_) for @languages;

	if (my $handle = $namespace->get_handle(@languages)) {
		$handle->fail_with(sub { $_[1] });
		$self->{handle}   = $handle;
		$self->{language} = $handle->language_tag;
		$self->{namespace} = $namespace;
	}

	return $self;
}

sub localize {
	my $self = shift;
	my $key  = shift;
	return $key unless my $handle = $self->{handle};
	return $handle->maketext($key, @_);
}

sub _po_file {
	my ($self, $namespace, $lang) = @_;
	my $mo_path = $self->_mo_file($namespace, $lang) or return;
	my $lc_messages_dir = dirname($mo_path);   # .../Useraccounts/en/LC_MESSAGES
	my $lang             = basename(dirname($lc_messages_dir)); # "en"
	my $module_dir        = dirname(dirname($lc_messages_dir));  # .../Useraccounts
	my $po_path            = "$module_dir/$lang.po";
	
	#(my $po = $mo) =~ s/\.mo\z/.po/;
	return $po_path;
}

# GNU gettext .mo files always start with a fixed 4-byte magic number, in
# either byte order (0x950412de big-endian or 0xde120495 little-endian).
# Locale::Maketext::Lexicon's pure-Perl .mo parser does not reliably die on
# malformed binary input - it can silently "succeed" with a broken lexicon,
# and later use of that lexicon has been observed to crash the whole worker
# process (heap corruption / SIGABRT), which no eval{} can catch. So we
# refuse to even attempt loading a .mo whose header doesn't look right.
sub _looks_like_valid_mo {
	my ($self, $file) = @_;
	return 0 unless $file && -e $file;
	open my $fh, '<:raw', $file or return 0;
	my $magic;
	my $n = read($fh, $magic, 4);
	close $fh;
	return 0 unless defined $n && $n == 4;
	my $be = unpack('N', $magic);
	my $le = unpack('V', $magic);
	return ($be == 0xde120495 || $le == 0x950412de) ? 1 : 0;
}

# Try to load one gettext-format file (.mo or .po - Locale::Maketext::Lexicon::Gettext
# accepts either) into $namespace's %Lexicon for $lang. Returns 1 on success, 0 if the
# file is missing or fails to parse/load.
sub _load_gettext_lexicon {
	my ($self, $namespace, $lang, $file) = @_;
	return 0 unless $file && -e $file;

	my $ok = eval qq{
		package $namespace;
		use Locale::Maketext::Lexicon {
			'$lang' => [ Gettext => '$file' ],
		};
		1;
	};
	return 0 unless $ok;

	# gettext's own convention stores the .po/.mo file HEADER (Project-Id-Version,
	# POT-Creation-Date, etc.) as the translation for the empty msgid (""). Both
	# the raw-.po and compiled-.mo Gettext backends load that header text
	# straight into %Lexicon under the '' key - it is not a translatable string,
	# but it IS directly retrievable via $Lexicon{''} or maketext(''), which any
	# caller can trigger by accident (e.g. l($maybe_empty_var) in a template).
	# Strip it immediately so it can never leak into rendered output. See
	# https://www.gnu.org/software/gettext/manual/html_node/More-Details.html and
	# https://www.gnu.org/software/gettext/manual/html_node/MO-Files.html - and
	# Locale::Maketext::Lexicon::Gettext's parse()/parse_mo() (both build
	# %Lexicon by merging the header's __-prefixed metadata copy with an
	# unconditional msgid/msgstr push that has no msgid-eq-'' exclusion).
	# There is no module option to suppress this - _allow_empty and _use_fuzzy
	# are the only related switches and neither applies here. This fix runs
	# purely in memory, after the file has already been parsed - the .po/.mo
	# file on disk is never modified.
	no strict 'refs';
	my $lex = \%{"${namespace}::${lang}::Lexicon"};
	delete $lex->{''} if exists $lex->{''};

	return 1;
}

sub _load_module {
	my $self = shift;

	my($namespace, $lang) = @_;
	return unless $namespace && $lang;

	my $mo_file = $self->_mo_file($namespace, $lang);
	warn "mo:".$mo_file;
	my $po_file = $self->_po_file($namespace, $lang);
	warn "po:".$po_file;

	my $loaded = 0;

	# 1st choice: compiled .mo - but only if its header actually looks like a real .mo
	if ($mo_file && -e $mo_file && !$self->_looks_like_valid_mo($mo_file)) {
		# always unconditional - a bad-magic .mo on disk is a real anomaly worth knowing about
		warn("REJECTED .mo for $namespace ($lang) - not a valid gettext .mo (bad magic number): $mo_file - will try .po");
	} elsif ($mo_file && -e $mo_file) {
		if ($self->_load_gettext_lexicon($namespace, $lang, $mo_file)) {
			#DEBUG && 
			warn("OK: loaded .mo lexicon for $namespace ($lang) from $mo_file");
			$loaded = 1;
		} else {
			# a .mo existed but Locale::Maketext::Lexicon couldn't use it - always worth logging
			#warn("FAILED to load .mo lexicon for $namespace ($lang) from $mo_file: $@ - will try .po");
		}
	} else {
		#DEBUG && 
		warn("No .mo file found for $namespace ($lang), expected at $mo_file");
	}

	# 2nd choice: uncompiled .po, only if the .mo path above didn't already succeed
	if (!$loaded && $po_file && -e $po_file) {
		if ($self->_load_gettext_lexicon($namespace, $lang, $po_file)) {
			# unconditional - not gated by DEBUG - running on raw .po is a build-process
			# signal worth always seeing, not routine
			warn("Loaded UNCOMPILED .po lexicon for $namespace ($lang) from $po_file - .mo missing or failed, check build");
			$loaded = 1;
		} else {
			#warn("FAILED to load .po lexicon for $namespace ($lang) from $po_file: $@ - will fall back to .pm");
		}
	}

	unless ($loaded) {
		# 3rd choice: fall through to the existing .pm-based mechanism below
		#DEBUG && 
		warn("No usable .mo or .po lexicon for $namespace ($lang) - falling back to .pm");
	}

	# lang such as en-us
	$lang =~ s/-/_/g;

	unless ($namespace->can('new')) {
		DEBUG && warn("Load default namespace $namespace");

		(my $file = $namespace) =~ s{::|'}{/}g;
		eval qq(require "$file.pm");

		if ($@) {
			DEBUG && warn("Create default namespace $namespace");

			eval "package $namespace; use base 'Locale::Maketext'; 1;";
			die qq/Couldn't initialize I18N default class "$namespace": $@/ if $@;
		}
	}

	for ($self->{default}, $lang) {
		my $module = "${namespace}::$_";
		unless ($module->can('new')) {
			DEBUG && warn("Load the I18N class $module");

			(my $file = $module) =~ s{::|'}{/}g;
			eval qq(require "$file.pm");

			my $default = $self->{default};
			if ($@ || not eval "\%${module}::Lexicon") {
				if ($_ eq $default) {
					DEBUG && warn("Create the I18N class $module");

					eval "package ${module}; use base '$namespace';" . 'our %Lexicon = (_AUTO => 1); 1;';
					die qq/Couldn't initialize I18N class "$namespace": $@/ if $@;
				}
			}
		}
	}
}

# Path to a module's compiled .mo file for a given language, or undef if
# the namespace doesn't resolve to a recognizable module name. Derived from
# the last component of the namespace (e.g. SrvMngr::I18N::Modules::Dnf ->
# "dnf"), matching the gettext domain convention already used for RPM
# packaging: <mo_root>/<lang>/LC_MESSAGES/<module>.mo
# (default mo_root: /usr/share/smanager/lib/SrvMngr/I18N/po -- co-located with
# the .po sources rather than a separate top-level locale/ tree, matching the
# real smeserver-manager-locale spec's %build/%install layout).
sub _mo_file {
	my ($self, $namespace, $lang) = @_;
	return unless $namespace && $lang;

	warn "Namespace:".$namespace;
	my ($domain) = $namespace =~ /([^:]+)\z/;
	warn "domain:".$domain;

	return unless $domain;
	my $domainLC = lc $domain;
	warn "domainLC:".$domainLC; 

	my $root = $self->{mo_root} || '/usr/share/smanager/lib/SrvMngr/I18N/po';
	return "$root/$domain/$lang/LC_MESSAGES/$domainLC.mo";
}
1;

__END__

=head1 NAME

Mojolicious::Plugin::I18N - Internationalization Plugin for Mojolicious

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('I18N');
  % languages 'de';
  %=l 'hello'

  # Mojolicious::Lite (detect language from URL, i.e. /en/ or /de/)
  plugin I18N => {namespace => 'MyApp::I18N', support_url_langs => [qw(en de)]};
  %=l 'hello'

  # Lexicon
  package MyApp::I18N::de;
  use Mojo::Base 'MyApp::I18N';

  our %Lexicon = (hello => 'hallo');

  1;

=head1 DESCRIPTION

L<Mojolicious::Plugin::I18N> is internationalization plugin for Mojolicious
It works with Mojolicious 4.0+.

Old namespace is L<Mojolicious::Plugin::I18N2>.

=head1 OPTIONS

L<Mojolicious::Plugin::I18N> supports the following options.

=head2 C<support_url_langs>

  plugin I18N => {support_url_langs => [qw(en de)]};

Detect language from URL.

=head2 C<support_hosts>

  plugin I18N => {support_hosts => { 'mojolicious.ru' => 'ru', 'mojolicio.us' => 'en' }};

Detect Host header and use language for that host.

=head2 C<no_header_detect>

  plugin I18N => {no_header_detect => 1};

Off header detect.

=head2 C<default>

  plugin I18N => {default => 'en'};

Default language for i18n, defaults to C<en>.

=head2 C<namespace>

  plugin I18N => {namespace => 'MyApp::I18N'};

Lexicon namespace, defaults to the application class followed by C<::I18N>.

=head1 HELPERS

L<Mojolicious::Plugin::I18N> implements helpers same as L<Mojolicious::Plugin::I18N>.

=head2 C<l>

  %=l 'hello'
  $self->l('hello');

Translate sentence.

=head2 C<languages>

  % languages 'de';
  $self->languages('de');

Change languages.

=head1 METHODS

L<Mojolicious::Plugin::I18N> inherits all methods from L<Mojolicious::Plugin::I18N>
and reimplements the following new ones.

=head2 C<register>

  $plugin->register;

Register plugin hooks and helpers in L<Mojolicious> application.

=head1 DEBUG MODE

L<Mojolicious::Plugin::I18N> has debug mode.

  # debug mode on
  BEGIN { $ENV{MOJO_I18N_DEBUG} = 1 };

  # or
  MOJO_I18N_DEBUG=1 perl script.pl

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 AUTHORS

2011-2014 Anatoly Sharifulin <sharifulin@gmail.com>

2010-2012 Sebastian Riedel <kraihx@googlemail.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mojolicious-plugin-i18n at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.htMail?Queue=Mojolicious-Plugin-I18N>.  We will be notified, and then you'll
automatically be notified of progress on your bug as we make changes.

=over 5

=item * Github

L<http://github.com/sharifulin/mojolicious-plugin-i18n/tree/master>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.htMail?Dist=Mojolicious-Plugin-I18N>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-I18N>

=item * CPANTS: CPAN Testing Service

L<http://cpants.perl.org/dist/overview/Mojolicious-Plugin-I18N>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-I18N>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-I18N>

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2011-2014 by Anatoly Sharifulin.
Copyright (C) 2008-2012, Sebastian Riedel.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
