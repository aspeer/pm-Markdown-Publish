# Convention-based site

From this directory, after installation:

```sh
markdown-publish mkdocs build
markdown-publish mkdocs serve
```

The two guide chapters become separate pages. Stop preview with Ctrl-C.
To experiment with publication, copy this example into a disposable Git
repository, make an initial commit, and run `markdown-publish mkdocs gh_publish`.
Inspect `git log gh-pages`; nothing is pushed.
