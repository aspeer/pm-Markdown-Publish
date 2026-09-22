#
#  This file is part of ASPEER::Markdown::Publish.
#
#  This software is copyright (c) 2026 by Andrew Speer
#  <andrew.speer@isolutions.com.au>.
#
#  This is free software; you can redistribute it and/or modify it under
#  the same terms as the Perl 5 programming language system itself.
#
package ASPEER::Markdown::Publish::Starlight;


#  Compiler pragma and package variables
#
use strict qw(vars);
use vars qw($VERSION @ISA);
use warnings;


#  Parent and supporting packages
#
use ASPEER::Markdown::Publish ();
use ASPEER::Markdown::Publish::Constant;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use JSON::PP qw(encode_json);


#  Inheritance and version information
#
@ISA=qw(ASPEER::Markdown::Publish);
$VERSION='0.001';


#  Done
#
1;


#======================================================================================================================


sub prepare {

    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $navigation_ar=$self->navigation($docs_dn, $pages_ar);
    my $site_dn=File::Spec->catdir($temporary_dn, 'starlight');
    my $site_docs_dn=File::Spec->catdir($site_dn, 'src', 'content', 'docs');
    make_path($site_docs_dn);
    $self->copy_tree($docs_dn, $site_docs_dn);
    $self->normalize_node_markdown($site_docs_dn);
    my $astro_version=$self->option('astro_version', 'latest');
    my $starlight_version=$self->option('starlight_version', 'latest');
    my $package_hr={
        type         => 'module',
        scripts      => {build => 'astro build', start => 'astro dev'},
        dependencies => {astro => $astro_version, '@astrojs/starlight' => $starlight_version}
    };
    $self->write_file(File::Spec->catfile($site_dn, 'package.json'), encode_json($package_hr));
    my $config_fn=$self->option('config', undef);
    my $prepared_config_fn;
    if (defined($config_fn) && length($config_fn)) {
        die "Starlight configuration not found: $config_fn\n" unless -f $config_fn;
        $prepared_config_fn=abs_path($config_fn);
    }
    else {
        my @items=map {
            #  Astro normalizes content collection slugs to lower case.
            my $slug=lc($_->{'id'});
            "      { label: ".encode_json($_->{'title'}).
                ", slug: ".encode_json($slug)." }"
        } @{$navigation_ar};
        my $config="import { defineConfig } from 'astro/config';\n".
            "import starlight from '\@astrojs/starlight';\n\n".
            "export default defineConfig({\n  integrations: [starlight({\n    title: ".
            encode_json($self->option('name', 'Documentation')).
            ",\n    sidebar: [{ label: 'Docs', items: [\n".
            join(",\n", @items)."\n    ] }]\n  })]\n});\n";
        $prepared_config_fn=File::Spec->catfile($site_dn, 'astro.config.mjs');
        $self->write_file($prepared_config_fn, $config);
    }
    $self->write_file(File::Spec->catfile($site_dn, 'src', 'content.config.ts'),
        "import { defineCollection } from 'astro:content';\n".
        "import { glob } from 'astro/loaders';\n".
        "import { docsSchema } from '\@astrojs/starlight/schema';\n\n".
        "export const collections = { docs: defineCollection({ loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/docs' }), schema: docsSchema() }) };\n");
    return ($temporary_dn, $site_dn, $prepared_config_fn);

}


sub normalize_backend_markdown {

    my ($self, $fn, $markdown)=@_;
    $markdown=$self->title_frontmatter($fn, $markdown);
    return $self->starlight_title_heading($markdown);

}


sub heading_anchor_required {

    return 1;

}


sub admonition_type {

    my ($self, $kind)=@_;
    my %map=(note => 'note', tip => 'tip', warning => 'caution',
        important => 'caution', caution => 'caution');
    return $map{$kind} || $kind;

}


sub starlight_title_heading {

    my ($self, $markdown)=@_;
    my @output;
    my ($fence, $length, $frontmatter, $removed)=('', 0, 0, 0);
    my $index=0;
    foreach my $line (split(/(?<=\n)/, $markdown)) {
        if (!$index && $line=~/^---[ \t]*\r?\n?$/) {
            $frontmatter=1;
            push(@output, $line);
            $index++;
            next;
        }
        if ($frontmatter) {
            $frontmatter=0 if $line=~/^---[ \t]*\r?\n?$/;
            push(@output, $line);
            $index++;
            next;
        }
        if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1);
            $length=length($1);
        }
        elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
            $fence='';
        }
        elsif (!$fence && !$removed && $line=~/^#\s+(.+?)[ \t]*(\r?\n)?$/) {
            my ($title, $newline)=($1, $2 || '');
            my ($id)=$title=~/\s+\{#([\w.-]+)(?:\s+[^}]*)?\}\s*$/;
            unless (defined($id)) {
                $id=lc($title);
                $id=~s/[^a-z0-9]+/-/g;
                $id=~s/^-|-$//g;
            }
            push(@output, "<a id=\"$id\"></a>$newline") if length($id);
            $removed=1;
            $index++;
            next;
        }
        push(@output, $line);
        $index++;
    }
    return join('', @output);

}


sub build {

    my ($self)=@_;
    my $output_dn=File::Spec->rel2abs($self->option('output', $MARKDOWN_PUBLISH_OUTPUT_DN));
    my (undef, $site_dn, $config_fn)=$self->prepare();
    my $config_arg=File::Spec->abs2rel($config_fn, $site_dn);
    $config_arg=$config_fn if $config_arg=~m{^\.\.[/\\]};
    $self->npm_install($site_dn);
    $self->system_in_dir($site_dn, $self->option('npm', 'npm'),
        'run', 'build', '--', '--config', $config_arg, '--outDir', $output_dn);
    return $output_dn;

}


sub serve {

    my ($self)=@_;
    my (undef, $site_dn, $config_fn)=$self->prepare();
    my $config_arg=File::Spec->abs2rel($config_fn, $site_dn);
    $config_arg=$config_fn if $config_arg=~m{^\.\.[/\\]};
    $self->npm_install($site_dn);
    local $ENV{'ASTRO_DEV_BACKGROUND'}=0;
    return $self->system_in_dir($site_dn, $self->option('npm', 'npm'),
        'run', 'start', '--', '--config', $config_arg,
        '--host', $self->option('host', '127.0.0.1'),
        '--port', $self->option('port', 4321));

}
__END__

=begin markdown

# NAME

ASPEER::Markdown::Publish::Starlight - publish distribution documentation with Astro Starlight

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish::Starlight;
my $publish_or=ASPEER::Markdown::Publish::Starlight->new({sources => ['doc']});
$publish_or->build();
```

# DESCRIPTION

This engine assembles documents and an ordered sidebar in a temporary Astro
Starlight project. Set `config` to an authored Astro configuration, or let the
engine create one. `npm`, `astro_version`, `starlight_version`, `host`, `port`,
and `output` customise operation. `prepare` returns the temporary root,
project directory, and configuration path; `build` returns the site directory;
`serve` runs the foreground server.

# SEE ALSO

`ASPEER::Markdown::Publish`

=end markdown


=head1 NAME

ASPEER::Markdown::Publish::Starlight - publish distribution documentation with Astro Starlight


=head1 SYNOPSIS


 use ASPEER::Markdown::Publish::Starlight;
 my $publish_or=ASPEER::Markdown::Publish::Starlight->new({sources => ['doc']});
 $publish_or->build();

=head1 DESCRIPTION

This engine assembles documents and an ordered sidebar in a temporary Astro
Starlight project. Set C<config> to an authored Astro configuration, or let the
engine create one. C<npm>, C<astro_version>, C<starlight_version>, C<host>, C<port>,
and C<output> customise operation. C<prepare> returns the temporary root,
project directory, and configuration path; C<build> returns the site directory;
C<serve> runs the foreground server.


=head1 SEE ALSO

C<ASPEER::Markdown::Publish>

=cut
