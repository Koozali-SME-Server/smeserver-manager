package SrvMngr::Plugin::I18N;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use I18N::LangTags;
use I18N::LangTags::Detect;

our $VERSION = '1.14';

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

	# _decode => 1 is required for the Gettext backend to actually call
	# Encode::decode_utf8() on every loaded msgid/msgstr (see
	# Locale::Maketext::Lexicon::Gettext's transform(), which only decodes
	# when $DoEncoding is true, and Locale::Maketext::Lexicon.pm's own
	# '_decode'/'_encoding' option docs). Without it, raw UTF-8 bytes are
	# left as un-decoded bytes; Mojolicious's own UTF-8 encoding of the
	# HTTP response then re-encodes those already-UTF-8 bytes a second
	# time, producing exactly the "Ã¨"-style mojibake seen for French (and
	# any other non-ASCII) locales. No explicit _encoding is given, so the
	# default (native utf8-flagged Perl strings) is used, which is what
	# Mojolicious's template rendering and later encoding step expect.
	# Confirmed for real: without this option utf8::is_utf8() on loaded
	# lexicon values returns false; with it, true.
	my $ok = eval qq{
		package $namespace;
		use Locale::Maketext::Lexicon {
			'$lang'  => [ Gettext => '$file' ],
			_decode  => 1,
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

	# IMPORTANT: overwrite with '', do NOT delete the key outright. If the key
	# is removed entirely, Locale::Maketext's own maketext() (see its core
	# lookup loop) finds no entry for '' anywhere in the @ISA chain and, since
	# this is a real gettext-backed lexicon (no _AUTO flag), falls through to
	# Carp::croak("maketext doesn't know how to say:\n...\nas needed") - i.e.
	# any accidental l('') / maketext('') call (the same "$maybe_empty_var"
	# case the header-leak fix itself is guarding against) would go from
	# "leaks ugly header text" to "fatal exception, 500s the whole request".
	# Confirmed via a real, isolated repro against Locale::Maketext 1.x's
	# maketext(): delete => croak; assigning '' => returns '' cleanly, with
	# real translated keys still resolving normally either way.
	no strict 'refs';
	(my $norm_lang = lc $lang) =~ s/-/_/g;
	my $lex = \%{"${namespace}::${norm_lang}::Lexicon"};
	$lex->{''} = '' if exists $lex->{''};

	return 1;
}


# Orchestrator: resolve $namespace's own lexicon for $lang, then - unless
# $namespace IS the shared "General" module - fold General's lexicon in on
# top (see _merge_general_lexicon below). Deliberately calls
# _load_own_lexicon directly for BOTH namespaces rather than recursing back
# into itself for General, so there is no recursive or mutual call anywhere
# in this path - _load_own_lexicon never calls _load_module, and
# _merge_general_lexicon never calls _load_module either.
sub _load_module {
	my $self = shift;
	my ($namespace, $lang) = @_;
	return unless $namespace && $lang;

	$self->_load_own_lexicon($namespace, $lang);

	# Fold in the shared "General" module's lexicon (SAVE, CANCEL, OK,
	# day/month names, etc.) so an ordinary panel module can use those
	# keys without ever declaring them itself. Real production's old
	# .pm-only world got this for free: locales2-conf (in
	# smeserver-manager) always compiles General's .lex FIRST and then
	# bakes "%{ General::$lang::Lexicon }, %lexicon" straight into every
	# other module's generated .pm, module-specific keys listed last so
	# they win on collision. That merge has no equivalent for the new
	# .mo/.po tiers - each module's .po is intentionally left to contain
	# ONLY that module's own strings (confirmed against the real, live
	# Useraccounts.pot: 74 msgids, none of them shared General keys) -
	# duplicating General's ~134 strings into every module's .po would
	# mean translating the same string N times over in Weblate with no
	# guarantee of staying in sync. So the merge is done dynamically
	# here instead, at load time, working the same way no matter which
	# tier (.mo, .po or .pm) either side happens to resolve through -
	# General's own lookup gets its own full .mo -> .po -> .pm cascade,
	# same as any other module, resolved directly below (never via
	# _load_module).
	if (my $general_ns = $self->_general_namespace($namespace)) {
		for my $lc ($self->{default}, $lang) {
			$self->_load_own_lexicon($general_ns, $lc);
			$self->_merge_general_lexicon($namespace, $general_ns, $lc);
		}
	}
}

# The .mo -> .po -> .pm cascade for a single namespace/lang pair. This is
# the ONLY place that resolves a namespace's own lexicon - it has no
# awareness of "General" at all, and never calls _load_module or any
# General-related method, so it cannot itself be part of any recursion.
sub _load_own_lexicon {
	my $self = shift;

	my($namespace, $lang) = @_;
	return unless $namespace && $lang;

	my $mo_file = $self->_mo_file($namespace, $lang);
	#warn "mo:".$mo_file;
	my $po_file = $self->_po_file($namespace, $lang);
	#warn "po:".$po_file;

	my $loaded = 0;

	# 1st choice: compiled .mo - but only if its header actually looks like a real .mo
	if ($mo_file && -e $mo_file && !$self->_looks_like_valid_mo($mo_file)) {
		# always unconditional - a bad-magic .mo on disk is a real anomaly worth knowing about
		warn("REJECTED .mo for $namespace ($lang) - not a valid gettext .mo (bad magic number): $mo_file - will try .po");
	} elsif ($mo_file && -e $mo_file) {
		if ($self->_load_gettext_lexicon($namespace, $lang, $mo_file)) {
			DEBUG && warn("OK: loaded .mo lexicon for $namespace ($lang) from $mo_file");
			$loaded = 1;
		} else {
			# a .mo existed but Locale::Maketext::Lexicon couldn't use it - always worth logging
			warn("FAILED to load .mo lexicon for $namespace ($lang) from $mo_file: $@ - will try .po");
		}
	} else {
		DEBUG && warn("No .mo file found for $namespace ($lang), expected at $mo_file");
	}

	# 2nd choice: uncompiled .po, only if the .mo path above didn't already succeed
	if (!$loaded && $po_file && -e $po_file) {
		if ($self->_load_gettext_lexicon($namespace, $lang, $po_file)) {
			# unconditional - not gated by DEBUG - running on raw .po is a build-process
			# signal worth always seeing, not routine
			warn("Loaded UNCOMPILED .po lexicon for $namespace ($lang) from $po_file - .mo missing or failed, check build");
			$loaded = 1;
		} else {
			warn("FAILED to load .po lexicon for $namespace ($lang) from $po_file: $@ - will fall back to .pm");
		}
	}

	# 2.5th choice: if the exact region-qualified tag (e.g. en_GB) has no
	# real .mo/.po of its own, try the base language (e.g. en) instead.
	# Real packaged translations only ever ship base-language directories
	# (en, fr, de, ...), never region-qualified sub-variants - so a request
	# for anything region-qualified (which is how real browsers virtually
	# always send Accept-Language, e.g. en-GB/en-US/fr-BR) would otherwise
	# always fall through to an empty _AUTO=>1 placeholder below, even
	# though a real, fully-translated lexicon for the base language is
	# sitting right next to it on disk. Confirmed via real .mo fixtures:
	# without this, get_handle('en_GB') resolves module-specific keys to
	# raw untranslated keys, while General's merged strings still translate
	# fine only because _load_module()'s merge loop always additionally
	# loads General with the bare default 'en' directly, independent of
	# what was actually requested. This mirrors the same exact-then-base
	# fallback philosophy already used for navigation.
	my ($base_lang) = split /[-_]/, $lang, 2;
	if (!$loaded && $base_lang && lc($base_lang) ne lc($lang)) {
		my $base_mo = $self->_mo_file($namespace, $base_lang);
		my $base_po = $self->_po_file($namespace, $base_lang);

		if ($base_mo && -e $base_mo && $self->_looks_like_valid_mo($base_mo)) {
			if ($self->_load_gettext_lexicon($namespace, $lang, $base_mo)) {
				DEBUG && warn("OK: loaded BASE-language .mo lexicon for $namespace ($lang) from $base_mo (region-qualified fallback to '$base_lang')");
				$loaded = 1;
			} else {
				warn("FAILED to load base-language .mo lexicon for $namespace ($lang) from $base_mo: $@");
			}
		}
		if (!$loaded && $base_po && -e $base_po) {
			if ($self->_load_gettext_lexicon($namespace, $lang, $base_po)) {
				warn("Loaded UNCOMPILED base-language .po lexicon for $namespace ($lang) from $base_po (region-qualified fallback to '$base_lang')");
				$loaded = 1;
			} else {
				warn("FAILED to load base-language .po lexicon for $namespace ($lang) from $base_po: $@");
			}
		}
	}

	unless ($loaded) {
		# 3rd choice: fall through to the existing .pm-based mechanism below
		DEBUG && warn("No usable .mo or .po lexicon for $namespace ($lang) - falling back to .pm");
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

	# NOTE (fixed): the upstream .pm-tier fallback used to only synthesize an
	# empty placeholder class (use base $namespace; %Lexicon=(_AUTO=>1)) when
	# $_ eq $self->{default} - i.e. ONLY for the default language, never for
	# the actually-requested $lang. When neither a real .mo/.po lexicon nor a
	# real per-language .pm file exists for that $lang (true for every
	# language on the bare top-level default namespace, e.g. SrvMngr::I18N::fr
	# - confirmed against the real repo: locales2-conf only ever generates
	# SrvMngr::I18N::Modules::<Module>::<lang>, never a bare
	# SrvMngr::I18N::<lang>), "${namespace}::${lang}" was left as a package
	# with no %Lexicon and no @ISA at all - it has no usable new(). Whether
	# that blows up immediately or only much later (Locale::Maketext's
	# get_handle() normally skips an unusable candidate via its own _try_use()
	# check, but _try_use() memoizes per-process once it ever sees a non-empty
	# %Lexicon or non-empty @ISA for that exact package - so this can look
	# harmless for a long time and then die with "Can't locate object method
	# 'new' via package ..." the moment something in the same long-running
	# worker process changes that) is exactly the shape of the real crash
	# reported by the user when selecting the French UI locale. Fix: apply
	# the SAME fallback-creation to both languages in the loop, symmetrically
	# - not just the default - so every language this loop touches always
	# ends up with a real, working new().
	for ($self->{default}, $lang) {
		my $module = "${namespace}::$_";
		unless ($module->can('new')) {
			DEBUG && warn("Load the I18N class $module");

			(my $file = $module) =~ s{::|'}{/}g;
			eval qq(require "$file.pm");

			if ($@ || not eval "\%${module}::Lexicon") {
				DEBUG && warn("Create the I18N class $module");

				eval "package ${module}; use base '$namespace';" . 'our %Lexicon = (_AUTO => 1); 1;';
				die qq/Couldn't initialize I18N class "$namespace": $@/ if $@;
			}
		}
	}
}

# Sibling "General" namespace for a module namespace, e.g.
# SrvMngr::I18N::Modules::Useraccounts -> SrvMngr::I18N::Modules::General.
# Returns undef for General itself (nothing to merge into itself) and for
# a namespace with no "::"-separated parent (no sibling to derive).
sub _general_namespace {
	my ($self, $namespace) = @_;
	return undef unless $namespace =~ /^(.*)::([^:]+)\z/;
	my ($prefix, $leaf) = ($1, $2);
	return undef if $leaf eq 'General';
	return "${prefix}::General";
}

# Copy any entry $general_ns's ALREADY-RESOLVED lexicon for $lang defines
# that $namespace's own (also already-resolved) lexicon for $lang doesn't
# already have. $namespace's own entries always win on collision - same
# precedence order as locales2-conf's existing (%General, %lexicon) merge.
# Locale::Maketext control keys (leading underscore, e.g. the _AUTO flag a
# from-scratch lexicon gets initialised with) are never copied across -
# only real msgid/msgstr pairs. Pure hash merge, no cascade/file logic and
# no call back into _load_module or _load_own_lexicon - the caller
# (_load_module) is responsible for resolving both sides first.
sub _merge_general_lexicon {
	my ($self, $namespace, $general_ns, $lang) = @_;
	return unless $namespace && $general_ns && $lang;

	# Locale::Maketext::Lexicon's own import() always lowercases (and
	# underscore-izes) the language tag when constructing the per-language
	# subclass name (see Locale/Maketext/Lexicon.pm import(): $lang =
	# lc($lang); $lang =~ s/-/_/g;) - so the REAL populated package for e.g.
	# 'en_GB' is "${namespace}::en_gb", never "${namespace}::en_GB".
	# get_handle() tolerates the original mixed case via its own
	# case-insensitive alternate-tag fallback (I18N::LangTags), which is why
	# module-specific content still resolves correctly - but here we access
	# the symbol table directly with no such fallback, so we must normalize
	# the same way Lexicon.pm does or we silently read an empty/nonexistent
	# package and merge nothing in. Confirmed via a minimal, isolated repro
	# of Locale::Maketext::Lexicon 1.00's import().
	(my $norm_lang = lc $lang) =~ s/-/_/g;

	my $general_class = "${general_ns}::${norm_lang}";
	my $target_class  = "${namespace}::${norm_lang}";

	# Only ever dereference a class's %Lexicon symbolically if that class
	# can already demonstrably new() - i.e. it was genuinely set up moments
	# ago by _load_own_lexicon/Locale::Maketext::Lexicon. A bare
	# \%{"Pkg::Lexicon"} silently autovivifies that package's own
	# symbol-table entry even when nothing is ever written through it and
	# even though the class is otherwise never touched. That alone is
	# enough to fool Locale::Maketext's own get_handle()/_try_use() into
	# treating an otherwise nonexistent candidate tag as "already seen" the
	# next time ANYTHING in the same long-running worker process asks for
	# that exact tag - producing a "Can't locate object method new" crash
	# far away from this line, on a totally unrelated request/module.
	# can() is a safe, non-autovivifying check; symbolic %{"..."} access is
	# not. Confirmed via a real regression repro (Initial module, default
	# en_US resolution with no Accept-Language header at all).
	return 1 unless $general_class->can('new');
	return 1 unless $target_class->can('new');

	no strict 'refs';

	# CRITICAL: never do a wholesale hash-copy (my %h = %{"Pkg::Lexicon"})
	# on a Gettext-backed lexicon. Locale::Maketext::Lexicon 1.00 ties
	# %Lexicon to its own lazy FETCH/FIRSTKEY/NEXTKEY implementation, and
	# flattening the whole tied hash in one go SEGFAULTS the Perl
	# interpreter outright on this Perl/module combination - confirmed via
	# a minimal, dependency-free repro (`my %copy = %{"Pkg::lang::Lexicon"}`
	# reliably crashes with SIGSEGV on a real .mo-backed tied lexicon,
	# while the iterate-keys-then-fetch-each-value pattern below, matching
	# what this function already did before any of these fixes, does not).
	# Always take a reference and fetch values one key at a time.
	my $general_lex = \%{"${general_class}::Lexicon"};
	my $target_lex  = \%{"${target_class}::Lexicon"};

	for my $key (keys %$general_lex) {
		next if $key =~ /^_/;
		$target_lex->{$key} = $general_lex->{$key}
			unless exists $target_lex->{$key};
	}
	return 1;
}

# Path to a module's compiled .mo file for a given language, or undef if
# the namespace doesn't resolve to a recognizable module name. Derived from
# the last component of the namespace (e.g. SrvMngr::I18N::Modules::Useraccounts
# -> "Useraccounts"), matching the real runtime layout used by
# smeserver-manager's Plugin/I18N.pm and smeserver-manager-locale packaging:
#   <mo_root>/<Module>/<lang>/LC_MESSAGES/<module-lowercase>.mo
#   <mo_root>/<Module>/<lang>.po                  (see _po_file above)
# The <Module> directory component keeps its ORIGINAL CASE (e.g.
# "Useraccounts"), matching the module's own directory name on disk -
# only the .mo filename itself ($domainLC) is lowercased. The .po file
# lives one directory level UP from LC_MESSAGES, not inside it.
# (default mo_root: /usr/share/smanager/lib/SrvMngr/I18N/po -- co-located with
# the .po sources rather than a separate top-level locale/ tree, matching the
# real smeserver-manager-locale spec's %build/%install layout).
sub _mo_file {
	my ($self, $namespace, $lang) = @_;
	return unless $namespace && $lang;

	#warn "Namespace:".$namespace;
	my ($domain) = $namespace =~ /([^:]+)\z/;
	#warn "domain:".$domain;

	return unless $domain;
	my $domainLC = lc $domain;
	#warn "domainLC:".$domainLC;

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
