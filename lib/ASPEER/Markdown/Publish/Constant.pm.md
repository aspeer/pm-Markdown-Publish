# NAME

ASPEER::Markdown::Publish::Constant - publication defaults

# DESCRIPTION

Defines `MARKDOWN_PUBLISH_MODULE`, `MARKDOWN_PUBLISH_CONFIG_FN`,
`MARKDOWN_PUBLISH_OUTPUT_DN`, `MARKDOWN_PUBLISH_BRANCH`, and
`MARKDOWN_PUBLISH_REMOTE`. Import individual scalar constants or use the default
export set. The default publisher is `ASPEER::Markdown::Publish::MkDocs`.

An optional `Constant.pm.local` beside the installed module may return a hash
reference of permanent overrides:

```perl
+{
    MARKDOWN_PUBLISH_MODULE    => 'ASPEER::Markdown::Publish::VitePress',
    MARKDOWN_PUBLISH_OUTPUT_DN => 'public'
}
```

Environment variables named after the constants override both the local file
and built-in values. `MARKDOWN_PUBLISH_MODULE` also overrides a module supplied
through the API, `META_MERGE.x_documentation.publish`, or JSON configuration.
