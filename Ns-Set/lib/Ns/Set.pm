=head1 NAME

Ns::Set - Object representation of an ns_set

=head1 SYNOPSIS

You will mostly be having an Ns::Set object passed to you by, eg.,
an L<Ns::Conn> - in that case just call the instance methods.

You can, though, also create an Ns::Set object and even register it with
the tcl layer if you need to pass some tcl code a C<setId>. Conversely you
can also access a registered set given a C<setId>.

  my $set = Ns::Set::new({ name => 'foo', }); # ns sets have optional names
  my $setId = $set->register();
  my $other_set = Ns::Set::get_by_setId($id); # a set id you were passed by some tcl code


=head1 Class Methods

=cut

package Ns::Set;

use 5.010000;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Ns::Set', $VERSION);

=head2 new

=head2 create

C<new> and C<create> are synonyms.

=cut

sub create { &new }

=head2 get_by_setId($id)

See SYNOPSIS for example.

=head1 Instance Methods

=head2 register($persist)

Returns a string representing a setId as per the tcl C<ns_set> interface. 

If persist is C<"perl"> then the set will not be freed when the perl code
exits and will be available for the rest of the connection. If persist is
C<"tcl"> then the set will never be freed automatically. You are responsible
for freeing it yourself.

Note that this functionality relies on reaching into private api's of nsd
and I'm not entirely sure I have it working properly. There are almost certainly
memory leaks if not worse.

You have been warned!

=cut

sub register {
    my $self = shift;
    my $persist = shift || "";
    $self->_register($persist);
}

=head2 keys_counts

The confusing double plural in the name of this method is due to the fact that ns
sets can have more than one entry with the same key.

The method returns a hashref, where the keys are the keys of the ns set, and the
values are the counts of their respective key. Eg. if you had an ns set with
one entry for key foo and two entries for key bar, the return of this method would be:

  {
    foo => 1,
    bar => 2,
  }

=cut

sub keys_counts {
    my $self = shift;

    my %keys;
    if (defined $self->last) {
        for (0..$self->last) {

            $keys{ $self->key($_) } ||= 0;
            $keys{ $self->key($_) }++;
        }
    }

    \%keys;
}

=head2 keys

Returns a list of the distinct keys in the set.

=cut

sub keys {
    keys %{ shift->keys_counts };
}

=head2 values

Returns a list of all values in the set

=cut

sub values {
    my $self = shift;

    map { $self->Value($_) } 0..$self->Last;
}

=head2 as_hashref

This returns a hasref representation of the data in the ns set. Note that since
perl hashes can only contain a single entry per key, only the first entry of any
duplicated keys in the ns set is represented. This is perl the functionality
of C<Ns_SetGet>.

=cut

sub as_hashref {
    my $self = shift;

    my $ret = $self->keys_counts;
    $ret->{$_} = $self->get($_) for CORE::keys %$ret;

    $ret;
}

=head2 exists($key)

Does the key exist in the set?

=cut

sub exists {
    my $self = shift;
    $self->find(shift) == -1 ? 0 : 1;
}

=head2 iexists($key)

Case insensitive version of exists.

=cut

sub iexists {
    my $self = shift;
    $self->ifind(shift) == -1 ? 0 : 1;
}

=head2 cput($key, $value)

TODO: confirm this behaviour against C API

=cut

sub cput {
    my ($self, $key, $value) = @_;

    return -1 if $self->exists($key);
    return $self->put($key, $value);
}

=head2 icput

=cut

sub icput {
    my ($self, $key, $value) = @_;

    return -1 if $self->iexists($key);
    return $self->put($key, $value);
}


1;
__END__

=head2 isnull($field)

=head2 size

=head2 name

=head2 key($idx)

=head2 value($idx)

=head2 last

The last (integer) index in the set.

=head2 copy

Returns a new Ns::Set object representing a copied ns set structure.

=head2 delete

Frees the set.

=head2 delkey($key)

=head idelkey($key)

=head2 find($key)

=head2 ifind($key)

=head2 get($key)

=head2 iget($key)

=head2 unique($key)

=head2 iunique($key)

=head2 merge($set)

Takes another instance of Ns::Set as it's argument.

=head2 move($set)

Takes another instance of Ns::Set as it's argument.

Moves from self, to the given set.

=head2 print

=head2 put($key, $value)

=head2 put_value($index, $value)

=head2 truncate

=head2 update($key, $value)

=head1 TODO

=over

=item many methods are not represented in the test cases, especially the setId related functionality

=item the logic for registered/persistent sets doesn't seem quite right

=head1 SEE ALSO

L<Ns::Set>, L<Ns::Conn>


=head1 AUTHOR

Mark Aufflick, E<lt>mark@aufflick.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Mark Aufflick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
