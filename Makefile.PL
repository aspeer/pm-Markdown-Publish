use 5.008;
use strict;
use warnings;
use version;

use ExtUtils::MakeMaker;


#  Optional documentation helpers provide this distribution's maintenance
#  targets when they are already installed.
#
eval {
    require ASPEER::MakeMaker::Markdown::Pod;
    ASPEER::MakeMaker::Markdown::Pod->import();
    1;
};


#  Main Makefile.PL section
#
my $mm_ver=$ExtUtils::MakeMaker::VERSION;
if ($mm_ver=~/_/) {
    $mm_ver=eval($mm_ver);
    die $@ if $@;
}
my %WriteMakefile=(
    NAME             => 'ASPEER::Markdown::Publish',
    DISTNAME         => 'ASPEER-Markdown-Publish',
    VERSION_FROM     => 'lib/ASPEER/Markdown/Publish.pm',
    ABSTRACT_FROM    => 'lib/ASPEER/Markdown/Publish.pm',
    EXE_FILES        => ['bin/markdown-publish'],
    LICENSE          => 'perl',
    AUTHOR           => 'Andrew Speer <andrew.speer@isolutions.com.au>',
    MIN_PERL_VERSION => '5.008',
    PREREQ_PM        => {
        'Cwd'          => 0,
        'Exporter'     => 0,
        'File::Copy'   => 0,
        'File::Find'   => 0,
        'File::Path'   => 0,
        'File::Spec'   => 0,
        'File::Temp'   => 0,
        'Getopt::Long' => 0,
        'IPC::Run3'    => 0,
        'JSON::PP'     => 0,
        'strict'       => 0,
        'vars'         => 0,
        'warnings'     => 0,
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'version'             => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    },
    META_MERGE => {
        'meta-spec' => {version => 2},
        prereqs     => {
            configure => {
                suggests => {
                    'ASPEER::MakeMaker::Markdown::Pod' => '0.012',
                },
            },
        },
        resources   => {
            bugtracker => {
                web => 'https://gitea.isolutions.com.au/aspeer/pm-ASPEER-Markdown-Publish/issues',
            },
            homepage   => 'https://gitea.isolutions.com.au/aspeer/pm-ASPEER-Markdown-Publish',
            repository => {
                type => 'git',
                url  => 'https://gitea.isolutions.com.au/aspeer/pm-ASPEER-Markdown-Publish.git',
                web  => 'https://gitea.isolutions.com.au/aspeer/pm-ASPEER-Markdown-Publish',
            },
        },
    },
    depend => {Makefile => '$(VERSION_FROM)'},
    dist   => {COMPRESS => 'gzip -9f', SUFFIX => '.gz'},
);
my %MM_Compat=(
    '6.31' => [qw(LICENSE)],
    '6.46' => [qw(META_MERGE)],
    '6.48' => [qw(MIN_PERL_VERSION)],
    '6.52' => [qw(CONFIGURE_REQUIRES)],
    '6.64' => [qw(TEST_REQUIRES)],
);
while (my ($mm_ver_test, $name_ar)=each(%MM_Compat)) {
    if (version->parse($mm_ver) < version->parse($mm_ver_test)) {
        delete(@WriteMakefile{@{$name_ar}});
    }
}
WriteMakefile(%WriteMakefile);
