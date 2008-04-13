package Ns::Conn::TieStdout;

use strict;
use warnings;

sub TIEHANDLE { my $self = ""; bless \$self, shift }

sub WRITE {
    my $self = shift;
    my($buf,$len,$offset) = @_;
    # can't do much about offset...
    $$self .= $buf;
}

sub PRINT {
    my $self = shift; warn($_) for @_;
    $$self .= $_ for @_;
}

sub PRINTF {
    my $self = shift;
    $$self .= sprintf(@_);
}

sub READ { warn "Not expecting READ in " . __PACKAGE__; }
sub READLINE { warn "Not expecting READLINE in " . __PACKAGE__; }
sub GETC { warn "Not expecting GETC in " . __PACKAGE__; }
sub CLOSE { warn "Not expecting CLOSE in " . __PACKAGE__; }

sub content {
    return ${$_[0]};
}

sub clear {
    ${$_[0]} = "";
}

1;
