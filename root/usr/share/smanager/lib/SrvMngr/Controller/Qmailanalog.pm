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

use esmith::FormMagick qw(gen_locale_date_string);

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);

sub main {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my $title = $c->l('qma_FORM_TITLE');
    my $modul = $c->render_to_string(inline => $c->l('qma_INITIAL_DESC'));

    $c->stash( title => $title, modul => $modul );
    $c->render(template => 'qmailanalog');
};


sub do_update {
    my $c = shift;
    $c->app->log->info($c->log_req);

    my $result = "";

    my $report_type = $c->param('report_type');

    if ($report_type =~ /^(\S+)$/)
    {
    	$report_type = $1;
    }
    elsif ($report_type =~ /^\s*$/)
    {
	$report_type = "zoverall";
    }  else {
	    $result = $c->l('INVALID_REPORT_TYPE') . $report_type;
	    $report_type = undef;
	}

    my $title = $c->l('qma_FORM_TITLE');

    $result = $c->render_to_string(inline => generateReport($c, $report_type)) if $report_type;

    $c->stash( title => $title, modul => $result );
    $c->render(template => 'module');
};


sub generateReport {

	my $c = shift;
	my $report_type = shift;

	my $out = '';
	
	#------------------------------------------------------------
	# Looks good; go ahead and generate the report.
	#------------------------------------------------------------

#	$| = 1;

	my $now_string = $c->gen_locale_date_string();
	$out .= sprintf("<h3>%s %s </h3>", $c->l('REPORT_GENERATED'), $now_string);

	if ($report_type =~ /^qmail-q/)
	{
		open(QMAILQUEUEREPORT, "/var/qmail/bin/$report_type |");

		$out .= sprintf "<pre>";

		while (<QMAILQUEUEREPORT>)
		{
			$out .= sprintf("%s", $_);
		}

		close QMAILQUEUEREPORT;
		$out .= sprintf "</pre>";

		$out .= sprintf("<h3>%s</h3>", $c->l('END_OF_REPORT'));
		return '';
	}

	chdir "/var/log/qmail";

	open(QMAILANALOG,
	"/bin/cat \@* current 2>/dev/null"
	    . "| /usr/local/bin/tai64nunix"
	    . "| /usr/local/qmailanalog/bin/matchup 5>/dev/null"
	    . "| /usr/local/qmailanalog/bin/$report_type |"
	);

	$out .= sprintf "<pre>";

	while (<QMAILANALOG>)
	{
		# Cook any special HTML characters

		s/\&/\&amp;/g;
		s/\"/\&quot;/g;
		s/\>/\&gt;/g;
		s/\</\&lt;/g;

			$out .= sprintf("%s", $_);
	}

	close QMAILANALOG;
	$out .= sprintf "</pre>";


	$out .= sprintf("<h3>%s</h3>", $c->l('END_OF_REPORT'));
	return $out;

}


sub reportType_list {

    my $c = shift;
    
    my @array = (
#        [ $c->l('qma_LIST_OUTGOING') => 'qmail-qread' ],
#        [ $c->l('qma_SUMMARIZE_QUEUE') => 'qmail-qstat' ],
        [ $c->l('qma_SUCCESSFUL_DELIVERY_DELAY') => 'zddist' ],
        [ $c->l('qma_REASONS_DEFERRAL') => 'zdeferrals' ],
        [ $c->l('qma_REASONS_FAILURE') => 'zfailures' ],
        [ $c->l('qma_BASIC_STATS') => 'zoverall' ],
        [ $c->l('qma_RECIP_STATS') => 'zrecipients' ],
        [ $c->l('qma_RECIP_HOSTS') => 'zrhosts' ],
        [ $c->l('qma_RECIP_ORDERED') => 'zrxdelay' ],
        [ $c->l('qma_SENDER_STATS') => 'zsenders' ],
        [ $c->l('qma_SENDMAIL_STYLE') => 'zsendmail' ],
        [ $c->l('qma_REASONS_SUCCESS') => 'zsuccesses' ],
        [ $c->l('qma_SENDER_UIDS') => 'zsuids' ]
    );
    my @sorted_array = sort { $a->[0] cmp $b->[0] } @array;
    return \@sorted_array;
}

1;
