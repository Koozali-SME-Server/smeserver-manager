package SrvMngr::Controller::Viewlogfiles;

#----------------------------------------------------------------------
# heading     : Investigation
# description : View log files
# navigation  : 7000 100
#
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

#use esmith::FormMagick qw(gen_locale_date_string);

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);

use esmith::ConfigDB;
use Time::TAI64;
use File::Basename;
use HTML::Entities;
use esmith::FormMagick qw(gen_locale_date_string);
use File::Temp qw(tempfile);

use constant TRUE  => 1;
use constant FALSE => 0;

our $cdb = esmith::ConfigDB->open() || die "Couldn't open config db";

our @logfiles = ();	# with array


sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my %log_datas = ();
    my $title = $c->l('log_FORM_TITLE');
    my $notif = '';

    $log_datas{default_op} = 
	($cdb->get('viewlogfiles')->prop('DefaultOperation')) || 'view';

    $c->stash( title => $title, notif => $notif, log_datas => \%log_datas);
    $c->render(template => 'viewlogfiles');
};


sub do_action {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('log_FORM_TITLE');
    my $notif = '';
    my $result = "";
    my %log_datas = ();

    $log_datas{filename} = $c->param('Filename');
    $log_datas{matchpattern} = $c->param('Matchpattern');
    $log_datas{highlightpattern} = $c->param('Highlightpattern');
    $log_datas{operation} = $c->param('Operation');
    if ($log_datas{operation} eq 'download') {
	$log_datas{'trt'} = "DOWN"
    } else {
	$log_datas{'trt'} = "SHOW"
    }


    if ($log_datas{filename} =~ /^([\S\s]+)$/) {
	$log_datas{filename} = $1;
    } elsif ($log_datas{filename} =~ /^$/) {
	$log_datas{filename} = "messages";
    } else {
	$result .= $c->l("log_FILENAME_ERROR", $log_datas{filename} )
    	    . " ";
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
        $result .= $c->l("log_LOG_FILE_EMPTY", "$log_datas{filename}" );
    }

    if ($log_datas{trt} eq "SHOW") {
        if ( ! $result ) {
	    $result = $c->render_to_string(inline => showlogFile( $c, %log_datas ));
	}

	if ( $result ) {
	    $c->stash(title => $title, modul => $result, log_datas => \%log_datas);
	    return $c->render(template => 'viewlogfiles2');
	}
    }


    if ( $log_datas{trt} eq 'DOWN' ) {

	my $modul = 'Log file download';
	
	$notif = download_logFile( $c, %log_datas );
	return undef unless defined $notif;
    }

    $c->stash( title => $title, notif => $notif, log_datas => \%log_datas);
    $c->render(template => 'viewlogfiles');

};


sub timestamp2local
{
    $_ = shift;
    if (/^(\@[0-9a-f]{24})(.*)/s)
    {
	return Time::TAI64::tai64nlocal($1) . $2;
    }
    elsif (/^([0-9]{10}\.[0-9]{3})(.*)/s)
    {
	return localtime($1) . $2;
    }
    return $_;
}


sub findlogFiles {

    my $c = shift;

    use File::Find;
    sub findlogfiles
    {
        my $path = $File::Find::name;

        if (-f)
        {
            # Remove leading /var/log/messages
            $path =~ s:^/var/log/::;
            # don't bother to collect files known to be non-text
            # or not log files
            foreach (qw(
                lastlog
                btmp$
                wtmp
                lock
                (?<!qpsmtpd/)state
                httpd/ssl_mutex.\d*
                httpd/ssl_scache.pag
                httpd/ssl_scache.dir
                \/config$
            ))
            {
                return if $path =~ /$_/;
            }

            my ($file_base, $file_path, $file_type) = fileparse($path);

            if ( $file_base =~ /@.*/ )
            {
                #$logfiles{$path} = $file_path . timestamp2local($file_base);
		push @logfiles, [ $file_path . timestamp2local($file_base), $path  ];
            }
            else
            {
                #$logfiles{$path} = $path;
		push @logfiles, [ $path, $path ];
            }
        }
    }

    @logfiles = ();
    # Now go and find all the files under /var/log
    find({wanted => \&findlogfiles, no_chdir => 1}, '/var/log');

    my @logf = sort { $a->[0] cmp $b->[0] } @logfiles;

    return \@logf;
}


sub showlogFile {

    my ($c, %log_datas) = @_;

    my $fullpath = "/var/log/$log_datas{filename}";
    my $out = '';

    $out .= sprintf("$fullpath: \n");

    $out .= sprintf($c->l("log_VIEWING_TIME", $c->gen_locale_date_string() ));

    unless ( $log_datas{matchpattern} eq '.' )
    {
        #$out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_MATCH_HEADER", $log_datas{matchpattern}  ));
    }

    if ( $log_datas{highlightpattern} )
    {
        #$out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_HIGHLIGHT_HEADER", "$log_datas{highlightpattern}" ));
    }

    if ($log_datas{filename} =~ /\.gz$/) {
        my $pid = open(LOGFILE, "-|");
        die "Couldn't fork: $!" unless defined $pid;
        unless ($pid) {
            # Child
            exec("/bin/zcat", $fullpath)
            || die "Can't exec zcat: $!";
            # NOTREACHED
        }
    } else {
        open(LOGFILE, "$fullpath");
    }

    my $somethingMatched = 0;
    my $fileEmpty = 1;
    $out .= sprintf("<PRE>");
    while(<LOGFILE>)
    {
        $fileEmpty = 0;
        next unless /$log_datas{matchpattern}/;
        $somethingMatched = 1;

        $_ = timestamp2local($_);
        $_ = HTML::Entities::encode_entities($_);
        ($log_datas{highlightpattern} && /$log_datas{highlightpattern}/)
    	    ? $out .= sprintf( "<b>$_</b>" )
    	    : $out .= sprintf("$_");
    }
    $out .= sprintf("</PRE>");

    if ($fileEmpty) {
        $out .= sprintf("<p>\n");
        $out .= sprintf($c->l("log_LOG_FILE_EMPTY"));
    } else {
        unless ($somethingMatched)
        {
            $out .= sprintf("<p>\n");
            $out .= sprintf($c->l("log_NO_MATCHING_LINES"));
        }
    }

    close LOGFILE;

    return $out;
}


sub download_logFile {

    my ($c, %log_datas) = @_;

    my $fullpath = "/var/log/$log_datas{filename}";

    # Save this information for later.

    $cdb->get('viewlogfiles')->merge_props('DefaultOperation', $log_datas{operation});

    # If the client is on windows, we must handle this a little differently.
    my $win32 = FALSE;
    my $mac   = FALSE;
    my $agent = $ENV{HTTP_USER_AGENT} || "";
    if ($agent =~ /win32|windows/i) {
        $win32 = TRUE;
    }  elsif ($agent =~ /mac/i) {
        $mac = TRUE;
    }

    # Check for errors first. Once we start sending the file it's too late to
    # report them.
    my $error = "";
    unless (-f $fullpath)  {
        $error = $c->l("log_ERR_NOEXIST_FILE") . $fullpath;
    }

    local *FILE;
    open(FILE, "<$fullpath")
        or $error = $c->l("log_ERR_NOOPEN_FILE");
    # Put other error checking here. 
    return $error if $error;

    # Fix the filename, as it might have a directory prefixed to it. 
    my $filename = $log_datas{filename};
    if ( $filename =~ m#/# ) {
        $filename = (split /\//, $filename)[-1];
    }

    # And send the file.
    my $nl = "\n";
    if ($win32)  { $nl = "\r\n" }
    elsif ($mac) { $nl = "\r" }

    # Otherwise, send the file. Start with the headers.
    # Note: The Content-disposition must be attachment, or IE will view the
    # file inline like it's told. It ignores the Content-type, but it likes
    # the Content-disposition (an officially unsupported header) for some
    # reason. Yay Microsoft.

    my $file2 = new File::Temp( UNLINK => 0 );

    while (my $line = <FILE>) {
        chomp $line;
        my $linew = timestamp2local($line) . $nl;
        print $file2 $linew;
    }
    close(FILE);

    $c->render_file(
        'filepath' => "$file2",
        'filename' => "$filename",
        'format' => 'x-download',
	'content_disposition' => 'attachment',
        'cleanup' => 1,
    );

    return undef;
}


1;

