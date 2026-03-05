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

# END marker emitted by your event script
my $DNF_END_MARKER_RE = qr/^---- dnf event finished at .*?\(exit=\d+\) ----/;

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

# ---- Actions ----

sub dnf_partial ($c) {
  # Same logic as do_show, but renders only _dnf_show
  my $function = $c->param('function') // 'update';
  $function = lc $function;
  $function =~ s/^\s+|\s+$//g;
  $function = 'update' unless $function =~ /^(update|install|remove)$/;

  my %map  = ( update => 'updates', install => 'available', remove => 'installed' );
  my $view = $map{$function};

  my ($pkg_opts, $grp_opts) = $c->_cached_options($view);

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
  my $function = $c->param('function') // 'update';
  $c->app->log->info("DNF do_show raw_function=[" . ($c->param('function') // '') . "] normalized=[$function]");
  $function = lc $function;
  $function =~ s/^\s+|\s+$//g;   # trim
  $function = 'update' unless $function =~ /^(update|install|remove)$/;

  my %map  = ( update => 'updates', install => 'available', remove => 'installed' );
  my $view = $map{$function};

  my ($pkg_opts, $grp_opts) = $c->_cached_options($view);

  $c->app->log->info("DNF do_show function=$function view=$view pkg=" . scalar(@$pkg_opts) . " grp=" . scalar(@$grp_opts));

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
    unless $function =~ /^(update|install|remove)$/;

  my %map  = ( update => 'updates', install => 'available', remove => 'installed' );
  my $view = $map{$function};

  my ($pkg_opts, $grp_opts) = $c->_cached_options($view);

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
    unless $function =~ /^(update|install|remove)$/;
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
sub dnf_stream ($c) {
  my $t0_i   = int($c->param('started_i') // time());
  my $old_db = $c->param('old_db') // '';

  $c->res->headers->header('X-Accel-Buffering' => 'no');
  $c->res->headers->cache_control('no-cache');
  $c->res->headers->content_type('text/html; charset=utf-8');
  $c->render_later;

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

  open(my $fh, '<', $logfile) or do {
    $c->write_chunk('<tr><td><pre>' . xml_escape("Failed to open $logfile: $!\n") . "</pre></td></tr>");
    $c->write_chunk('</tbody></table></div></body></html>');
    return $c->finish;
  };

  my $stream_id = $$ . time . rand();
  $c->stash(stream_id => $stream_id, fh => $fh, pos => 0, line_count => 0);

  _dnf_next_chunk($c, $stream_id);
}

sub _dnf_next_chunk ($c, $stream_id) {
  return unless ($c->stash('stream_id') // '') eq $stream_id;

  my $fh = $c->stash('fh') or return $c->finish;

  my $pos        = $c->stash('pos') // 0;
  my $line_count = $c->stash('line_count') // 0;

  seek($fh, $pos, 0);

  my $chunk = '';
  my $lines = 0;
  my $max_lines = 150;
  my $saw_end = 0;

  while ($lines < $max_lines && (my $line = <$fh>)) {
    $lines++;
    $line_count++;
    $saw_end = 1 if $line =~ $DNF_END_MARKER_RE;

    $chunk .= sprintf(
      '<tr><td class="line-num">%d</td><td class="line"><pre>%s</pre></td></tr>',
      $line_count, xml_escape($line)
    );
  }

  my $newpos = tell($fh);
  $c->stash(pos => $newpos, line_count => $line_count);

  $c->write_chunk($chunk) if length $chunk;

  if ($saw_end) {
    $c->write_chunk('</tbody></table></div></body></html>');
    close $fh;
    $c->stash(fh => undef);
    $c->_clear_panel_cache;
    return $c->finish;
  }

  Mojo::IOLoop->timer(0.25 => sub { _dnf_next_chunk($c, $stream_id) });
}

1;
