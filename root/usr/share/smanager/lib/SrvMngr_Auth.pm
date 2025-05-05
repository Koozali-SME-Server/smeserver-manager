# Optimized SrvMngr_Auth module using stash caching and Exporter

package SrvMngr_Auth;

use strict;
use warnings;
use Exporter qw(import); # Import the Exporter module
use esmith::AccountsDB;

# Define functions to be exported upon request
our @EXPORT_OK = qw(check_admin_access load_user_auth_info has_panel_access get_panel_from_path);

# Helper function to extract panel name from path
sub get_panel_from_path {
    my ($path) = @_;
    
    if ($path =~ m{^/([^/]+)}) {
        return $1;
    }
    
    return ''; # Return empty string if no panel found
}

# Load user authentication info and cache it in the stash
sub load_user_auth_info {
    my ($c) = @_;
    
    # Check if auth info is already cached in the stash
    return if exists $c->stash->{auth_info};
    
    my %auth_info = (
        username => '', # Initialize username
        is_admin => 0,
        allowed_panels => [],
    );
    
    # Get username from session
    $auth_info{username} = $c->session->{username} || ''; # Provide default empty string
    
    # Check if user is admin
    $auth_info{is_admin} = $c->is_admin || 0;
    
    # If not admin, get allowed panels
    if (!$auth_info{is_admin} && $auth_info{username}) {
        my $accountsdb = esmith::AccountsDB->open_ro();
        if ($accountsdb) {
            my $user_rec = $accountsdb->get($auth_info{username});
            # Check if the property exists before trying to get its value
            if (defined $user_rec && $user_rec->prop('AdminPanels')) {
                # Get comma-separated list of allowed admin panels
                my $admin_panels = $user_rec->prop('AdminPanels');
                $auth_info{allowed_panels} = [split(/,/, $admin_panels)];
            }
        }
    }
    
    # Store the calculated info in the stash
    $c->stash(auth_info => \%auth_info);
}

# Check if a user has access to a specific panel (uses cached info)
sub has_panel_access {
    my ($c, $panel) = @_;
    
    # Ensure auth info is loaded
    load_user_auth_info($c);
    
    my $auth_info = $c->stash->{auth_info};
    
    # Check if requested panel is in allowed panels
    foreach my $allowed_panel (@{$auth_info->{allowed_panels}}) {
		return 1 if lc($panel) eq lc($allowed_panel) 
         || lc(substr($panel, 0, length($allowed_panel))) eq lc($allowed_panel);
    }
    
    return 0;
}

# Main function to check admin access (uses cached info)
sub check_admin_access {
    my ($c) = @_;
    
    # Ensure auth info is loaded
    load_user_auth_info($c);
    
    my $auth_info = $c->stash->{auth_info};
    
    # First check if user is admin
    return 1 if $auth_info->{is_admin};
    
    # If not admin, check if they have access to the specific panel
    my $current_path = $c->req->url->path;
    my $requested_panel = $current_path;  
    return 0 unless $requested_panel;
    
    # Check if user has access to this panel using the cached info
    return has_panel_access($c, $requested_panel);
}

1; # Return true value for module loading