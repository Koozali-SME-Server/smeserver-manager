package SrvMngr::Plugin::CSRFProtectBuiltin;

use strict;
use warnings;
use Carp qw(croak);

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream qw(b);

our $VERSION = '0.02';

sub register {
    my ($self, $app, $conf) = @_;
    $conf ||= {};

    my $on_error = (ref($conf->{on_error}) eq 'CODE')
      ? $conf->{on_error}
      : sub { shift->render(status => 403, text => 'Forbidden!') };

    my $original_form_for = delete $app->renderer->helpers->{form_for};
    croak qq{Cannot find helper "form_for". Please load plugin "TagHelpers" before}
      unless $original_form_for;

    $app->helper(
        form_for => sub {
            my $c = shift;

            if (defined $_[-1] && ref($_[-1]) eq 'CODE') {
                my $cb = $_[-1];
                $_[-1] = sub {
                    $c->csrf_field . $cb->();
                };
            }

            return $original_form_for->($c, @_);
        }
    );

    $app->helper(csrftoken => sub { shift->csrf_token });

    $app->helper(
        is_valid_csrftoken => sub {
            my $c = shift;
            my $v = $c->validation;
            $v->csrf_protect;
            return $v->has_error('csrf_token') ? 0 : 1;
        }
    );

    $app->helper(
        jquery_ajax_csrf_protection => sub {
            my $c  = shift;
            my $js = '<meta name="csrf_token" content="' . $c->csrf_token . '"/>';
            $js .= q{<script type="text/javascript">};
            $js .= q{jQuery(document).ajaxSend(function(e, xhr, options) { };
            $js .= q{var token = jQuery("meta[name='csrf_token']").attr("content"); };
            $js .= q{xhr.setRequestHeader("X-CSRF-Token", token); };
            $js .= q{ });</script>};
            return b($js);
        }
    );

    $app->hook(
        before_routes => sub {
            my ($c) = @_;

            return 1 if $c->req->method =~ m/^(?:GET|HEAD|OPTIONS)$/;

            my $v = $c->validation;
            $v->csrf_protect;

            if ($v->has_error('csrf_token')) {
                my $path = $c->tx->req->url->to_abs->to_string;
                $c->app->log->debug(
                    "CSRFProtectBuiltin: Wrong CSRF token for [$path]!"
                );
                $on_error->($c);
                return;
            }

            return 1;
        }
    );

    return $self;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::CSRFProtectBuiltin - CSRF protection plugin using Mojolicious built-in CSRF support

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('TagHelpers');
    $self->plugin('CSRFProtectBuiltin');

    # Mojolicious::Lite
    plugin 'TagHelpers';
    plugin 'CSRFProtectBuiltin';

    # Existing block-style form_for forms automatically receive a CSRF field
    %= form_for '/login' => (method => 'POST') => begin
      %= text_field 'Username'
      %= password_field 'Password'
      %= submit_button 'Sign in'
    % end

    # Optional jQuery AJAX support
    <%= jquery_ajax_csrf_protection %>

    # Custom error handling
    $self->plugin('CSRFProtectBuiltin' => {
      on_error => sub {
        my $c = shift;
        $c->render(template => 'error_403', status => 403);
      }
    });

=head1 DESCRIPTION

L<Mojolicious::Plugin::CSRFProtectBuiltin> adds CSRF protection to
applications that already make heavy use of C<form_for>, while relying on
Mojolicious built-in CSRF helpers and validation.

It does the following:

=over 4

=item 1.

Wraps the C<form_for> helper so block-style forms automatically get a
C<csrf_field> inserted at the start of the form body.

=item 2.

Provides a C<jquery_ajax_csrf_protection> helper that emits a meta tag with
the current CSRF token and JavaScript to attach that token as an
C<X-CSRF-Token> header on jQuery AJAX requests.

=item 3.

Rejects non C<GET>, C<HEAD>, and C<OPTIONS> requests when
C<csrf_protect> validation fails.

=back

This plugin uses Mojolicious built-in C<csrf_token>, C<csrf_field>, and
C<csrf_protect> support rather than implementing its own token generation and
comparison logic.

=head1 CONFIGURATION

=head2 on_error

Optional callback used when CSRF validation fails.

If omitted, the plugin returns a simple C<403 Forbidden!> response.

Example:

    $self->plugin('CSRFProtectBuiltin' => {
      on_error => sub {
        my $c = shift;
        $c->render(template => 'error_403', status => 403);
      }
    });

=head1 HELPERS

=head2 form_for

This plugin replaces the existing C<form_for> helper and prepends
C<csrf_field> to block-style forms.

So this:

    %= form_for '/save' => (method => 'POST') => begin
      %= text_field 'name'
      %= submit_button 'Save'
    % end

behaves as if you had written:

    %= form_for '/save' => (method => 'POST') => begin
      %= csrf_field
      %= text_field 'name'
      %= submit_button 'Save'
    % end

=head2 csrftoken

Returns the current Mojolicious CSRF token.

In templates:

    <%= csrftoken %>

In controllers:

    my $token = $self->csrftoken;

This is a compatibility helper for older code that expects a helper called
C<csrftoken>.

=head2 is_valid_csrftoken

Checks whether the current request contains a valid CSRF token.

Returns C<1> for valid and C<0> for invalid.

Example:

    return $c->render(status => 403, text => 'Forbidden')
      unless $c->is_valid_csrftoken;

This is primarily a compatibility helper for code that previously used the
older plugin API.

=head2 jquery_ajax_csrf_protection

Emits a meta tag containing the current CSRF token and a jQuery
C<ajaxSend> handler that adds the token as an C<X-CSRF-Token> header to AJAX
requests.

Add it in the page head or layout:

    <%= jquery_ajax_csrf_protection %>

This helper is intended for jQuery-based AJAX only. If your application uses
C<fetch>, Axios, or raw C<XMLHttpRequest>, you will need an equivalent custom
JavaScript snippet.

=head1 HOW VALIDATION WORKS

For non C<GET>, C<HEAD>, and C<OPTIONS> requests, the plugin calls:

    $c->validation->csrf_protect

If validation fails, Mojolicious records an error on C<csrf_token>, and the
plugin invokes the configured C<on_error> callback.

=head1 GET REQUESTS

This plugin does not automatically protect ordinary C<GET> requests.

That is intentional, because navigation links and menu entries are normally
C<GET>, while CSRF protection is generally intended for state-changing
requests such as C<POST>, C<PUT>, C<PATCH>, and C<DELETE>.

If you have a state-changing C<GET> route, you should strongly consider
changing it to C<POST>. If that is not possible, protect it manually.

=head1 LIMITATIONS

=over 4

=item *

Only block-style C<form_for ... begin ... end> usage is automatically
augmented with C<csrf_field>.

=item *

Raw literal C<E<lt>formE<gt>> tags are not modified.

=item *

The AJAX helper supports jQuery only.

=back

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin::TagHelpers>,
L<Mojolicious::Plugin::DefaultHelpers>,
L<Mojolicious::Validator::Validation>,
L<Mojolicious::Plugin::CSRFProtect>,
L<Mojolicious::Plugin::CSRFDefender>

=head1 AUTHOR

Adapted for Mojolicious built-in CSRF support.

=head1 LICENSE

Same terms as Perl itself.