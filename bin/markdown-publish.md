# NAME

markdown-publish - build, preview, and publish Perl distribution documentation

# USAGE

```sh
markdown-publish mkdocs build
markdown-publish mkdocs serve
markdown-publish mkdocs gh_publish
markdown-publish mkdocs gh_push
```

The backend may be `mkdocs`, `vitepress`, `docusaurus`, or `starlight`.
`gh_publish` changes only the local publication branch. `gh_push` is the
explicit remote operation.

Options include `--config FILE`, repeatable `--source DIRECTORY`, `--name`,
`--output`, `--branch`, and `--remote`. Without `--config`, an existing
`doc/project.json` is read. Otherwise the module's convention-based defaults
are used.
