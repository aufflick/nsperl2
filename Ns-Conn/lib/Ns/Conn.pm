=head1 NAME

Ns::Conn - Object representation for ns_conn

=head1 SYNOPSIS

In any perl called from AOLServer/nsperl2 the following two lines are equivalent to get the
current connection's conn object. C<undef> if we are in a connectionless environment such
as timed procs.

  $conn = Ns::conn();
  $conn = Ns::Conn::current();

There is no implementation of C<isconnected> - simple test to see if C<Ns::conn()> returns
a conn object or not.

=head1 DESCRIPTION

You will find it instructive to consider the AOLServer Tcl API documentation alongside this document.
Function names and arguments correlate fairly closely.

=head1 Object Methods

=cut

package Ns::Conn;

use 5.010000;
use strict;
use warnings;



our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Ns::Conn', $VERSION);

use Ns::Conn::TieStdout;

sub tie_stdout {
    tie *STDOUT, 'Ns::Conn::TieStdout';
}

sub clear_tied_stdout {
    (tied *STDOUT)->clear;
}

sub tied_stdout_content {
    (tied *STDOUT)->content;
}

sub current {
    return $Ns::Conn::__current_conn;
}

=head2 outputheaders

Returns an L<Ns::Set> object containing the output headers.

=cut

sub outputheaders {
    my $self = shift;

    my $set = $self->OutputHeaders;
    $set->_persist(1); # don't want Perl API to free the set
    return $set;
}

1;
__END__


=head2 authpassword

=head2 authuser

=head2 close

=head2 contentlength

=head2 driver

=head2 form

Returns an instance of L<Ns::Set> with the same set you would get from C<ns_conn form>.

=head2 query

=head2 headers

Returns an instance of L<Ns::Set> with the same set you would get from C<ns_conn headers>.

=head2 host

=head2 location

=head2 method

=head2 peeraddr

=head2 port

=head2 protocol

=head2 request

=head2 url

=head2 urlc

=head2 version

=head2 return( $status, $mime_type, $content )

Eg:

  $conn->return(200, 'text/plain', "hello world");

=head2 returnredirect( $location )

=head2 returnerror( $status, $message )

=head2 returnunauthorized

=head2 returnnotfound

=head2 returnbadrequest( $message )

=head2 returnadminnotice( $status, $message, $long_message )

Note that the long message is optional.

=head2 returnnotice( $status, $message, $long_message )

=head2 returnforbidden

=head2 returnfile( $status, $type, $filename )

Note that the long message is optional.



=head1 TODO

=over

=item only a few methods are represented in the test cases

=item complete documentation

=item C<urlv> is unimplemented.

=back

=head1 SEE ALSO

L<Ns>, L<Ns::Set>

=head1 AUTHOR

Mark Aufflick, E<lt>mark@aufflick.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Mark Aufflick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
