#
#  This file is part of ASPEER::Markdown::Publish.
#
#  This software is copyright (c) 2026 by Andrew Speer <andrew.speer@isolutions.com.au>.
#
#  This is free software; you can redistribute it and/or modify it under
#  the same terms as the Perl 5 programming language system itself.
#
package ASPEER::Markdown::Publish::Constant;

use strict qw(vars);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %Constant);
use warnings;

use Cwd qw(abs_path);

$VERSION='0.001';

%Constant=(
    MARKDOWN_PUBLISH_MODULE      => 'ASPEER::Markdown::Publish::MkDocs',
    MARKDOWN_PUBLISH_CONFIG_FN   => 'doc/project.json',
    MARKDOWN_PUBLISH_OUTPUT_DN   => 'site',
    MARKDOWN_PUBLISH_BRANCH      => 'gh-pages',
    MARKDOWN_PUBLISH_REMOTE      => 'github',
    MARKDOWN_PUBLISH_NPM_VERBOSE => 0,
    MARKDOWN_PUBLISH_HOST        => undef,
    MARKDOWN_PUBLISH_PORT        => undef
);

#  Local preferences sit beside the installed module. Environment variables
#  with the same names take precedence over both the file and built-in values.
#
my $local_fn=abs_path(__FILE__).'.local';
if (-f $local_fn) {
    my $local_hr=do($local_fn);
    die "unable to load local publication constants $local_fn: ".($@ || $! || 'expected a hash reference')."\n"
        unless ref($local_hr) eq 'HASH';
    @Constant{keys(%{$local_hr})}=values(%{$local_hr});
}
foreach my $name (keys(%Constant)) {
    $Constant{$name}=$ENV{$name} if defined($ENV{$name});
}

require Exporter;
@ISA=qw(Exporter);
{
    no warnings qw(once);
    foreach (keys(%Constant)) {${$_}=$Constant{$_}}
}
@EXPORT=map {'$'.$_} keys(%Constant);
@EXPORT_OK=@EXPORT;
%EXPORT_TAGS=(all => [@EXPORT_OK]);

1;
__END__

=begin markdown

# NAME

ASPEER::Markdown::Publish::Constant - publication defaults

# DESCRIPTION

Defines `MARKDOWN_PUBLISH_MODULE`, `MARKDOWN_PUBLISH_CONFIG_FN`,
`MARKDOWN_PUBLISH_OUTPUT_DN`, `MARKDOWN_PUBLISH_BRANCH`,
`MARKDOWN_PUBLISH_REMOTE`, `MARKDOWN_PUBLISH_NPM_VERBOSE`,
`MARKDOWN_PUBLISH_HOST`, and `MARKDOWN_PUBLISH_PORT`. Import individual scalar
constants or use the default export set. The default publisher is
`ASPEER::Markdown::Publish::MkDocs`.

An optional `Constant.pm.local` beside the installed module may return a hash
reference of permanent overrides:

```perl
+{
    MARKDOWN_PUBLISH_MODULE    => 'ASPEER::Markdown::Publish::VitePress',
    MARKDOWN_PUBLISH_OUTPUT_DN => 'public'
}
```

Environment variables named after the constants override both the local file
and built-in values. `MARKDOWN_PUBLISH_MODULE` also overrides a module supplied
through the API, `META_MERGE.x_documentation.publish`, or JSON configuration.
Set `MARKDOWN_PUBLISH_NPM_VERBOSE=1` to show npm installation output. Its default
value is `0`; installation start and completion messages are always shown.
Set `MARKDOWN_PUBLISH_HOST` and `MARKDOWN_PUBLISH_PORT` to control where
`publish_serve` listens. Both default to undefined, leaving each engine's
existing address and port in place. Per-engine `host`, `port`, or MkDocs
`address` settings take precedence.

=end markdown


=head1 NAME

ASPEER::Markdown::Publish::Constant - publication defaults


=head1 DESCRIPTION

Defines C<MARKDOWN_PUBLISH_MODULE>, C<MARKDOWN_PUBLISH_CONFIG_FN>,
C<MARKDOWN_PUBLISH_OUTPUT_DN>, C<MARKDOWN_PUBLISH_BRANCH>,
C<MARKDOWN_PUBLISH_REMOTE>, C<MARKDOWN_PUBLISH_NPM_VERBOSE>,
C<MARKDOWN_PUBLISH_HOST>, and C<MARKDOWN_PUBLISH_PORT>. Import individual scalar
constants or use the default export set. The default publisher is
C<ASPEER::Markdown::Publish::MkDocs>.

An optional C<Constant.pm.local> beside the installed module may return a hash
reference of permanent overrides:


 +{
     MARKDOWN_PUBLISH_MODULE    => 'ASPEER::Markdown::Publish::VitePress',
     MARKDOWN_PUBLISH_OUTPUT_DN => 'public'
 }
Environment variables named after the constants override both the local file
and built-in values. C<MARKDOWN_PUBLISH_MODULE> also overrides a module supplied
through the API, C<META_MERGE.x_documentation.publish>, or JSON configuration.
Set C<MARKDOWN_PUBLISH_NPM_VERBOSE=1> to show npm installation output. Its default
value is C<0>; installation start and completion messages are always shown.
Set C<MARKDOWN_PUBLISH_HOST> and C<MARKDOWN_PUBLISH_PORT> to control where
C<publish_serve> listens. Both default to undefined, leaving each engine's
existing address and port in place. Per-engine C<host>, C<port>, or MkDocs
C<address> settings take precedence.

=cut
