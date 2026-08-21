package SrvMngr::Controller::Mailanalog;

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
    my $title = $c->l('mai_FORM_TITLE');
    my $modul = $c->render_to_string(inline => $c->l('mai_INITIAL_DESC'));
    $c->stash(title => $title, modul => $modul);
    $c->render(template => 'mailanalog');
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
        $result      = $c->l('mai_INVALID_REPORT_TYPE') . $report_type;
        $report_type = undef;
    }
    my $title = $c->l('mai_FORM_TITLE');
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
    $out .= sprintf("<h3>%s %s </h3>", $c->l('mai_REPORT_GENERATED'), $now_string);
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
    elsif ($selected_report eq 'daily_summary_all') {
        $out .= daily_summary_report_all($log_path);  
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
		[$c->l('mai_Daily_Summary_Report_yesterday') => 'daily_summary'],
		[$c->l('mai_Daily_Summary_Report_today') => 'daily_summary_today'],
		[$c->l('mai_Daily_Summary_Report_all') => 'daily_summary_all'],
		#[$c->l('mai_Top Senders and Recipients') => 'top_senders'],
		#[$c->l('mai_Bounce Rate Analysis') => 'bounce_analysis'],
		#[$c->l('mai_Spam and Virus Filtering Report') => 'spam_and_virus'],
		#[$c->l('mai_Delivery Status Report') => 'delivery_status'],
		#[$c->l('mai_Geographic Analysis of Email') => 'geo_analysis'],
		#[$c->l('mai_Traffic Analysis') => 'traffic_analysis'],
		#[$c->l('mai_Authentication Analysis') => 'auth_analysis'],
		#[$c->l('mai_User Activity Report') => 'user_activity'],
		#[$c->l('mai_Error Reporting') => 'error_reporting'],
		#[$c->l('mai_Comparison Reports') => 'comparison_reports'],
		#[$c->l('mai_Customized Reports') => 'customized_reports'],
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

sub daily_summary_report_all {
    my $log_file = shift;  # Path to log file
    my $output = qx(ls -1 /var/log/maillog* | xargs cat |pflogsumm --detail 0 --no-no-msg-size);
    return format_as_html("Summary Report across all logs", $output);
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

1;
