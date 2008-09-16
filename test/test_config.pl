package Ns::Test;

use strict;
use Data::Dumper;

# call these first two subs in adp test files
sub multiply {
    my ($num1, $num2) = @_;
    warn Dumper \@_;

    if (wantarray) {
        die "this test was expecting to be called in scalar context - ie perl::call -scalar";
    }
    
    return $num1 * $num2;
}

sub foo_times_hash_list {
    my $times = shift;

    if (!wantarray) {
        die "this test was expecting to be called in list context - ie no -scalar option passed to perl::call";
    }

    return { the_list => [map {'foo'} 1..$times] };
}

# use this in a perlish mount
sub dump {
    print Data::Dumper::Dumper(@_);
}

our $config = [

    {
        uri => 'multiply.adp',
        mount_perl => 0,
        match => qr/\n15\n/,
    },

     {
         uri => 'hash_list.adp',
         mount_perl => 0,
         match => qr/\n{the_list {foo foo foo}}\n/,
     },

    {
        uri => 'perlish_package_sub',
        perlish => 1,
        perl_sub => 'Ns::Test::dump',
        args => { the_args => [1, 2, 3]},
        match => qr/{\s*'the_args' => \[\s*1,\s*2,\s*3.*\].*}/s,
    },

    {
        uri => 'perlish_dump',
        perlish => 1,
        perl_sub => sub {print Data::Dumper::Dumper(@_)},
        args => { the_args => [1, 2, 3]},
        match => qr/{\s*'the_args' => \[\s*1,\s*2,\s*3.*\].*}/s,
    },

    {
        uri => 'redirect',
        perl_sub => sub { Ns::conn->returnredirect('/perlish_dump') },
        match => qr/{\s*'the_args' => \[\s*1,\s*2,\s*3.*\].*}/s,
    },

    {
        uri => 'perlish_redirect',
        perlish => 1,
        perl_sub => sub { return (302, "/perlish_dump") },
        match => qr/{\s*'the_args' => \[\s*1,\s*2,\s*3.*\].*}/s,
    },

    {
        uri => 'perlish_static',
        perlish => 1,
        perl_sub => sub { print "static test"},
        match => qr/\nstatic test\n/,
    },

    {
        uri => 'perlish_die',
        perlish => 1,
        perl_sub => sub { die "dead" },
        match => qr/dead/,
        response_code => 500,
    },

    {
        uri => 'perlish_error',
        perlish => 1,
        perl_sub => sub { return (405, "Doh.") },
        match => qr!<TITLE>Doh.</TITLE>.*<H2>Doh.</H2>!s,
        response_code => 405,
    },

    {
        uri => 'returnerror',
        perl_sub => sub {Ns::Conn->current->returnerror(409, "When web pages go bad")},
        match => qr!<TITLE>Request Error</TITLE>.*When web pages go bad!s,
        response_code => 409,
    },

    {
        uri => 'ns_return',
        perl_sub => sub {
            my $conn = Ns::conn();
            my $html = "<html><body>content</body></html>";
            $conn->return(200, 'text/html', $html);
        },
        match => qr!<html><body>content</body></html>!,
    },

    {
        uri => 'conn_headers',
        perlish => 1,
        perl_sub => sub { print Ns::conn()->headers->iget('USER-AGENT') },
        match => qr/libwww-perl/,
    },

    # need some multi-argument ones of these...
    {
        uri => 'tcl_api',
        perlish => 1,
        perl_sub => sub { my $nsinfo = Ns::tcl_api('ns_info'); print $nsinfo->version; },
        match => qr/4\.5/,
    },

    {
        uri => 'tcl_api_call',
        perlish => 1,
        perl_sub => sub { my $nsinfo = Ns::tcl_api('ns_info'); print $nsinfo->CALL('version'); },
        match => qr/4\.5/,
    },

    {
        uri => 'tcl_eval',
        perlish => 1,
        perl_sub => sub { print Ns::tcl_eval('ns_info version') },
        match => qr/4\.5/,
    },

    {
        uri => 'tcl_prepare',
        perlish => 1,
        perl_sub => sub {
            my $nsinfo_coderef = Ns::tcl_prepare('ns_info version');
            die "tcl_prepare didn't retur a coderef" unless ref $nsinfo_coderef eq 'CODE';
            print &$nsinfo_coderef;
        },
        match => qr/4\.5/,
    },

    {
        uri => 'conn_port',
        perlish => 1,
        perl_sub => sub { print Ns::conn->port },
        match => qr/8787/,
    },

    {
        uri => 'query_args',
        perlish => 1,
        query_args => 'foo=bar&flubber=123',
        perl_sub => sub {
            my $form = Ns::conn->form->as_hashref;
            die "form->as_hashref didn't return a hashref" unless ref $form eq 'HASH';
            print join(',', $form->{foo}, $form->{flubber});
        },
        match => qr/bar,123/,
    },

    # TODO: need fuller tests of Ns::Conn and Ns::Set (eg. get_by_setId and friends...)
];

1;
