use strict;
use warnings;

package Ns::Test;

use Data::Dumper;

# these should be hard-loaded in interp
use Ns;
use Storable;
our $config;

require "$ENV{NSPERL2SRC}/test/test_config.pl";

sub server_init {

    require "$ENV{NSPERL2SRC}/test/test_config.pl";

    my $config = $Ns::Test::config;

    for my $test (@$config) {
        next if exists $test->{mount_perl} && !$test->{mount_perl};
        
        Ns::register_url({
            url => "/" . $test->{uri},
            perl_sub => $test->{perl_sub},
            perlish => $test->{perlish},
            args => $test->{args},
           });
    }
}
