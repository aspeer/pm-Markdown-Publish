# NAME

Markdown::MkDocs - build, preview, and publish repository Markdown

# SYNOPSIS

```perl
use Markdown::MkDocs;
my $site_or=Markdown::MkDocs->new({name => 'Example'});
$site_or->build();
$site_or->pages();
```

# PUBLIC METHODS

`new(\%options)` accepts name, mkdocs (executable), branch (default gh-pages),
remote (default origin), and push (false by default).

`prepare()` returns a MkDocs configuration path. With an existing mkdocs.yml,
that configuration is returned unchanged. Otherwise a temporary source tree is
assembled from doc, lib, and bin Markdown. Generated temporary files are removed
at process exit.

`prepare_preview()` also recognises `doc/mkdocs/mkdocs.yml`. It assembles the
current Markdown into a temporary docs tree and creates a temporary
configuration inheriting the project file. The project theme, extensions and
presentation settings are retained while the generated docs directory,
navigation and built-in search plugin are selected for the local preview. A
root `mkdocs.yml` continues to own its complete source-tree layout.

`split($filename, $markdown)` returns a hash reference mapping stable page names
to Markdown. It recognises top-level ATX headings outside backtick/tilde fences,
uses explicit IDs where supplied, and rewrites explicit internal anchor links.
Duplicate chapter IDs are errors.

`build()` runs a strict MkDocs build and returns the absolute site/ directory.
`serve()` starts the foreground preview server until it is interrupted.
`pages()` builds and commits to the publication branch, optionally pushing.
An unchanged site does not create another commit. Existing branch history is
preserved. Git refuses publication if the branch is already checked out elsewhere.

Commands failing to run or returning nonzero throw exceptions. An existing
mkdocs.yml is responsible for its own navigation, hooks, and source assembly.
