# NAME

markdown-publish - build, preview, and publish Perl distribution documentation

# USAGE

```sh
markdown-publish build
markdown-publish serve --config doc/project.json
markdown-publish gh --config doc/project.json
markdown-publish cloudflare --config doc/project.json
```

`build` prepares and renders the site. `serve` starts the selected engine's
foreground local server. `gh` builds, updates the configured publication
branch, and leaves it local. Push that branch through the repository's normal
Git workflow.

`cloudflare` builds the selected engine and deploys its output to a Cloudflare
Worker using the `cloudflare.config` Wrangler file in the JSON configuration.
It does not change a Git branch or push to GitHub.

MkDocs is used when no backend is selected. `--module` selects a backend when
no configuration file is used. Otherwise put `module` in the JSON configuration.
`MARKDOWN_PUBLISH_MODULE` overrides either selection. Bundled publishers may be
selected with `mkdocs`, `vitepress`, `docusaurus`, or `starlight`; a fully
qualified name may select another installed subclass. Without `--config`, an
existing `doc/project.json` is read automatically. Other options are repeatable
`--source DIRECTORY`, `--name`, `--output`, and `--branch`.

`--version` prints the installed program version.
