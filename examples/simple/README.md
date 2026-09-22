# Convention-based site

From this directory, after installation:

```sh
markdown-publish build
markdown-publish serve
```

The two guide chapters become separate pages. Stop preview with Ctrl-C.
To experiment with publication, copy this example into a disposable Git
repository, make an initial commit, add a disposable remote named `github`,
and run `markdown-publish gh`.
This action pushes the `gh-pages` branch to that remote.
