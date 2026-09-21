# NAME

ASPEER::Markdown::Publish - publish Perl distribution documentation with multiple site generators

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish;

my $publish_or=ASPEER::Markdown::Publish->new({
    sources => ['doc'],
    mkdocs  => {
        config => 'doc/mkdocs/mkdocs.yml',
        output => 'site',
    },
});

$publish_or->run('mkdocs', 'build');
$publish_or->run('mkdocs', 'serve');
$publish_or->run('mkdocs', 'gh_publish');
```

# DESCRIPTION

`ASPEER::Markdown::Publish` assembles Markdown documentation from a Perl
distribution and delegates rendering to MkDocs, VitePress, Docusaurus, or
Astro Starlight. It has no MakeMaker dependency. The companion
`ASPEER::MakeMaker::Markdown::Publish` module supplies Makefile targets and
passes `META_MERGE.x_documentation.publish` configuration to this module.

When `sources` is omitted, an existing `doc/` directory is the publication
boundary. If `doc/` does not exist, `lib/` and `bin/` Markdown sidecars are used
as a compatibility fallback. An existing but empty `doc/` directory does not
fall back. An explicit source list is exact:

```perl
sources => [qw(doc lib bin)]
```

Multiple top-level headings in documents beneath `doc/` are split into stable
pages. Explicit anchors and links between split chapters are preserved.
For the Node-backed generators, Pandoc definition lists and attribute syntax
are converted to portable Markdown and HTML equivalents in the disposable
publication tree. Authored source documents are not changed.

# CONFIGURATION

Common settings may be placed directly in the constructor hash. A backend hash
overrides the corresponding common value:

```perl
{
    sources => ['doc'],
    name    => 'Example documentation',
    output  => 'site',
    branch  => 'gh-pages',
    remote  => 'origin',

    mkdocs => {
        config      => 'doc/mkdocs/mkdocs.yml',
        config_mode => 'inherit',
        command     => 'mkdocs',
        strict      => 1,
        address     => '127.0.0.1:8000',
    },

    vitepress => {
        config => 'doc/vitepress/config.mts',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 5173,
        version => 'latest',
    },

    docusaurus => {
        config => 'doc/docusaurus/docusaurus.config.js',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 3001,
        version => 'latest',
    },

    starlight => {
        config => 'doc/starlight/astro.config.mjs',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 4321,
        astro_version     => 'latest',
        starlight_version => 'latest',
    },
}
```

A root `mkdocs.yml` is used directly because it owns its complete source-tree
layout. Other MkDocs configuration paths are inherited by a temporary child
configuration which supplies the assembled documentation, navigation, and
output directory. Set `config_mode` to `direct` when a non-root configuration
also owns its complete layout.

`load_config($filename)` reads JSON in any of these forms:

```json
{"sources":["doc"]}
```

```json
{"publish":{"sources":["doc"]}}
```

```json
{"x_documentation":{"publish":{"sources":["doc"]}}}
```

# METHODS

## new

Creates a publisher from a configuration hash reference.

## load_config

Creates a publisher from a standalone JSON file.

## run

```perl
$publish_or->run($backend, $action);
```

Supported backends are `mkdocs`, `vitepress`, `docusaurus`, and `starlight`.
Supported actions are:

- `build`: render the static site.
- `serve`: run the backend's foreground preview server.
- `gh_publish`: build and commit the result to a local publication branch.
- `gh_push`: perform `gh_publish`, then push the selected branch to the selected
  remote.

Remote publication is never implicit.

## source_directories

Returns the exact configured publication roots or the default roots selected by
the `doc/` boundary rule.

## prepare_docs

Assembles source Markdown and assets in a temporary directory. It returns the
temporary root, assembled documentation directory, and ordered page list.

## split

Splits a Markdown guide at top-level ATX headings, ignoring fenced examples,
and repairs links to explicit anchors moved to another generated page.

## prepare_mkdocs

Returns a MkDocs configuration filename, generating a temporary configuration
when assembly or inheritance is required.

## prepare_vitepress

Returns a temporary root, prepared VitePress documentation directory, and
configuration filename. An authored configuration remains at its original
location so its relative imports continue to resolve correctly. Generated
navigation uses each page's authored title and preserves source order.

## prepare_docusaurus

Returns a temporary root, prepared Docusaurus project directory, and
configuration filename. Generated pages receive explicit title frontmatter and
the sidebar preserves authored titles and source order.

## prepare_starlight

Returns a temporary root, prepared Astro Starlight project directory, and
configuration filename. Generated navigation lists every page explicitly so
root documents retain their authored titles and source order.

## build

Builds one supported backend and returns the absolute output directory.

## serve

Starts one supported backend's foreground development server.

## gh_publish

Builds a backend, updates a local publication branch through a temporary Git
worktree, and optionally pushes when its second argument is true. Callers should
normally use `run()` so local publication and explicit push remain distinct.

# ERRORS

Invalid configuration, missing source/configuration files, failed external
commands, unsafe chapter identifiers, and Git failures are fatal.

# SEE ALSO

`ASPEER::MakeMaker::Markdown::Publish`, `ASPEER::MakeMaker::Markdown::Pod`

# AUTHOR

Andrew Speer <andrew.speer@isolutions.com.au>

# LICENSE AND COPYRIGHT

This file is part of ASPEER::Markdown::Publish.

This software is copyright (c) 2026 by Andrew Speer
<andrew.speer@isolutions.com.au>.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
