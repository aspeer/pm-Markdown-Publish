# NAME

ASPEER::Markdown::Publish::VitePress - publish distribution documentation with VitePress

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish::VitePress;
my $publish_or=ASPEER::Markdown::Publish::VitePress->new({sources => ['doc']});
$publish_or->build();
```

# DESCRIPTION

This engine assembles documents, writes generated navigation when no authored
configuration is supplied, and runs VitePress in a temporary npm project.
Set `config` to an authored VitePress configuration; its original location is
preserved for relative imports. `npm`, `version`, `host`, `port`, and `output`
customise operation. `prepare` returns the temporary root, documentation
directory, and configuration path; `build` returns the site directory; `serve`
runs the foreground server.

# SEE ALSO

`ASPEER::Markdown::Publish`
