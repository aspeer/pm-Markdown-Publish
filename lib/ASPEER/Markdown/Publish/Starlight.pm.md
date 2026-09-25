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
`serve` runs the foreground server. For generated configuration, `base` sets
Astro's deployment base path. An authored configuration remains authoritative.
Local Markdown links such as `lib/Example/Module.pm.md` are resolved to the
corresponding Starlight page in the temporary project. An authored Astro
configuration is wrapped to retain this behavior; its Markdown processor must
be unified if it sets one explicitly.

# SEE ALSO

`ASPEER::Markdown::Publish`
