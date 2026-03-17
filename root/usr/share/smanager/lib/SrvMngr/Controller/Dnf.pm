package SrvMngr::Controller::Dnf;
#----------------------------------------------------------------------
# heading     : System
# description : Software installer (dnf)
# navigation  : 4000 510
#
#    $if_admin->get ('/dnf')->to('dnf#do_show')->name('dnf');
#    $if_admin->post('/dnf/start/:function')->to('dnf#start_dnf')->name('dnf_start_dnf');
#    $if_admin->get ('/dnf/stream/:run_id')->to('dnf#dnf_stream')->name('dnf_stream');
#    $if_admin->get('/dnf/options/:function')->to('dnf#dnf_options')->name('dnf_options');
#    $if_admin->get('/dnf/partial')->to('dnf#dnf_partial')->name('dnf_partial');
#    $if_admin->get('/dnfd')->to('dnf#do_update')->name('dnfd');
#
# routes : end
#----------------------------------------------------------------------
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::IOLoop;
use Mojo::Util qw(xml_escape);
use Mojo::Cache;
use Time::HiRes qw(time);

use esmith::ConfigDB::UTF8;
use esmith::util;

# ---- Config ----
my $DNF_STATUS_FILE   = '/var/cache/dnf/dnf.status';
my $DNF_LOG_DIR       = '/var/log/dnf';
my $DNF_LOG_RE        = qr/^dnf\.log\.(\d+)$/;

our %dbs;

# END marker emitted by your event script
#my $DNF_END_MARKER_RE = qr/^---- dnf event finished at .*?\(exit=\d+\) ----/;

# Per-worker cache (hypnotoad workers each keep their own cache)
my $CACHE = Mojo::Cache->new(max_keys => 40);

# ---- Helpers ----

sub _open_cfg ($c) {
  my $db = esmith::ConfigDB::UTF8->open;
  die "Couldn't open configuration DB\n" unless $db;
  return $db;
}

sub _open_view_db ($c, $view) {
  my $db = esmith::ConfigDB::UTF8->open_ro("dnf_$view");
  die "Couldn't open dnf_$view DB\n" unless $db;
  return $db;
}

sub _get_dnf_status ($c) {
  return 'resolved' unless -e $DNF_STATUS_FILE;
  open my $fh, '<', $DNF_STATUS_FILE or return 'resolved';
  my $line = <$fh> // 'resolved';
  close $fh;
  chomp $line;
  return $line;
}

sub _is_dnf_running ($c) {
  my $s = $c->_get_dnf_status;
  return $s ne "resolved" && $s ne "config" && $s ne "sack";
}

sub _options_for ($db, $type) {
  my @options;
  for my $r ($db->get_all_by_prop(type => $type)) {
    my $key     = $r->key             // '';
    my $version = $r->prop('Version') // '';
    my $repo    = $r->prop('Repo')    // '';
    push @options, [ "$key $version - $repo" => $key ];
  }
  return \@options;
}

sub _cached_options ($c, $view) {
  my $key_pkg = "dnfpanel:$view:package";
  my $key_grp = "dnfpanel:$view:group";

  my $packages = $CACHE->get($key_pkg);
  my $groups   = $CACHE->get($key_grp);

  return ($packages, $groups) if $packages && $groups;

  my $db = $c->_open_view_db($view);
  $packages = _options_for($db, 'package');
  $groups   = _options_for($db, 'group');

  # TTL 5 minutes
  $CACHE->set($key_pkg, $packages, 300);
  $CACHE->set($key_grp, $groups,   300);

  return ($packages, $groups);
}

sub _clear_panel_cache ($c) {
  for my $view (qw(updates available installed)) {
    $CACHE->set("dnfpanel:$view:package", undef, 0);
    $CACHE->set("dnfpanel:$view:group",   undef, 0);
  }
}

sub _get_logfile_from_configdb_fresh ($c) {
  my $cfg = $c->_open_cfg;
  return $cfg->get_prop('dnf', 'LogFile') // '';
}

sub _get_logfile_via_db_cmd ($c) {
  open(my $fh, '-|', 'db', 'configuration', 'getprop', 'dnf', 'LogFile') or return '';
  my $v = <$fh> // '';
  close $fh;
  chomp $v;
  return $v;
}

sub _get_logfile_best_effort_with_source ($c) {
  my $v = $c->_get_logfile_from_configdb_fresh;
  return ($v, 'esmith::ConfigDB') if defined($v) && length($v);

  $v = $c->_get_logfile_via_db_cmd;
  return ($v, 'db command') if defined($v) && length($v);

  return ('', 'none');
}

sub _newest_log_since ($c, $t0_int, $slack_seconds = 2) {
  return '' unless -d $DNF_LOG_DIR;

  opendir(my $dh, $DNF_LOG_DIR) or return '';
  my @f = readdir($dh);
  closedir $dh;

  my $min = $t0_int - $slack_seconds;
  my ($best_path, $best_n) = ('', 0);

  for my $fn (@f) {
    my ($n) = ($fn =~ $DNF_LOG_RE) or next;
    next if $n < $min;
    next if $n <= $best_n;
    my $path = "$DNF_LOG_DIR/$fn";
    next unless -e $path;
    ($best_path, $best_n) = ($path, $n);
  }

  return $best_path;
}

sub change_settings {
    my ($c) = @_;
    my $cfg = $c->_open_cfg;

    for my $param (
        qw(
        PackageFunctions
        )
        )
    {
        $cfg->set_prop("dnf", $param, $c->param("yum_$param"));
    } ## end for my $param (qw( PackageFunctions...))
    my $check4updates = $c->param("yum_check4updates");
    my $status        = 'disabled';
    if ($check4updates ne 'disabled') { $status = 'enabled'; }
    $cfg->set_prop("dnf", 'check4updates', $check4updates);
    my $deltarpm = $c->param("yum_DeltaRpmProcess");
    $cfg->set_prop("dnf", 'DeltaRpmProcess', $deltarpm);
    my $downloadonly = $c->param("yum_DownloadOnly");
    if ($downloadonly ne 'disabled') { $status = 'enabled'; }
    $cfg->set_prop("dnf", 'DownloadOnly', $downloadonly);
    my $AutoInstallUpdates = $c->param("yum_AutoInstallUpdates");
    if ($AutoInstallUpdates ne 'disabled') { $status = 'enabled'; }
    $cfg->set_prop("dnf", 'AutoInstallUpdates', $AutoInstallUpdates);
    $cfg->set_prop("dnf", 'status',             $status);
    $cfg->reload();
    my %selected = map { $_ => 1 } @{ $c->every_param('SelectedRepositories') };
    
    $c->refresh_dbs();
    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        $repos->set_prop("status", exists $selected{ $repos->key } ? 'enabled' : 'disabled');
    }
    $dbs{repositories}->reload;

    unless (system("/sbin/e-smith/signal-event", "dnf-modify") == 0) {
        return $c->l('yum_ERROR_UPDATING_CONFIGURATION');
    }
    return 'OK';
} ## end sub change_settings


sub get_status {
    # called from template
    my ($c, $prop, $localise) = @_;
    my $cfg = $c->_open_cfg;
    my $status = $cfg->get_prop("dnf", $prop) || 'disabled';
    return $status unless $localise;
    return $c->l($status eq 'enabled' ? 'ENABLED' : 'DISABLED');
} ## end sub get_status

sub get_check_freq_opt {
    my ($c) = @_;
    return [
        [ $c->l('DISABLED')     => 'disabled' ],
        [ $c->l('yum_1DAILY')   => 'daily' ],
        [ $c->l('yum_2WEEKLY')  => 'weekly' ],
        [ $c->l('yum_3MONTHLY') => 'monthly' ]
    ];
} ## end sub get_check_freq_opt

sub refresh_dbs {
    for (qw(available installed updates)) {
        $dbs{$_} = esmith::ConfigDB::UTF8->open_ro("dnf_$_")
            or die "Couldn't open dnf_$_ DB\n";
    }

    for (qw(repositories)) {
        $dbs{$_} = esmith::ConfigDB::UTF8->open("yum_$_")
            or die "Couldn't open yum_$_ DB\n";
    }
}

sub get_repository_current_options {
    # called from template
    # returns raw keys in a simple array
    my $c = shift;
    $c->refresh_dbs();
    my @selected;
    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        next unless ($repos->prop('Visible') eq 'yes'
            or $repos->prop('status') eq 'enabled');
        push @selected, $repos->key if ($repos->prop('status') eq 'enabled');
    }
    return \@selected;
} ## end sub get_repository_current_options

sub get_repository_options2 {
    # builds name-key pairs, sorts them alphabetically by name, and returns a structured array of arrays
    my $c = shift;
    $c->refresh_dbs();
    my @options;
    foreach my $repos ($dbs{repositories}->get_all_by_prop(type => "repository")) {
        next unless ($repos->prop('Visible') eq 'yes'
            or $repos->prop('status') eq 'enabled');
        push @options, [ $repos->prop('Name') => $repos->key ];
    }
    my @opts = sort { $a->[0] cmp $b->[0] } @options;
    return \@opts;
} ## end sub get_repository_options2


# ---- Actions ----

sub do_update ($c) {
   my $res=$c->change_settings();
   if ($res eq 'OK'){
       $c->stash('success',$c->l('yum_SUCCESS'));
   } else {
       $c->stash('error',$res); 
   }
   $c->_clear_panel_cache();
   $c->do_show();
}

sub dnf_partial ($c) {
  my $function = lc($c->param('function') // 'update');
  $function =~ s/^\s+|\s+$//g;
  $function = 'update' unless $function =~ /^(update|install|remove|configure)$/;

  my %map = ( update => 'updates', install => 'available', remove => 'installed' );

  my ($pkg_opts, $grp_opts) = ([], []);
  my $view = $map{$function} // '';
  $c->refresh_dbs();

  if ($function ne 'configure') {
    ($pkg_opts, $grp_opts) = $c->_cached_options($view);
  }

  $c->stash(
    title         => 'DNF',
    function      => $function,
    view          => $view,
    pkg_opts      => $pkg_opts,
    grp_opts      => $grp_opts,
    pkg_count     => scalar(@$pkg_opts),
    grp_count     => scalar(@$grp_opts),
    preselect_all => ($function eq 'update') ? 1 : 0,
  );

  return $c->render(template => 'partials/_dnf_show', format => 'html');
}

# GET /dnf?function=update|install|remove
sub do_show ($c) {
  my $function = lc($c->param('function') // 'update');
  $c->app->log->info("DNF do_show raw_function=[" . ($c->param('function') // '') . "] normalized=[$function]");
  $function =~ s/^\s+|\s+$//g;
  $function = 'update' unless $function =~ /^(update|install|remove|configure)$/;

  my %map = ( update => 'updates', install => 'available', remove => 'installed' );

  my ($pkg_opts, $grp_opts) = ([], []);
  my $view = $map{$function} // '';

  if ($function ne 'configure') {
    ($pkg_opts, $grp_opts) = $c->_cached_options($view);
  }

  $c->stash(
    title         => $c->l('yum_FORM_TITLE'),
    function      => $function,
    view          => $view,
    pkg_opts      => $pkg_opts,
    grp_opts      => $grp_opts,
    pkg_count     => scalar(@$pkg_opts),
    grp_count     => scalar(@$grp_opts),
    preselect_all => ($function eq 'update') ? 1 : 0,
  );

  return $c->render(template => 'dnf');
}

# GET /dnf/options/:function  (implemented for completeness)
sub dnf_options ($c) {
  my $function = $c->param('function') // '';
  return $c->render(json => { error => "Invalid function" }, status => 400)
    unless $function =~ /^(update|install|remove|configure)$/;

  # ADD THIS BLOCK (special-case configure)
  if ($function eq 'configure') {
    return $c->render(json => {
      function     => 'configure',
      view         => '',
      has_packages => 0,
      has_groups   => 0,
      packages     => [],
      groups       => [],
    });
  }

  my %map  = ( update => 'updates', install => 'available', remove => 'installed' );
  my $view = $map{$function};

  my ($pkg_opts, $grp_opts) = $c->_cached_options($view);
  
  return $c->render(json => { function => 'configure', view => '', packages => [], groups => [] });

  return $c->render(json => {
    function     => $function,
    view         => $view,
    has_packages => (@$pkg_opts ? 1 : 0),
    has_groups   => (@$grp_opts ? 1 : 0),
    packages     => $pkg_opts,
    groups       => $grp_opts,
  });
  
}

# POST /dnf/start/:function  (route uses start_dnf)
sub start_dnf ($c) {
  my $function = $c->param('function') // '';
  $c->app->log->info("DNF start dnf raw_function=[" . ($c->param('function') // '') . "] normalized=[$function]");
  $function = lc $function;
  $function =~ s/^\s+|\s+$//g;
  return $c->render(json => { error => "Invalid function" }, status => 400)
    unless $function =~ /^(update|install|remove|configure)$/;
  my $st = $c->_get_dnf_status;
  $c->app->log->info("DNF start_dnf requested; status=[$st]");
  if ($c->_is_dnf_running) {
    return $c->render(json => { error => "DNF is already running (status=$st)" }, status => 409);
  }
  my $cfg = $c->_open_cfg;

  my ($old_db, undef) = $c->_get_logfile_best_effort_with_source;

  # Save selections for the event script to read
  for my $param (qw(SelectedGroups SelectedPackages)) {
    my $values = $c->every_param($param) || [];
    $cfg->set_prop('dnf', $param, @$values ? join(',', @$values) : '');
  }
  $cfg->reload;

  esmith::util::backgroundCommand(0, "/sbin/e-smith/signal-event", "dnf-$function");

  $c->_clear_panel_cache;

  my $run_id  = int(time()*1000) . "-" . $$ . "-" . int(rand(1_000_000));
  my $t0_i    = int(time());
  return $c->render(json => { run_id => $run_id, started_i => $t0_i, old_db => $old_db });
}

# GET /dnf/stream/:run_id?started_i=...&old_db=...
# start at beginning + follow

use Mojo::Util qw(xml_escape);

my $DNF_END_MARKER_RE = qr/^---- dnf event finished at .*?\(exit=\d+\) ----/;

sub dnf_stream ($c) {
  my $t0_i   = int($c->param('started_i') // time());
  my $old_db = $c->param('old_db') // '';

  $c->app->log->info($c->log_req);

  $c->res->headers->cache_control('no-cache');
  $c->res->headers->content_type('text/html; charset=utf-8');
  $c->inactivity_timeout(0);   # disable for this connection
  $c->render_later;

  # Header
  $c->write_chunk(<<'HTML');
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Live DNF</title>
  <link rel="stylesheet" href="/smanager/css/dnf.css">
</head>
<body class="dnf-stream">
<div class="dnf-stream-panel">
<table class="dnf-stream-table"><tbody id="log-body">
HTML

  # Discover logfile (unchanged)
  my ($logfile, $logsrc) = ('', '');
  my $deadline = time() + 20;

  while (time() < $deadline) {
    my ($cur, $src) = $c->_get_logfile_best_effort_with_source;

    if ($cur && $cur =~ m{^/var/log/dnf/dnf\.log\.\d+$} && -e $cur && ($old_db eq '' || $cur ne $old_db)) {
      ($logfile, $logsrc) = ($cur, "dnf:LogFile via $src");
      last;
    }

    my $n = $c->_newest_log_since($t0_i, 2);
    if ($n && -e $n) {
      ($logfile, $logsrc) = ($n, "directory scan (newest_log_since >= start)");
      last;
    }

    select undef, undef, undef, 0.1;
  }

  unless ($logfile && -r $logfile) {
    $c->write_chunk('<tr><td><pre>' . xml_escape("Could not discover readable logfile\n") . "</pre></td></tr>");
    $c->write_chunk('</tbody></table></div></body></html>');
    return $c->finish;
  }

  $c->write_chunk(
    '<tr class="dnf-stream-meta"><td colspan="2"><div class="dnf-stream-meta-box">'
    . '<div><span class="k">Streaming:</span> <span class="v">' . xml_escape($logfile) . '</span></div>'
    . '<div><span class="k">Discovered via:</span> <span class="v">' . xml_escape($logsrc) . '</span></div>'
    . '</div></td></tr>'
  );

  # Start tail from beginning, follow
  open(my $fh, "-|", "/usr/bin/tail", "-n", "+1", "-F", "--", $logfile) or do {
    $c->write_chunk('<tr><td><pre>' . xml_escape("Failed to start tail on $logfile: $!\n") . "</pre></td></tr>");
    $c->write_chunk('</tbody></table></div></body></html>');
    return $c->finish;
  };

  my $stream_id = $$ . time;
  $c->stash(
    stream_id   => $stream_id,
    fh          => $fh,
    logfile     => $logfile,
    line_count  => 0,
    tail_buf    => '',   # partial line buffer
    tail_stream => undef # Mojo::IOLoop::Stream
  );

  # Stop tail if client disconnects
  $c->on(finish => sub ($c, @) {
    if (my $s = $c->stash('tail_stream')) {
      $s->close_gracefully;
      $c->stash(tail_stream => undef);
    }
    if (my $fh = $c->stash('fh')) {
      close $fh;
      $c->stash(fh => undef);
    }
  });
  SrvMngr::Controller::Dnf::dnf_next_chunk($c, $stream_id);
}

sub dnf_next_chunk ($c, $stream_id) {
  # Guard: correct stream?
  return unless ($c->stash('stream_id') // '') eq $stream_id;

  my $fh = $c->stash('fh') or return $c->finish;

  # Attach stream reader exactly once
  return if $c->stash('tail_stream');

  my $stream = Mojo::IOLoop::Stream->new($fh);
  $c->stash(tail_stream => $stream);

  $stream->timeout(0); # tail can be quiet for a long time

  $stream->on(read => sub ($s, $bytes) {
    return unless ($c->stash('stream_id') // '') eq $stream_id;

    my $buf = ($c->stash('tail_buf') // '') . $bytes;

    # Process complete lines; keep partial in stash
    my $chunk_html = '';
    my $max_lines  = 150;
    my $lines_out  = 0;

    while ($lines_out < $max_lines && $buf =~ s/^(.*?\n)//) {
      my $line = $1;

      my $line_count = ($c->stash('line_count') // 0) + 1;
      $c->stash(line_count => $line_count);

      my $saw_end = ($line =~ $DNF_END_MARKER_RE) ? 1 : 0;

      $chunk_html .= sprintf(
        '<tr><td class="line-num">%d</td><td class="line"><pre>%s</pre></td></tr>',
        $line_count, xml_escape($line)
      );

      $lines_out++;

      if ($saw_end) {
        # flush what we have, then end
        $c->stash(tail_buf => ''); # done
        $c->write_chunk($chunk_html => sub {
          $c->write_chunk('</tbody></table></div></body></html>' => sub {
            $s->close_gracefully;
            close $fh;
            $c->stash(fh => undef, tail_stream => undef);
            $c->_clear_panel_cache;
            $c->finish;
          });
        });
        return;
      }
    }

    # Save remaining partial line
    $c->stash(tail_buf => $buf);

    # Write any completed lines we accumulated
    $c->write_chunk($chunk_html) if length $chunk_html;
  });

  $stream->on(error => sub ($s, $err) {
    $c->app->log->error("DNF(tail) stream error: $err");
  });

  $stream->on(close => sub ($s) {
    $c->app->log->info("DNF(tail) stream closed");
  });

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running; # usually already running under hypnotoad
  $stream->start;
}

1;
