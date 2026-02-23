package SrvMngr::Controller::Viewlogfiles;

#----------------------------------------------------------------------
# heading     : Investigation
# description : View log files
# navigation  : 7000 100
#
# for info (from SrvMngs.pm)
    #$if_admin->get('/viewlogfiles')->to('viewlogfiles#main')->name('viewlogfiles');
    #$if_admin->post('/viewlogfilesd')->to('viewlogfiles#do_action')->name('viewlogfilesd');
    #$if_admin->post('/viewlogfilesr')->to('viewlogfiles#do_action')->name('viewlogfilesr');
    #$if_admin->get('/viewlogfilest')->to('viewlogfiles#stream_logs', format => 0)->name('viewlogfilest');
    
    #$if_admin->get('/viewlogfilesl')->to('viewlogfiles#live_page', format => 0)->name('viewlogfilesl');
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use File::Basename;
use HTML::Entities;
use SrvMngr qw(gen_locale_date_string);
use File::Temp qw(tempfile);
use constant TRUE  => 1;
use constant FALSE => 0;
use esmith::ConfigDB::UTF8;

our $cdb;
our @logfiles = ();    # with array

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my %log_datas = ();
    my $title     = $c->l('log_FORM_TITLE');
    my $notif     = '';
    $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";
    my $viewlog = $cdb->get('viewlogfiles');
    $log_datas{default_op} = ($viewlog ? $viewlog->prop('DefaultOperation') : undef) || 'view';
    $c->stash(title => $title, notif => $notif, log_datas => \%log_datas);
    $c->render(template => 'viewlogfiles');
} ## end sub main

sub do_action {
    my $c = shift;
    $c->app->log->info($c->log_req);
    #my $fred = 1/0;
    my $title     = $c->l('log_FORM_TITLE');
    my $notif     = '';
    my $result    = "";
    my %log_datas = ();
    $log_datas{filename}         = $c->param('Filename');
    $log_datas{matchpattern}     = $c->param('Matchpattern');
    $log_datas{highlightpattern} = $c->param('Highlightpattern');
    $log_datas{operation}        = $c->param('Operation');

    if ($log_datas{operation} eq 'download') {
        $log_datas{'trt'} = "DOWN";
    } else {
        $log_datas{'trt'} = "SHOW";
    }

    if ($log_datas{filename} =~ /^([\S\s]+)$/) {
        $log_datas{filename} = $1;
    } elsif ($log_datas{filename} =~ /^$/) {
        $log_datas{filename} = "messages";
    } else {
        $result .= $c->l("log_FILENAME_ERROR", $log_datas{filename}) . " ";
    }

    if ($log_datas{matchpattern} =~ /^(\S+)$/) {
        $log_datas{matchpattern} = $1;
    } else {
        $log_datas{matchpattern} = ".";
    }

    if ($log_datas{highlightpattern} =~ /^(\S+)$/) {
        $log_datas{highlightpattern} = $1;
    } else {
        $log_datas{highlightpattern} = '';
    }
    my $fullpath = "/var/log/$log_datas{filename}";

    if (-z $fullpath) {
        $result .= $c->l("log_LOG_FILE_EMPTY", "$log_datas{filename}");
    }

    if ($log_datas{trt} eq "SHOW") {
		$c->app->log->info("Show");
        #if (!$result) {
        #    $result = $c->render_to_string(inline => showlogFile($c, %log_datas));
        #}

        #if ($result) {
            $c->stash(title => $title, modul => $result, log_datas => \%log_datas);
            return $c->live_page();
        #}
    } ## end if ($log_datas{trt} eq...)

    if ($log_datas{trt} eq 'DOWN') {
		$c->app->log->info("Down");
        my $modul = 'Log file download';
        $notif = download_logFile($c, %log_datas);
        return undef unless defined $notif;
    } ## end if ($log_datas{trt} eq...)
    $c->stash(title => $title, notif => $notif, log_datas => \%log_datas);
    return $c->render(template => 'viewlogfiles');
} ## end sub do_action

sub timestamp2local {
    $_ = shift;

    #if (/^(\@[0-9a-f]{24})(.*)/s) {
    #    return Time::TAI64::tai64nlocal($1) . $2;
    #} els
	if (/^([0-9]{10}\.[0-9]{3})(.*)/s) {
		return localtime($1) . $2;
    }
    return $_;
} ## end sub timestamp2local

sub findlogFiles {
    my $c = shift;
    use File::Find;

    sub findlogfiles {
        my $full_path = $File::Find::name;  # full path on disk
        my $path      = $full_path;         # display/value path (trimmed)

        # Only regular files ending in .log
        return unless -f $full_path;
        #return unless $full_path =~ /\.log\z/;   #maillog, messages etc not .log

        # Skip empty (zero-length) files
        my $bytes = (stat($full_path))[7];
        return if !defined($bytes) || $bytes == 0;

        # Remove leading /var/log/
        $path =~ s:^/var/log/::;

        # don't bother to collect files known to be non-text
        # or not log files
        foreach (
            qw(
            journal
            lastlog
            btmp$
            wtmp
            lock
            (?<!qpsmtpd/)state
            httpd/ssl_mutex.\d*
            httpd/ssl_scache.pag
            httpd/ssl_scache.dir
            \/config$
            )
          )
        {
            return if $path =~ /$_/;
        }
        
        # consider if file is a .gz compressed file
        #if (is_gzipped($full_path)){ return;} - gzipped now processed by zcat

        # Size adjunct "(<size> mb)"
        my $mb = $bytes / (1024 * 1024);
        my $size_suffix = sprintf(' (%.2f mb)', $mb);

        my ($file_base, $file_path, $file_type) = fileparse($path);

        if ($file_base =~ /@.*/) {
            push @logfiles, [ $file_path . timestamp2local($file_base) . $size_suffix, $path ];
        } else {
            push @logfiles, [ $path . $size_suffix, $path ];
        }
    }

    @logfiles = ();

    # Now go and find all the files under /var/log
    find({ wanted => \&findlogfiles, no_chdir => 1 }, '/var/log');
    my @logf = sort { $a->[0] cmp $b->[0] } @logfiles;
    return \@logf;
}

sub showlogFile {
	#
	# Not used - Feb 2026
	#
    my ($c, %log_datas) = @_;
    my $fullpath = "/var/log/$log_datas{filename}";
    my $out      = '';
    $out .= sprintf("$fullpath: \n");
    $out .= sprintf($c->l("log_VIEWING_TIME", $c->gen_locale_date_string()));

    unless ($log_datas{matchpattern} eq '.') {

        #$out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_MATCH_HEADER", $log_datas{matchpattern}));
    } ## end unless ($log_datas{matchpattern...})

    if ($log_datas{highlightpattern}) {

        #$out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_HIGHLIGHT_HEADER", "$log_datas{highlightpattern}"));
    } ## end if ($log_datas{highlightpattern...})

    if ($log_datas{filename} =~ /\.gz$/) {
        my $pid = open(LOGFILE, "-|");
        die "Couldn't fork: $!" unless defined $pid;

        unless ($pid) {

            # Child
            exec("/bin/zcat", $fullpath)
                || die "Can't exec zcat: $!";

            # NOTREACHED
        } ## end unless ($pid)
    } else {
        open(LOGFILE, "$fullpath");
    }
    my $somethingMatched = 0;
    my $fileEmpty        = 1;
    $out .= sprintf("<PRE>");

    while (<LOGFILE>) {
        $fileEmpty = 0;
        next unless /$log_datas{matchpattern}/;
        $somethingMatched = 1;
        $_                = timestamp2local($_);
        $_                = HTML::Entities::encode_entities($_);
        ($log_datas{highlightpattern} && /$log_datas{highlightpattern}/)
            ? $out .= "<b>$_</b>"
            : $out .= "$_";
    } ## end while (<LOGFILE>)
    $out .= sprintf("</PRE>");

    if ($fileEmpty) {
        $out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_LOG_FILE_EMPTY"));
    } else {

        unless ($somethingMatched) {
            $out .= sprintf("<p>\n");
            $out .= sprintf($c->l("log_NO_MATCHING_LINES"));
        }
    } ## end else [ if ($fileEmpty) ]
    close LOGFILE;
    return $out;
} ## end sub showlogFile

sub download_logFile {
    my ($c, %log_datas) = @_;
    my $fullpath = "/var/log/$log_datas{filename}";
    $cdb = esmith::ConfigDB::UTF8->open() || die "Couldn't open config db";

    # Save this information for later.
    $cdb->get('viewlogfiles')->merge_props('DefaultOperation', $log_datas{operation});

    # If the client is on windows, we must handle this a little differently.
    my $win32 = FALSE;
    my $mac   = FALSE;
    my $agent = $ENV{HTTP_USER_AGENT} || "";

    if ($agent =~ /win32|windows/i) {
        $win32 = TRUE;
    } elsif ($agent =~ /mac/i) {
        $mac = TRUE;
    }

    # Check for errors first. Once we start sending the file it's too late to
    # report them.
    my $error = "";

    unless (-f $fullpath) {
        $error = $c->l("log_ERR_NOEXIST_FILE") . $fullpath;
    }
    local *FILE;
    open(FILE, "<$fullpath")
        or $error = $c->l("log_ERR_NOOPEN_FILE");

    # Put other error checking here.
    return $error if $error;

    # Fix the filename, as it might have a directory prefixed to it.
    my $filename = $log_datas{filename};

    if ($filename =~ m#/#) {
        $filename = (split /\//, $filename)[-1];
    }

    # And send the file.
    my $nl = "\n";
    if    ($win32) { $nl = "\r\n" }
    elsif ($mac)   { $nl = "\r" }

    # Otherwise, send the file. Start with the headers.
    # Note: The Content-disposition must be attachment, or IE will view the
    # file inline like it's told. It ignores the Content-type, but it likes
    # the Content-disposition (an officially unsupported header) for some
    # reason. Yay Microsoft.
    my $file2 = new File::Temp(UNLINK => 0);

    while (my $line = <FILE>) {
        chomp $line;
        my $linew = timestamp2local($line) . $nl;
        print $file2 $linew;
    } ## end while (my $line = <FILE>)
    close(FILE);
    $c->render_file(
        'filepath'            => "$file2",
        'filename'            => "$filename",
        'format'              => 'x-download',
        'content_disposition' => 'attachment',
        'cleanup'             => 1,
    );
    return undef;
} ## end sub download_logFile

sub is_gzipped {
    my $filename = shift;
    return 0 unless -f $filename;
    
    open my $fh, '<:raw', $filename or return 0;
    my $bytes;
    my $bytes_read = read($fh, $bytes, 2);
    close $fh;
    
    return $bytes_read == 2 && $bytes eq "\x1f\x8b";
}


sub stream_logs {
    my $c = shift;
    $c->app->log->info($c->log_req);
    
    my $filename = $c->param('Filename') // 'messages';
	my $filter    = $c->param('Matchpattern') // '';
	my $highlight = $c->param('highlight') // '';
	
   
    $filename = "/var/log/$filename" unless $filename =~ m{^/var/log/};
    $filename =~ s{[^\w./-]}{}g;
    
    unless (-r $filename) {
        $c->reply->not_found;
        return;
    }
    
    my $fh; 
    if (is_gzipped($filename)) {
		open $fh, "-|", "zcat", $filename or die "Cannot zcat $filename: $!";
		$c->app->log->debug("Using zcat for $filename");
	} else {
		open $fh, "<", $filename or die "Cannot open $filename: $!";
		$c->app->log->debug( "Using direct read for $filename");
	}

    $c->res->headers->header('X-Accel-Buffering' => 'no');
    $c->res->headers->cache_control('no-cache');
    $c->res->headers->content_type('text/html');
    $c->render_later;

    # Store filehandle in stash with unique ID to avoid conflicts
    my $stream_id = $$ . time;
    $c->stash(stream_id => $stream_id, fh => $fh, filter => $filter, highlight => $highlight);

    # Header
    $c->write_chunk(<<"HTML");
<!DOCTYPE html>
<html>
<head>
    <title>Live: $filename</title>
    <link rel="stylesheet" href="css/viewlogfiles.css">
</head>
<body>
    <div class="header viewlogfiles-panel">
       <!-- <strong>Live: $filename</strong>-->
HTML
    
    #$c->write_chunk("<span class=fl>Filter: $filter</span> ") if $filter;
    #$c->write_chunk("<span class=hl>Highlight: $highlight</span>") if $highlight;
    $c->write_chunk('</div><div class=viewlogfiles-panel><table><tbody id="log-body">');

    # Start streaming
    SrvMngr::Controller::Viewlogfiles::stream_next_chunk($c,$stream_id);
}

sub stream_next_chunk {
    my ($c, $stream_id) = @_;
    # Verify this is the right stream
    return unless $c->stash('stream_id') eq $stream_id;
    
    my $fh = $c->stash('fh') or return $c->finish;
    my $filter = $c->stash('filter') // '';
    my $highlight = $c->stash('highlight') // '';
    my $line_count = $c->stash('line_count') // 0;
    #$c->app->log->info("Filter:$filter Highlight:$highlight");
    my $chunk_html = '';
    my $lines_read = 0;
    my $max_lines = 50;
    
    while ($lines_read < $max_lines && (my $line = <$fh>)) {
	# Enhanced filter - supports both literal text and /regex/ patterns
		next if $filter && do {
			if ($filter =~ m{^/(.*)/$}) {
				my $regex = $1;
				$line !~ qr/$regex/;
			} else {
				my $quoted = quotemeta($filter);
				$line !~ qr/$quoted/i;
			}
		};
      
        $line_count++;
        $lines_read++;
        
        # enhanced highlight - supports both literal text and /regex/ patterns
		my $escaped = Mojo::Util::xml_escape($line);
		if ($highlight) {
			if ($highlight =~ m{^/(.*)/$} ) {
				# Regex mode - extract pattern between slashes
				my $regex_pattern = $1;
				if ($line =~ m/$regex_pattern/g) {
					#$c->app->log->info("Regex:$regex_pattern");
					$escaped =~ s/($regex_pattern)/<span class="hl">$1<\/span>/gi;
				}
			} else {
				# Plain text mode
				my $quoted = quotemeta($highlight);   # or: my $quoted = "\Q$highlight\E";
				#$c->app->log->info("Not Regex:$quoted");
				$escaped =~ s/($quoted)/<span class="hl">$1<\/span>/gi;
			}
		}

		$chunk_html .= sprintf(
			'<tr><td class="line-num">%d</td><td><pre>%s</pre></td></tr>',
			$line_count, $escaped
		);
    }
    
    $c->stash(line_count => $line_count); 
    
    if ($chunk_html) {
		# this blows CSP, not sure if we need it or not.
        #$chunk_html .= '<script>window.scrollTo(0,document.body.scrollHeight);</script>';
        $c->write_chunk($chunk_html);
        
        # Chain next chunk
        Mojo::IOLoop->timer(0.2 => sub {
            SrvMngr::Controller::Viewlogfiles::stream_next_chunk($c,$stream_id);
        });
    } else {
        $c->write_chunk('</tbody></table></div></body></html>');
        close $fh;
        $c->stash(fh => undef);
        $c->finish;
    }
}

sub live_page {
    my $c = shift;
    #my $fred = 1/0;
    my $file      = $c->param('Filename') // 'messages';
    my $filter    = $c->param('Matchpattern') // '';
    my $highlight = $c->param('Highlightpattern') // '';
	$c->app->log->info("Stream_logs:$file $filter $highlight");
    
    # Build iframe src to the actual streaming endpoint
    my $src = $c->url_for('viewlogfilest')->query(
		Filename 		=> $c->param('Filename') // 'messages',
        Matchpattern  	=> $c->param('Matchpattern') // '',
        highlight 		=> $c->param('Highlightpattern') // '',
    );
    $c->app->log->info($src);
   	$c->stash(
        title     => $c->l('log_FORM_TITLE'),
		Filename 		=> $c->param('Filename') // 'messages',
        Matchpattern  	=> $c->param('Matchpattern') // '',
        highlight 		=> $c->param('Highlightpattern') // '',
        stream_src => $src,
    );
    return $c->render(template => 'viewlogfiles2');
}


1;
