# ASPEER::Markdown::Publish

Build, preview, and publish Markdown documentation from Perl distribution
trees with MkDocs, VitePress, Docusaurus, or Astro Starlight.

## Install and run

Install this distribution with `cpanm .`, then install the external site
generator required for the backend you use.

```sh
markdown-publish mkdocs build
markdown-publish mkdocs serve
markdown-publish mkdocs gh_publish
# Explicit remote publication:
markdown-publish mkdocs gh_push
```

An existing `doc/` directory is the default publication boundary. `lib/` and
`bin/` sidecars are used only when `doc/` is absent, or when they are named in
an explicit source list. Guides with multiple top-level headings are split into
stable ID-based pages.

Common and backend-specific settings include source directories, configuration
paths, output directories, publication branch, remote, and executable names.
Standalone projects may put the configuration in `doc/project.json`.

The HTML output defaults to `site/`. `gh_publish` requires an existing Git
commit and configured author identity. It updates `gh-pages` through a temporary
worktree and never pushes. Only `gh_push` updates the configured remote.

See [API details](lib/ASPEER/Markdown/Publish.pm.md) and
[examples](examples/README.md). `Markdown::MkDocs` and `markdown-mkdocs` remain
as compatibility interfaces for the earlier unpublished implementation.

`ASPEER::MakeMaker::Markdown::Publish` supplies equivalent Makefile targets and
passes the `META_MERGE.x_documentation.publish` field to this module.
