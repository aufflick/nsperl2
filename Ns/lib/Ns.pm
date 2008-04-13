=head1 NAME

Ns - Root package for the AOLServer/nsperl2 perl API.

=head1 SYNOPSIS

In your aolserver tcl config (substituting suitable path and package values):

  ns_section "ns/server/server1/modules"
    ...
    ns_param nsperl2 nsperl2.so

  ns_section "ns/server/server1/module/nsperl2"
    ns_param init_script "/opt/aolserver/nsperl2_startup.pl"
    ns_param init_sub "Foo::server_init"
    ns_param server "server1"

In your C<startup.pl>:

  use Ns;

  # or better would be to 'use' a package with the following:
  package Foo;

  sub server_init { # as per tcl config above
    Ns::register_urls({
        '/ns_style' => {
            perl_sub => 'Foo::ns_style',
            args => [ 'abc', { foo => 123}],
           },
         '/perlish' => {
            perlish => 1,
            perl_sub => 'Foo::perlish_test',
        },
        '/perlish_sub' => {
            perlish => 1,
            perl_sub => sub {
                my $args = shift;
                print "args: " . join(",", @$args);
            },
            args => ['foo', 'bar'],
        },
    });
  }

  sub ns_style {
    my $args = shift;
    my $conn = Ns::conn();

    my $html = "<html><body>" . $conn->headers->iget('USER-AGENT') . "<br><pre>" . Dumper($args) . "</pre></body></html>";

    $conn->return(200, 'text/html', $html);
  }

  sub perlish {
    my $args = shift;

    print Dumper($args);

    print "foo.";
    print "bar.";
  }

For further code examples (of eg. errors and redirects), see the C<test> directory in the nsperl2 distribution.

=head1 DESCRIPTION

The nsperl2 AOLServer module and it's attendant Perl API is designed to allow you to do three different, but complementary,
things:

=over

=item Call Perl functions from tcl

=item Call Tcl functions from Perl

=item Mount Perl functions as aolserver request handlers

=back

Along with the above examples and the C<test> directory, you should also see the API Documentation below and also in L<Ns::Set>,
L<Ns::Conn>, L<Ns::TclApi>.

=head1 A note about return values and arguments

All the different methods to call tcl from perl or perl from tcl do their best to natively convert
arguments and return values.

Perl hashrefs are converted into a single list with alternating key value pairs (ie. [key1 val1 key2 val2]).

Where possible native values are converted - eg. integers and floats are used in preference to string values.

Note that when a tcl return value or argument is only available as a string (and not a native tcl object),
it is not always possible to determine whether it is a string with spaces or a space separated list. You have been
warned!

=cut

package Ns;

use 5.010000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

use Ns::Conn;
use Ns::Set;
use Ns::TclApi;
use Storable;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Ns', $VERSION);

=head2 tcl_api( $tcl_cmd, $global )

Returns an L<Ns::TclApi> object with which you can call a tcl command with different options. eg:

  my $log = Ns::tcl_api('ns_log');

If $global is true, the code will be executed in the global namespace - otherwise the namespace will be whatever namespace the tcl code which invoked your perl code (where the execution takes place) happens to be in.

The object allows you to call a method as the first argument to that tcl command, and any arguments
given to the method are used as the subsequent tcl arguments. eg:

  $log->Notice('this is a notice');

When that interface is not appropriate you can use the method CALL. eg:

  $log->CALL('Notice', 'this is also a notice');

=cut

sub tcl_api {
    my ($tcl_proc_name, $global) = @_;
    CORE::return Ns::TclApi->make($tcl_proc_name, ($global || 0));
}

=head2 tcl_eval( $tcl_string )

Evals the provided tcl string.

=head2 tcl_prepare( $tcl_code_string, $global );

Returns a coderef which, when called, will compile and execute the tcl code. Subsequent calls will execute the already compiled tcl bytecode.

If $global is true, the code will be executed in the global namespace - otherwise the namespace will be whatever namespace the tcl code which invoked your perl code (where the execution takes place) happens to be in.

If you will be repeatedly calling exactly the same tcl, this interface will be faster than using C<tcl_api> or C<tcl_eval> since it allows Tcl to re-use compiled bytecode.

=cut

sub tcl_prepare {
    my ($tcl_code_string, $global) = @_;
    my $tcl_code_obj = _tcl_prepare($tcl_code_string) or die "Unable to prepare Tcl Code object";
    CORE::return sub { _tcl_exec_obj($tcl_code_obj, $global ? 1 : 0) };
}

=head2 conn()

Returns the current AOLServer connection as an L<Ns::Conn> object.

  my $conn = Ns::conn();

=cut

sub conn { Ns::Conn::current(); }

sub perlish_request {
    my $sub = $_[0]->[0];
    my $args = $_[0]->[1];
    my $conn = Ns::Conn::current;
    
    local *STDOUT;
    
    $conn->tie_stdout();

    no strict 'refs';
    my @ret;
    eval { @ret = $sub->($args); };

    my $status;

    if ($@) {
        return $conn->returnerror(500, $@);
    } else {
        $status = shift(@ret) || 200;
    }

    my $content;

    if ($status == 200) {
        my $type = $ret[0] || 'text/html';
        $conn->return($status, $type, $conn->tied_stdout_content);

    } elsif ($status == 401) {
        $conn->returnunauthorized;

    } elsif ($status == 404) {
        $conn->returnnotfound;
        
    } elsif ($status >= 400) {
        $conn->returnadminnotice($status, @ret)

    } elsif ($status >= 300) {
        # need to implement general redirect functionality for any 30x code
        $conn->returnredirect($ret[0]);
    } else {
        die "Status: $status not yet supported by perlish url handler";
    }
}

=head2 register_url

Allows you to register a perl sub as an AOLServer request handler. L<register_urls> is usually more convenient.

=cut

# since we can't SvSHARE coderefs we need to store them in a dispatch table (which will be cloned) and pass around a key
# pity, since it means we can't add subs after startup
our %_dispatch;

sub register_url {
    my $args = shift;

    $args->{http_method} ||= 'GET';

    if (ref $args->{perl_sub} eq 'CODE') {
        $_dispatch{$args->{url}} = $args->{perl_sub};
        delete $args->{perl_sub};
        $args->{dispatch_key} = $args->{url};
    }

    Ns::_register_url($args);
}

=head2 register_urls

Allows you to register many perl request handlers. See the L<SYNOPSIS> and the C<test> directory for concrete examples.

=cut

sub register_urls {
    my $map = shift;

    for my $url (keys %$map) {
        $map->{$url}{url} = $url;
        Ns::register_url($map->{$url});
    }
}

1;
__END__


=head1 BUGS

Hopefully there are no major bugs, but at the moment there are B<certainly> memory leaks. It's
not called an alpha version for nothing!

=head1 SEE ALSO

L<Ns::Conn>, L<Ns::Set>, L<Ns::TclApi>

=head1 AUTHOR

Mark Aufflick, E<lt>mark@aufflick.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Mark Aufflick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
