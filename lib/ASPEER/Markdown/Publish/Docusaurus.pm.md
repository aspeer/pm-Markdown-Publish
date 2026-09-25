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
foreground server. For generated configuration, `base` sets Docusaurus's
`baseUrl`. An authored configuration remains authoritative.

Set `config_extend` to a CommonJS module exporting a synchronous function that
accepts `(config, context)` and returns the Docusaurus configuration to use.
The context contains the generated publication name, base, output, pages, and
navigation. `config` and `config_extend` cannot be combined.

```javascript
module.exports = (config) => ({
  ...config,
  onBrokenLinks: 'throw',
});
```

# SEE ALSO

`ASPEER::Markdown::Publish`
