# NAME

ASPEER::Markdown::Publish - common documentation publication operations

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish;

my $publish_or=ASPEER::Markdown::Publish->new({
    module  => 'ASPEER::Markdown::Publish::MkDocs',
    sources => ['doc'],
    config  => 'doc/mkdocs/mkdocs.yml',
});

$publish_or->run('build');
$publish_or->run('serve');
$publish_or->run('gh');
$publish_or->run('cloudflare');
```

# DESCRIPTION

This module selects one publishing engine and provides the shared operations
for assembling Markdown, splitting chapters, normalising links and assets,
and publishing a built site through a temporary Git worktree. The engine
classes implement their own `prepare`, `build`, and `serve` methods. No
Makefile is needed; `ASPEER::MakeMaker::Markdown::Publish` supplies optional
MakeMaker targets.

An existing `doc/` directory is the default publication boundary. When it is
assembled, Markdown beneath `lib/` and `bin/` is mirrored under those paths in
the temporary site documents. A guide can link to `lib/Example/Module.pm.md`.
Mirrored pages are available through links but are not added to generated
navigation. When `doc/` is absent, sidecars become the default source pages.
Set `sources` explicitly to include other directories. Source files are never rewritten;
assembly and engine-specific Markdown adjustments happen in temporary trees.
Nested Markdown under `doc/` remains available for links but does not appear
in generated navigation. When no `index.md` was authored, the first top-level
page becomes the home page in each engine; its original URL remains available.

# CONFIGURATION

The default engine is `ASPEER::Markdown::Publish::MkDocs`. Select another class
with `module`. `MARKDOWN_PUBLISH_MODULE` overrides `module`, including
when it comes from a JSON file or MakeMaker metadata. Engine settings are flat,
rather than nested beneath engine names:

```perl
{
    module  => 'ASPEER::Markdown::Publish::Docusaurus',
    sources => ['doc'],
    name    => 'Example documentation',
    config  => 'doc/docusaurus/docusaurus.config.js',
    output  => 'site',
    branch  => 'gh-pages',
    remote  => 'github',
    cloudflare => {config => 'wrangler.jsonc'},
}
```

The `config` path and other engine-specific options are described by the
selected engine module. `load_config($filename)` accepts a JSON object
containing the settings directly, under `publish`, or under
`x_documentation.publish`. `new({config_file => $filename})` is equivalent.
Do not combine `config_file` with inline settings.

For a static documentation Worker, a minimal authored `wrangler.jsonc` is:

```jsonc
{
    "name": "example-docs",
    "compatibility_date": "2026-09-22",
    "assets": {
        "directory": "./site",
        "not_found_handling": "404-page"
    },
    "observability": {
        "enabled": true,
        "traces": {"enabled": true}
    }
}
```

Use the current compatibility date for a new Worker and choose the intended
Worker name. The deploy action replaces `assets.directory` with the selected
engine's actual build output; the authored file remains unchanged.

# METHODS

## new

Loads and constructs the selected engine class. A direct engine-class
constructor may be used when the class is already known.

## load_config

Reads a JSON configuration and constructs its selected engine.

## run

Dispatches `build`, `serve`, `gh`, or `cloudflare`. `gh` builds the
site, updates the local publication branch, then pushes that branch to the
configured remote. It defaults to a remote named `github` and fails if that
remote does not exist. It is an explicit publishing action, not part of
`build` or `serve`. `cloudflare` builds and deploys the static files to a
Cloudflare Worker without committing or pushing Git.

## source_directories

Returns the configured source roots or the default roots described above.

## prepare_docs

Assembles source Markdown and assets in a temporary directory. Returns the
temporary root, assembled document directory, and ordered pages.

## split

Splits a guide at top-level headings outside code fences and repairs links to
anchors moved into another generated page.

## publish_gh

Builds, commits to a temporary worktree for the configured branch, and pushes
that branch to the configured GitHub remote. It does not change the current
checkout or force-push.

## publish_cloudflare

Builds through the selected engine, then deploys that output as Workers Static
Assets using Wrangler. Set `cloudflare.config` to an existing, dedicated
Wrangler configuration file for the intended Worker. `cloudflare.wrangler`
selects the executable (`wrangler` by default); `cloudflare.environment`
optionally selects an authored Wrangler environment. The site directory is
passed with `--assets`, overriding the config file's asset directory. Missing
configuration or build output is fatal before deployment. Authentication
comes from Wrangler's existing login or environment, not publication metadata.

The Wrangler config owns the Worker name, compatibility date, routing, and
other deployment settings. Use a static-assets-only config without a `main`
script for this documentation workflow. Publishing to an existing Worker can
update its settings; review its config before invoking this remote action.

# SEE ALSO

`ASPEER::Markdown::Publish::MkDocs`,
`ASPEER::Markdown::Publish::VitePress`,
`ASPEER::Markdown::Publish::Docusaurus`,
`ASPEER::Markdown::Publish::Starlight`,
`ASPEER::MakeMaker::Markdown::Publish`

# AUTHOR

Andrew Speer <andrew.speer@isolutions.com.au>

# LICENSE AND COPYRIGHT

This file is part of ASPEER::Markdown::Publish. Copyright (c) 2026 Andrew
Speer. This is free software; you can redistribute it and/or modify it under
the same terms as Perl 5.
