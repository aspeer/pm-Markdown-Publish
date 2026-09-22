# NAME

ASPEER::Markdown::Publish::Docusaurus - publish distribution documentation with Docusaurus

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish::Docusaurus;
my $publish_or=ASPEER::Markdown::Publish::Docusaurus->new({sources => ['doc']});
$publish_or->build();
```

# DESCRIPTION

This engine assembles documents and an ordered sidebar in a temporary
Docusaurus project. Set `config` to an authored Docusaurus configuration, or
let the engine create one. `npm`, `version`, `host`, `port`, and `output`
customise operation. `prepare` returns the temporary root, project directory,
and configuration path; `build` returns the site directory; `serve` runs the
foreground server.

# SEE ALSO

`ASPEER::Markdown::Publish`
