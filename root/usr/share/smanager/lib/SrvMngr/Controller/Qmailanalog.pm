package SrvMngr::Controller::Qmailanalog;

#----------------------------------------------------------------------
# heading     : Investigation
# description : Mail log file analysis
# navigation  : 7000 200
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use SrvMngr qw(gen_locale_date_string);
use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw(theme_list init_session);
use List::Util qw(sum); 

#use Mail::Log::Trace::Postfix;

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $title = $c->l('qma_FORM_TITLE');
    my $modul = $c->render_to_string(inline => $c->l('qma_INITIAL_DESC'));
    $c->stash(title => $title, modul => $modul);
    $c->render(template => 'qmailanalog');
} ## end sub main

sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);
    my $result      = "";
    my $report_type = $c->param('report_type');

    if ($report_type =~ /^(\S+)$/) {
        $report_type = $1;
    } elsif ($report_type =~ /^\s*$/) {
        $report_type = "zoverall";
    } else {
        $result      = $c->l('INVALID_REPORT_TYPE') . $report_type;
        $report_type = undef;
    }
    my $title = $c->l('qma_FORM_TITLE');
    $result = $c->render_to_string(inline => generateReport($c, $report_type)) if $report_type;
    $c->stash(title => $title, modul => $result);
    $c->render(template => 'module');
} ## end sub do_update

sub generateReport {
    my $c           = shift;
    my $report_type = shift;
    my $out         = '';
    #------------------------------------------------------------
    # Go ahead and generate the report.
    #------------------------------------------------------------
    my $now_string = $c->gen_locale_date_string();
    my $log_path = '/var/log/maillog';
    $out .= sprintf("<h3>%s %s </h3>", $c->l('REPORT_GENERATED'), $now_string);
    $out .= sprintf "<pre>";
    # Get the selected report from the form submission
    my $selected_report = $report_type;

    # Call the relevant report sub based on the selection
    if ($selected_report eq 'daily_summary') {
        $out .= daily_summary_report($log_path);  
    }
    elsif ($selected_report eq 'daily_summary_today') {
        $out .= daily_summary_report_today($log_path);  
    }
    elsif ($selected_report eq 'top_senders') {
        $out .= top_senders_and_recipients($log_path);  
    }
    elsif ($selected_report eq 'bounce_analysis') {
        $out .= bounce_rate_analysis($log_path);  
    }
    elsif ($selected_report eq 'spam_and_virus') {
        $out .= spam_and_virus_filter_report($log_path);  
    }
    elsif ($selected_report eq 'delivery_status') {
        $out .= delivery_status_report($log_path);  
    }
    elsif ($selected_report eq 'geo_analysis') {
        $out .= geographical_analysis_of_email($log_path);  
    }
    elsif ($selected_report eq 'traffic_analysis') {
        $out .= traffic_analysis($log_path);  
    }
    elsif ($selected_report eq 'auth_analysis') {
        $out .= authentication_analysis($log_path);  
    }
    elsif ($selected_report eq 'user_activity') {
        $out .= user_activity_report($log_path);  
    }
    elsif ($selected_report eq 'error_reporting') {
        $out .= error_reporting($log_path);  
    }
    elsif ($selected_report eq 'comparison_reports') {
        $out .= comparison_reports($log_path, '/var/log/mail.log.1');
    }
    elsif ($selected_report eq 'customized_reports') {
        $out .= customized_reports($log_path);  
    }
    else {
        $out .= 'Invalid report selected';
    }

    # The $output variable now contains the generated report output.
    # Further processing can be done here, or you can render it later.
  
    $out .= sprintf "</pre>";
    $out .= sprintf("<h3>%s</h3>", $c->l('END_OF_REPORT'));
    return $out;
} ## end sub generateReport

sub reportType_list {
    my $c     = shift;
    my @array = (
		[$c->l('qma_Daily_Summary_Report_yesterday') => 'daily_summary'],
		[$c->l('qma_Daily_Summary_Report_today') => 'daily_summary_today'],
		#[$c->l('qma_Top Senders and Recipients') => 'top_senders'],
		#[$c->l('qma_Bounce Rate Analysis') => 'bounce_analysis'],
		#[$c->l('qma_Spam and Virus Filtering Report') => 'spam_and_virus'],
		#[$c->l('qma_Delivery Status Report') => 'delivery_status'],
		#[$c->l('qma_Geographic Analysis of Email') => 'geo_analysis'],
		#[$c->l('qma_Traffic Analysis') => 'traffic_analysis'],
		#[$c->l('qma_Authentication Analysis') => 'auth_analysis'],
		#[$c->l('qma_User Activity Report') => 'user_activity'],
		#[$c->l('qma_Error Reporting') => 'error_reporting'],
		#[$c->l('qma_Comparison Reports') => 'comparison_reports'],
		#[$c->l('qma_Customized Reports') => 'customized_reports'],
	);
    my @sorted_array = sort { $a->[0] cmp $b->[0] } @array;
    return \@sorted_array;
} ## end sub reportType_list

sub daily_summary_report {
    my $log_file = shift;  # Path to log file
    my $output = qx(ls -1 /var/log/maillog* | xargs cat |pflogsumm -d yesterday --detail 0 --no-no-msg-size);
    return format_as_html("Daily Summary Report", $output);
}

sub daily_summary_report_today {
    my $log_file = shift;  # Path to log file
    my $output = qx(ls -1 /var/log/maillog* | xargs cat |pflogsumm -d today --detail 0 --no-no-msg-size);
    return format_as_html("Daily Summary Report", $output);
}

sub top_senders_and_recipients {
    my $log_file = shift;
    my $output = qx(pflogsumm --smtpd-stats $log_file);
    return format_as_html("Top Senders and Recipients", $output);
}

sub bounce_rate_analysis {
    my $log_file = shift;
    my $output = qx(pflogsumm --bounce-detail 10 $log_file);  # Show up to 10 bounce details
    return format_as_html("Bounce Rate Analysis", $output);
}

sub spam_and_virus_filter_report {
    my $log_file = shift;
    my $output = qx(pflogsumm -u 10 $log_file);  # User report with up to 10 entries
    return format_as_html("Spam and Virus Filtering Report", $output);
}

sub delivery_status_report {
    my $log_file = shift;
    my $output = qx(pflogsumm --deferral-detail 10 $log_file);  # Show deferral details
    return format_as_html("Delivery Status Report", $output);
}

sub geographical_analysis_of_email {
    my $log_file = shift;
    # `pflogsumm` doesn't have a specific option for geographic analysis in the help text;
    # It's assumed this could be replaced with something relevant, like a SMTP detail.
    my $output = qx(pflogsumm --smtp-detail 10 $log_file);  # Show up to 10 SMTP details
    return format_as_html("Geographic Analysis of Email", $output);
}

sub traffic_analysis {
    my $log_file = shift;
    my $output = qx(pflogsumm --verbose-msg-detail $log_file);  # Request verbose detail
    return format_as_html("Traffic Analysis", $output);
}

sub authentication_analysis {
    my $log_file = shift;
    my $output = qx(pflogsumm -u 10 --verbose-msg-detail $log_file);  # User detailed report
    return format_as_html("Authentication Analysis", $output);
}

sub user_activity_report {
    my $log_file = shift;
    my $output = qx(pflogsumm -u 20 $log_file);  # Show user activity for up to 20 users
    return format_as_html("User Activity Report", $output);
}

sub error_reporting {
    my $log_file = shift;
    my $output = qx(pflogsumm --problems-first $log_file);  # This will show problems first
    return format_as_html("Error Reporting", $output);
}

sub comparison_reports {
    my ($log_file1, $log_file2) = @_; # Comparing two log files
    my $output = qx(pflogsumm $log_file1 $log_file2);  # Standard comparison without special flags
    return format_as_html("Comparison Reports", $output);
}

sub customized_reports {
    my $log_file = shift;
    # Because we don't have a concrete custom flag, we'll consider using -d with specific detail.
    my $output = qx(pflogsumm --detail 10 $log_file);  # Generally show detailed summary
    return format_as_html("Customized Reports", $output);
}

sub format_as_html {
    my ($title, $content) = @_;
    return <<HTML;
<h2>$title</h2>
<pre>$content</pre>
HTML
}


### 1. Message Tracking
#sub trace_message {
    #my ($log_path, $message_id) = @_;
    ##my $tracer = Mail::Log::Trace::Postfix->new({log_file => $log_path});
    ##$tracer->set_message_id($message_id);
    
    #my $output = "Message Tracking Report for ID: $message_id\n";
    ##$output .= "=" x 50 . "\n";
    ##$output .= sprintf "%-12s: %s\n", 'From', $tracer->get_from_address;
    ##$output .= sprintf "%-12s: %s\n", 'Status', $tracer->get_final_status;
    
    ##$output .= "\nRecipients:\n";
    ##$output .= join("\n", map { "- $_" } $tracer->get_recipient_addresses);
    
    ##$output .= "\n\nTimeline:\n";
    ##my $timeline = $tracer->get_timestamps;
    ##while (my ($stage, $time) = each %$timeline) {
        ##$output .= sprintf "%-10s: %s\n", ucfirst($stage), $time;
    ##}
    
    #return $output || "No records found for message ID: $message_id";
#}

#### 2. Queue Analysis
#sub get_queue_stats {
    #my $spool_dir = '/var/spool/postfix';
    #my %queues = map { $_ => 0 } qw(active deferred bounce hold corrupt);
    
    #foreach my $q (keys %queues) {
        #opendir(my $dh, "$spool_dir/$q");
        #$queues{$q} = scalar(grep { -f "$spool_dir/$q/$_" } readdir($dh));
        #closedir($dh);
    #}
    
    #my $output = "Current Postfix Queue Status\n";
    #$output .= "=" x 30 . "\n";
    #$output .= sprintf "%-10s: %3d messages\n", ucfirst($_), $queues{$_} 
        #for sort keys %queues;
    #$output .= "\nTotal: " . sum(values %queues) . " messages in queue";
    
    #return $output;
#}

#### 3. Message Statistics
#sub get_message_stats {
    #my ($log_path) = @_;
    #my %stats = (received => 0, rejected => 0, delivered => 0, 
                #deferred => 0, bounced => 0, held => 0);

    #open(my $fh, '<', $log_path);
    #while(<$fh>) {
        #$stats{received}++ if /qmgr.*: [A-Z0-9]+: from=/;
        #$stats{delivered}++ if /status=sent/;
        #$stats{rejected}++ if /NOQUEUE: reject/;
        #$stats{deferred}++ if /status=deferred/;
        #$stats{bounced}++ if /status=bounced/;
        #$stats{held}++ if /status=hold/;
    #}
    #close($fh);
    
    #my $output = "Message Statistics for " . localtime . "\n";
    #$output .= "=" x 40 . "\n";
    #$output .= sprintf "%-12s: %6d\n", 'Received', $stats{received};
    #$output .= sprintf "%-12s: %6d (%.1f%%)\n", 'Delivered', $stats{delivered},
        #($stats{received} ? ($stats{delivered}/$stats{received}*100) : 0);
    #$output .= sprintf "%-12s: %6d\n", 'Rejected', $stats{rejected};
    #$output .= sprintf "%-12s: %6d\n", 'Deferred', $stats{deferred};
    #$output .= sprintf "%-12s: %6d\n", 'Bounced', $stats{bounced};
    #$output .= sprintf "%-12s: %6d\n", 'Held', $stats{held};
    
    #return $output;
#}

#### 4. User Activity Audit
#sub get_user_activity {
    #my ($log_path, $email) = @_;
    ##my $tracer = Mail::Log::Trace::Postfix->new({log_file => $log_path});
    
    ##my $sent = scalar $tracer->find_messages_by_sender($email);
    ##my $received = scalar $tracer->find_messages_by_recipient($email);
    
    #my $output = "Activity Report for: $email\n";
    ##$output .= "=" x (length($email) + 18) . "\n";
    ##$output .= "Messages sent:     $sent\n";
    ##$output .= "Messages received: $received\n\n";
    
    ##$output .= "Last week's activity:\n";
    ##$output .= join("\n", map { sprintf "- %s: %d messages", $_->[0], $_->[1] }
        ##$tracer->get_weekly_stats($email));
    
    #return $output || "No activity found for $email";
#}

#### 5. Security Monitoring
#sub detect_auth_failures {
    #my ($log_path) = @_;
    #my %failures;
    
    #open(my $fh, '<', $log_path);
    #while(<$fh>) {
        #if(/SASL (?:LOGIN|PLAIN) authentication failed.*?\[([0-9.]+)\]/) {
            #$failures{$1}++;
        #}
    #}
    #close($fh);
    
    #return "No authentication failures found" unless keys %failures;
    
    #my $output = "Authentication Failure Report\n";
    #$output .= "=" x 30 . "\n";
    #$output .= sprintf "%-15s %s\n", 'IP Address', 'Attempts';
    #$output .= sprintf "%-15s %s\n", '-' x 15, '-' x 7;
    
    #foreach my $ip (sort { $failures{$b} <=> $failures{$a} } keys %failures) {
        #$output .= sprintf "%-15s %5d\n", $ip, $failures{$ip};
    #}
    #$output .= "\nTotal failures: " . sum(values %failures);
    
    #return $output;
#}




1;