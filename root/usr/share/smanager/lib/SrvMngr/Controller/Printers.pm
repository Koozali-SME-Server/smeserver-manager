package SrvMngr::Controller::Printers;

#----------------------------------------------------------------------
# heading     : System
# description : Printers
# navigation  : 4000 800
#
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;

use SrvMngr qw(theme_list init_session);

use esmith::FormMagick::Panel::printers;

our $adb = esmith::AccountsDB->open || die "Couldn't open accounts db";

sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %prt_datas = ();
    my $title = $c->l('prt_FORM_TITLE');

    $prt_datas{'trt'} = 'LIST';

    my @printerDrivers;
    if ($adb)
    {
        @printerDrivers = $adb->printers();
    }

    $c->stash( title => $title, prt_datas => \%prt_datas, printerDrivers => \@printerDrivers );
    $c->render(template => 'printers');

};


sub do_display {

    my $c = shift;

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');
    my $printer = $c->param('printer') || '';

    #$trt = 'DEL' if ( $printer );
    #$trt = 'ADD' if ( $rt eq 'printeradd' );

    my %prt_datas = ();
    my $title = $c->l('prt_FORM_TITLE');

    $prt_datas{'trt'} = $trt;

        if ( $trt eq 'ADD' ) {

	# nothing

        }

        if ( $trt eq 'DEL' ) {

	    my $rec = $adb->get($printer);
	    if ($rec and $rec->prop('type') eq 'printer') {
    		$prt_datas{printer} = $printer;
    		$prt_datas{description} = $rec->prop('Description') || '';
	    }

        }

        if ( $trt eq 'LIST' ) {
	    my @printerDrivers;
	    if ($adb)
	    {
    		@printerDrivers = $adb->printers();
	    }
            $c->stash( printerDrivers => \@printerDrivers );

	}

    $c->stash( title => $title, prt_datas => \%prt_datas );
    $c->render( template => 'printers' );

};


sub do_update {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || 'LIST');

    my %prt_datas = ();
    my $title = $c->l('prt_FORM_TITLE');
    $prt_datas{'trt'} = $trt;

    my ($res, $result) = '';

    if ( $trt eq 'ADD' ) {

	my $name = ($c->param('Name') || '');
        my $description = ($c->param('Description') || '');
        my $location = ($c->param('Location') || '');

	# controls
	$res = $c->validate_printer( $name, $description, $location );
	$result .= $res unless $res eq 'OK';

	if ( $location eq 'remote' and ! $result) {
	    $prt_datas{'trt'} = 'NET';
	    $prt_datas{'name'} = $name;
	    $prt_datas{'description'} = $description;
	    $prt_datas{'location'} = $location;
	    $c->stash( title => $title, prt_datas => \%prt_datas );
	    return $c->render( template => 'printers' );
	}
	
	$res = '';
	if ( ! $result ) {
	    $res = $c->new_printer( $name, $description, $location ); 
	    #$remoteName, $address );
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('prt_CREATED_SUCCESSFULLY') . ' ' . $name; 
	    }
	}
    }

    if ( $trt eq 'NET' ) {

	my $name = ($c->param('Name') || '');
        my $description = ($c->param('Description') || '');
        my $location = ($c->param('Location') || '');
	my $remoteName = ($c->param ('RemoteName') || '');
	my $address = ($c->param ('Address') || '');

	$prt_datas{'name'} = $name;
	$prt_datas{'description'} = $description;
	$prt_datas{'location'} = $location;

	# controls
	$res = $c->validate_network( $location, $remoteName, $address);
	$result .= $res unless $res eq 'OK';

	$res = '';
	if ( ! $result ) {
	    $res = $c->new_printer( $name, $description, $location, $remoteName, $address );
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('prt_CREATED_SUCCESSFULLY') . ' ' . $name; 
	    }
	}
    }

    if ( $trt eq 'DEL' ) {
    
	my $printer = ($c->param ('printer') || '');

	if ($printer =~ /^([a-z][a-z0-9]*)$/) {
    	    $printer = $1;
	} else {
    	    $result .= $c->l('prt_ERR_INTERNAL_FAILURE') . ':' . $printer;
	}

	my $rec = $adb->get($printer);
	$result .= $c->l('prt_ERR_INTERNAL_FAILURE') . ':' . $printer unless ($rec);

	$res = '';
	if ( ! $result ) {
	    $res = $c->del_printer( $printer );
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('prt_DELETED_SUCCESSFULLY') . ' ' . $printer; 
	    }
	}
    }

    # common parts

    if ($res ne 'OK') {
	$c->stash( error => $result );
	$c->stash( title => $title, prt_datas => \%prt_datas );
	return $c->render('printers');
    }

    my $message = "'Printers' updates ($trt) DONE";
    $c->app->log->info($message);
    $c->flash( success => $result );
    #$c->flash( error => 'No changes applied !!' );	# for testing purpose

    $c->redirect_to('/printers');

};


sub del_printer {

    my ( $c, $printer ) = @_;

    # Update the db account (1)
    my $rec = $adb->get($printer);
    
    $rec->set_prop('type', 'printer-deleted');
    system ("/sbin/e-smith/signal-event printer-delete $printer") == 0
            or return $c->error('ERR_DELETING');

    $rec->delete();

    return 'OK';

}


sub validate_printer {

    my ($c, $name, $description, $location, $remoteName, $address ) = @_;

    #------------------------------------------------------------
    # Validate parameters and untaint them
    #------------------------------------------------------------

    if ($name =~ /^([a-z][a-z0-9]*)$/)  {
        $name = $1;
    } else  {
        return $c->l('prt_ERR_UNEXPECTED_NAME') . ': ' . $name;
    }

    if ($description =~ /^([\'\w\s]+)$/) {
        $description = $1; 
    } else {
        return $c->l('prt_ERR_UNEXPECTED_DESC') . ': ' . $description;
    }

    if ($location =~ /^(lp[0-9]+|remote|usb\/lp[0-9]+)$/){
        $location = $1;
    } else {
        $location = "lp0";
    }

    #------------------------------------------------------------
    # Looks good. Find out if this printer has been taken
    #------------------------------------------------------------

    my $rec = $adb->get($name);
    my $type;
    if ($rec and ($type = $rec->prop('type'))) {
        return $c->l('prt_ERR_EXISTS') . ' : ' . $name;
    }

    return 'OK';
}


sub validate_network {

    my ($c, $location, $remoteName, $address ) = @_;

    if ($location eq 'remote') {

	my $msg = hostname_or_ip2 ( $c, $address );
	return $msg unless $msg eq 'OK';
	
        if ($address =~ /^([a-zA-Z0-9\.\-]+)$/) {
            $address = $1;
        } else {
            return $c->l('prt_ERR_INVALID_ADDRESS') . ' : ' . $address;
        }

        if ($remoteName =~ /^([^\|]*)$/) {
            $remoteName = $1;
        } else {
            return $c->l('prt_ERR_INVALID_REMOTE_NAME') . ' : ' . $remoteName;
        }
    }

    return 'OK';
}


sub new_printer {

    my ($c, $name, $description, $location, $remoteName, $address ) = @_;

    #------------------------------------------------------------
    # Printer name is available! Update printers database and 
    # signal the create-printer event.
    #------------------------------------------------------------

    my $result = '';

    my $rec = $adb->new_record($name, 
        {type=>'printer',
        Description => $description,
        Address => $address,
        RemoteName => $remoteName,
        Location => $location});

    system ("/sbin/e-smith/signal-event printer-create $name") == 0
            or return $c->error('ERR_CREATING');

    return 'OK',
}


sub hostname_or_ip2 {

    my ($fm, $data) = @_;
    if ($data =~ /^[\d\.]+$/) {
        if (ip_number2($fm, $data) eq "OK")
        {
            return "OK";
        }
        else 
        {
            return $fm->l('prt_MUST_BE_VALID_HOSTNAME_OR_IP');
        }
    }
    elsif ($data =~ /^([a-zA-Z0-9\.\-]+)$/ ) 
    {
        return "OK";
    } 
    else 
    {
        return $fm->l('prt_MUST_BE_VALID_HOSTNAME_OR_IP');
    }
}


sub ip_number2 {
    # from CGI::FormMagick::Validator::ip_number($fm, $data)
    
    my ($fm, $data) = @_;

    return undef unless defined $data;

    return 'FM_IP_NUMBER1' unless $data =~ /^[\d.]+$/;

    my @octets = split /\./, $data;
    my $dots = ($data =~ tr/.//);

    return 'FM_IP_NUMBER2' unless (scalar @octets == 4 and $dots == 3);

    foreach my $octet (@octets) {
        return $fm->l("FM_IP_NUMBER3", {octet => $octet}) if $octet > 255;
    }

    return 'OK';
}


=head2 publicAccess_list

Returns the hash of public access settings for showing in the public
access drop down list.

=cut

sub printerLocation_list {

    my $c = shift;
    return  [[ $c->l('prt_LOCAL_PRINTER_0') => 'lp0'],
	    [ $c->l('prt_LOCAL_PRINTER_1') => 'lp1'],
	    [ $c->l('prt_LOCAL_PRINTER_2') => 'lp2'],
	    [ $c->l('prt_NET_PRINTER') => 'remote' ],
	    [ $c->l('prt_FIRST_USB_PRINTER') => 'usb/lp0'],
	    [ $c->l('prt_SECOND_USB_PRINTER') => 'usb/lp1']];
}


1
