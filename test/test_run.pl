require 'test_config.pl';

use Test::More 'no_plan';

use strict;
use warnings;
use LWP;

# TODO: better arg handling
my $valgrind;
my $delay = 5;
if (grep {/^--valgrind$/} @ARGV) {
    $valgrind = 1;
    $delay *= 10;
}

my $ua = LWP::UserAgent->new;

sub test_get {
    my ($url, $match, $response_code, $query_args) = @_;

    $response_code ||= 200;

    $url .= "?$query_args" if $query_args;

    diag($url);
    my $req = HTTP::Request->new( GET => $url );
    my $resp = $ua->request($req);
    is($resp->code, $response_code, "Response is $response_code");
    like($resp->as_string, $match, "Content matches");
}

sub nsd_err_log { "/tmp/nsperl2_test_nsd_stderr." . shift }
sub nsd_log { "/tmp/nsperl2_test_nsd_stdout." . shift }

sub fork_nsd {
    if (my $pid = fork) {
        # parent
        return $pid;
    }

    # remove chance of old log causing an issue in the case of getting a previously used pid
    unlink nsd_err_log($$) if (-f nsd_err_log($$));
    unlink nsd_log($$) if (-f nsd_log($$));

    open STDOUT, ">" . nsd_log($$);
    open STDERR, ">" . nsd_err_log($$);

    if (!$valgrind) {
        exec "$ENV{NSINST}/bin/nsd", "-ft", "$ENV{NSPERL2SRC}/test/nsperl2_test_nsd.tcl";
    } else {
        exec "valgrind", "--leak-check=yes", "$ENV{NSINST}/bin/nsd", "-ft", "$ENV{NSPERL2SRC}/test/nsperl2_test_nsd.tcl";
    }
}

sub file_not_like { my $msg = pop; ok(_file_like(@_, 1) == 0, $msg); }
sub file_like { my $msg = pop; ok(_file_like(@_, 0) == 1, $msg); }
sub _file_like {
    my ($file, $match, $echo) = @_;

    my $fh;
    if ( ! open($fh, $file) ) {
        diag($!);
        return -1;
    }

    while (!eof $fh) {
        $_ = <$fh>;
        if (/$match/) {
            if ($echo) {
                chomp $_;
                diag($_);
            }
            return 1;
        }
    }

    return 0;
}

$Ns::Test::config || die "No test config";
my $conf = $Ns::Test::config;
my $nsd_pid = fork_nsd();

# give nsd a few seconds to startup and read config etc.
diag("sleeping a bit for nsd to startup");
sleep($delay);

if ( ! file_like(nsd_err_log($nsd_pid), qr/Notice: nssock: listening on 127.0.0.1:8787/, "nsd started & listening. err log: " . nsd_err_log($nsd_pid)) ) {
    system("kill $nsd_pid"); # make sure child is dead
    die "server didn't start correctly - can't continue";
}

while (my $args = shift @$conf) {
    my $uri = $args->{uri};
    my $url = "http://127.0.0.1:8787/$uri";

    test_get($url, $args->{match}, $args->{response_code}, $args->{query_args});
}

ok(system("kill $nsd_pid") == 0, "killed nsd");

diag("sleeping for a bit for nsd to shutdown");
sleep($delay);

file_like(nsd_err_log($nsd_pid), qr!Notice: nsmain: AOLserver/4.5.0 exiting!, 'nsd shutdown');
file_not_like(nsd_err_log($nsd_pid), qr/^[^=].*(?:error:|panic|fatal)/, 'nsd log error check'); # ^= is to avoid flagging valgrind output as an error

if ($valgrind) {
    diag('valgrind summary:');
    diag(' ');
    open my $v, nsd_err_log($nsd_pid) or die $!;
    while (<$v>) {
	chomp;
	diag($_) if /SUMMARY/.../== $/;
    }
    diag(' ');
    diag('full valgrind output in error log: ' . nsd_err_log($nsd_pid));
}

