# NAME

markdown-publish - build, preview, and publish Markdown documentation

# SYNOPSIS

```sh
markdown-publish [ACTION] [OPTIONS]
markdown-publish --help
markdown-publish --version
```

# DESCRIPTION

`markdown-publish` assembles Markdown documentation and runs a static-site
publishing engine. MkDocs is the default engine; VitePress, Docusaurus, and
Astro Starlight are also included.

The default action is `build`. Unless `--config` is given, the command reads
`doc/project.json` when that file exists. Command-line options override the
corresponding settings loaded from the file.

# ACTIONS

## build

Assemble the documentation and build the static site.

## serve

Assemble the documentation and run the selected engine's local development
server in the foreground.

## gh

Build the site and update the configured local publication branch. The current
checkout is left unchanged and no remote is contacted.

## gh-push

Perform `gh`, then push only the publication branch to `origin`. The push is
not forced.

## cloudflare

Build the site and deploy it as Cloudflare Workers Static Assets with Wrangler.
This action does not change or push a Git branch.

# OPTIONS

## --config FILE

Read publication settings from the specified JSON file instead of
`doc/project.json`.

## --module MODULE

Select the publishing engine when no configuration file is used. MODULE may
be `mkdocs`, `vitepress`, `docusaurus`, or `starlight`, or the fully qualified
name of an installed `Markdown::Publish` subclass.

This option cannot be used when `--config` is given or when
`doc/project.json` exists. Use the `module` setting in that file instead.

## --source DIRECTORY

Use DIRECTORY as a documentation source. The option may be repeated; when
present, the resulting list replaces the configured sources.

## --name NAME

Set the site name.

## --base PATH

Set the deployment base path. PATH must begin and end with `/`, for example
`/project/`.

For `gh` and `gh-push`, the default is derived from the `origin` repository:
`/<repository>/` for a project site and `/` for an `<owner>.github.io`
repository.

## --output DIRECTORY

Set the generated site directory.

## --branch BRANCH

Set the local publication branch used by `gh` and `gh-push`. The default is
`gh-pages`.

## --help

Print a brief usage summary and exit.

## --version

Print the program version and exit.

# CONFIGURATION

The JSON configuration may contain publication settings directly, below
`publish`, or below `x_documentation.publish`. Engine-specific settings are
described in the corresponding `Markdown::Publish` engine module.

For `cloudflare`, `cloudflare.config` may name an authored Wrangler
configuration. Otherwise, the command looks for `wrangler.jsonc` and then
`wrangler.json` in the project root. Wrangler supplies authentication and the
configuration owns the Worker name, routes, and other deployment settings.

# ENVIRONMENT

`MARKDOWN_PUBLISH_MODULE` overrides the publishing engine selected on the
command line or in configuration. Other `MARKDOWN_PUBLISH_*` variables control
defaults such as the output directory, publication branch, and local server
address; see `Markdown::Publish::Constant`.

# FILES

`doc/project.json`
: Default publication configuration.

`wrangler.jsonc`, `wrangler.json`
: Default Cloudflare Wrangler configuration, in order of preference.

# EXIT STATUS

The command exits with status zero after a successful action, or non-zero when
an option, configuration, build, publication, or deployment operation fails.

# SEE ALSO

`Markdown::Publish`, `Markdown::Publish::MkDocs`,
`Markdown::Publish::VitePress`, `Markdown::Publish::Docusaurus`,
`Markdown::Publish::Starlight`, `Markdown::Publish::Constant`

# AUTHOR

Andrew Speer <andrew.speer@isolutions.com.au>

# LICENSE AND COPYRIGHT

This software is copyright (c) 2026 by Andrew Speer. It may be distributed
under the same terms as Perl itself.
