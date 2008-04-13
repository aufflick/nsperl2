use 5.010000;
use ExtUtils::MakeMaker;

die("NSINST and NSSRC env variables required. see ../INSTALL.txt") unless (
    $ENV{NSINST} &&
    $ENV{NSSRC} &&
    -d $ENV{NSINST} &&
    -d $ENV{NSSRC}
   );

WriteMakefile(
    NAME              => 'Ns::Set',
    VERSION_FROM      => 'lib/Ns/Set.pm',
    PREREQ_PM         => {},
    ABSTRACT_FROM     => 'lib/Ns/Set.pm',
    AUTHOR            => 'Mark Aufflick <mark@aufflick.com>',
    LIBS              => [],
    DEFINE            => '',
    INC               => "-I. -I$ENV{NSSRC}/nsd -I$ENV{NSINST}/include",
    TYPEMAPS		=> ['../Ns/typemap'],
);
