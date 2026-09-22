# NAME

ASPEER::Markdown::Publish::MkDocs - publish distribution documentation with MkDocs

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish::MkDocs;
my $publish_or=ASPEER::Markdown::Publish::MkDocs->new({sources => ['doc']});
$publish_or->build();
```

# DESCRIPTION

This engine prepares a MkDocs configuration and runs MkDocs. Set `config` to
an authored YAML file. A root `mkdocs.yml` is used directly; other files are
inherited by a temporary configuration that supplies the assembled documents
and navigation. Set `config_mode => 'direct'` when an authored file already
owns that layout. `command`, `strict`, `address`, and `output` customise the
build and local server. `prepare($preview)` returns the configuration path;
`build` returns the site directory; `serve` runs the foreground server.

When no home page is authored, the first top-level assembled page is also used
for `index.md`. Its original URL remains available for existing links.

# SEE ALSO

`ASPEER::Markdown::Publish`
