#!perl

use strict;
use warnings;
use lib 'lib';

use Cwd qw(abs_path getcwd);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json);
use Test::More;

use ASPEER::Markdown::Publish;


sub blurp {

    my ($fn, $text)=@_;
    open(my $output_fh, '>', $fn) || die "unable to write $fn: $!";
    print {$output_fh} $text;
    close($output_fh) || die "unable to close $fn: $!";
    return 1;

}


sub slurp {

    my ($fn)=@_;
    open(my $input_fh, '<', $fn) || die "unable to read $fn: $!";
    local $/=undef;
    my $text=<$input_fh>;
    close($input_fh) || die "unable to close $fn: $!";
    return $text;

}


#  Work entirely inside a disposable distribution tree
#
my $cwd=getcwd();
my $temporary_dn=tempdir(CLEANUP => 1);
chdir($temporary_dn) || die "unable to chdir $temporary_dn: $!";
make_path('doc/mkdocs', 'lib/Sample', 'bin', 'config');
blurp('doc/guide.md', "# Start {#start}\n\n[Next](#next)\n\n# Next {#next}\n\nDone.\n");
blurp('lib/Sample/Module.pm.md', "# Sample::Module\n\nModule documentation.\n");
blurp('bin/example.md', "# example\n\nUtility documentation.\n");


#  doc is the default publication boundary when present
#
my $publish_or=ASPEER::Markdown::Publish->new();
my ($assembly_dn, $docs_dn, $pages_ar)=$publish_or->prepare_docs();
ok(-f "$docs_dn/guide--start.md", 'doc guide is split into publication pages');
ok(!-e "$docs_dn/modules/Sample_Module.md", 'module sidecar is excluded by default');
like(slurp("$docs_dn/guide--start.md"), qr/\[Next\]\(guide--next\.md\)/,
    'chapter links use the split page without a redundant heading fragment');
is_deeply($pages_ar, ['index.md', 'guide--start.md', 'guide--next.md'],
    'default navigation contains only doc pages');


#  Explicit sources are exact and can aggregate distribution documentation
#
$publish_or=ASPEER::Markdown::Publish->new({sources => [qw(doc lib bin)]});
(undef, $docs_dn, $pages_ar)=$publish_or->prepare_docs();
ok(-f "$docs_dn/modules/Sample_Module.md", 'explicit lib source publishes module sidecar');
ok(-f "$docs_dn/utilities/example.md", 'explicit bin source publishes utility sidecar');


#  An existing empty doc directory remains an intentional boundary
#
unlink('doc/guide.md') || die "unable to remove disposable guide: $!";
eval {ASPEER::Markdown::Publish->new()->prepare_docs()};
like($@, qr/no Markdown documents discovered/, 'empty doc does not fall back to sidecars');
blurp('doc/guide.md', "# Guide\n\nText.\n");


#  Standalone JSON accepts the same x_documentation metadata shape
#
blurp('config/project.json', encode_json({
    x_documentation => {
        publish => {
            sources => ['doc'],
            mkdocs => {config => 'doc/mkdocs/custom.yml'}
        }
    }
}));
$publish_or=ASPEER::Markdown::Publish->load_config('config/project.json');
is_deeply($publish_or->{'sources'}, ['doc'], 'metadata publication sources loaded');
is($publish_or->{'mkdocs'}{'config'}, 'doc/mkdocs/custom.yml',
    'backend configuration loaded');


#  Custom backend configuration paths are applied to prepared trees
#
blurp('doc/mkdocs/custom.yml', "site_name: Custom\n");
my $mkdocs_fn=$publish_or->prepare_mkdocs(1);
like(slurp($mkdocs_fn), qr/^INHERIT: .*custom\.yml/m,
    'custom MkDocs configuration is inherited');
like(slurp($mkdocs_fn), qr/^docs_dir: /m, 'assembled documentation overrides docs_dir');

blurp('config/vitepress.mts', "export default { title: 'Custom' };\n");
blurp('doc/chapters.md',
    "# First Chapter {#first}\n\nFirst.\n\n# Second Chapter {#second}\n\nSecond.\n");
blurp('doc/formatting.md', <<'MARKDOWN');
# Formatting {#formatting}

`handler=METHOD`

: Call a handler.

  [Full manual](manual.md){target="_blank" rel="noopener"}

  ``` {#handler_example .perl}
  print "ok";
  ```

```text
Term

: remains example text
```
MARKDOWN
$publish_or=ASPEER::Markdown::Publish->new({sources => ['doc']});
my (undef, $generated_vitepress_dn, $generated_vitepress_fn)=$publish_or->prepare_vitepress();
my $vitepress_config=slurp($generated_vitepress_fn);
like($vitepress_config,
    qr/text: "First Chapter".*text: "Second Chapter"/s,
    'VitePress navigation uses authored titles in source order');
unlike($vitepress_config, qr/text: "chapters--first\.md"/,
    'VitePress does not expose generated filenames as labels');
my $vitepress_formatting=slurp("$generated_vitepress_dn/formatting.md");
like($vitepress_formatting, qr/- \*\*`handler=METHOD`\*\*\n\n  Call a handler\./,
    'VitePress receives portable CommonMark definition items');
like($vitepress_formatting, qr/  <a id="handler_example"><\/a>\n  ```perl/,
    'VitePress receives portable fenced-code attributes');
unlike($vitepress_formatting, qr/\{target=/,
    'VitePress does not receive visible link attributes');
like($vitepress_formatting, qr/```text\nTerm\n\n: remains example text\n```/,
    'definition syntax inside a fenced example is unchanged');

$publish_or=ASPEER::Markdown::Publish->new({
    sources   => ['doc'],
    vitepress => {config => 'config/vitepress.mts'}
});
my (undef, $vitepress_dn, $vitepress_config_fn)=$publish_or->prepare_vitepress();
is($vitepress_config_fn, abs_path('config/vitepress.mts'),
    'custom VitePress configuration location retained');

blurp('config/docusaurus.js', "module.exports = { title: 'Custom' };\n");
blurp('doc/guide.md', "# Guide {#guide}\n\nText.\n");
$publish_or=ASPEER::Markdown::Publish->new({sources => ['doc']});
my (undef, $generated_docusaurus_dn, $generated_docusaurus_fn)=
    $publish_or->prepare_docusaurus();
like(slurp($generated_docusaurus_fn), qr/markdown: \{ format: 'detect' \}/,
    'generated Docusaurus project enables CommonMark detection');
my $docusaurus_sidebar=slurp("$generated_docusaurus_dn/sidebars.js");
like($docusaurus_sidebar,
    qr/"label":"First Chapter".*"label":"Second Chapter"/s,
    'Docusaurus sidebar uses authored titles in source order');
like(slurp("$generated_docusaurus_dn/docs/chapters--first.md"),
    qr/\A---\ntitle: "First Chapter"\n---\n\n<a id="first"><\/a>/,
    'Docusaurus receives an explicit title before its heading anchor');
my $docusaurus_formatting=slurp("$generated_docusaurus_dn/docs/formatting.md");
like($docusaurus_formatting, qr/- \*\*`handler=METHOD`\*\*\n\n  Call a handler\./,
    'Docusaurus receives portable CommonMark definition items');
unlike($docusaurus_formatting, qr/\{target=/,
    'Docusaurus does not receive visible link attributes');
$publish_or=ASPEER::Markdown::Publish->new({
    sources    => ['doc'],
    docusaurus => {config => 'config/docusaurus.js'}
});
my (undef, $docusaurus_dn, $docusaurus_config_fn)=$publish_or->prepare_docusaurus();
is($docusaurus_config_fn, abs_path('config/docusaurus.js'),
    'custom Docusaurus configuration location retained');
like(slurp("$docusaurus_dn/docs/guide.md"), qr/<a id="guide"><\/a>/,
    'Docusaurus receives explicit HTML heading anchors');

blurp('config/astro.mjs', "export default {};\n");
$publish_or=ASPEER::Markdown::Publish->new({sources => ['doc']});
my (undef, $generated_starlight_dn, $generated_starlight_fn)=$publish_or->prepare_starlight();
my $starlight_config=slurp($generated_starlight_fn);
like($starlight_config,
    qr/label: "First Chapter", slug: "chapters--first".*label: "Second Chapter", slug: "chapters--second"/s,
    'Starlight navigation includes root pages in source order');
unlike($starlight_config, qr/autogenerate/,
    'Starlight does not depend on root-directory autogeneration');
my $starlight_formatting=slurp("$generated_starlight_dn/src/content/docs/formatting.md");
like($starlight_formatting,
    qr/\A---\ntitle: "Formatting"\n---\n\n<a id="formatting"><\/a>\n\n- \*\*`handler=METHOD`\*\*/,
    'Starlight uses its page title and retains the authored chapter anchor');
unlike($starlight_formatting, qr/^# Formatting/m,
    'Starlight does not render a duplicate first-level page title');
unlike($starlight_formatting, qr/\{#|\{target=/,
    'Starlight does not receive visible Pandoc attributes');
like($starlight_formatting, qr/  <a id="handler_example"><\/a>\n  ```perl/,
    'Starlight receives a portable code language and anchor');

$publish_or=ASPEER::Markdown::Publish->new({
    sources   => ['doc'],
    starlight => {config => 'config/astro.mjs'}
});
my (undef, $starlight_dn, $starlight_config_fn)=$publish_or->prepare_starlight();
is($starlight_config_fn, abs_path('config/astro.mjs'),
    'custom Starlight configuration location retained');


#  Generated Starlight configuration is addressed from its disposable project
#
{
    package TestBuild;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish);
    sub npm_install {return 1}
    sub system_in_dir {
        my ($self, $dir, @command)=@_;
        $self->{'site_dn'}=$dir;
        $self->{'command'}=\@command;
        return 1;
    }
}

my $build_or=TestBuild->new({sources => ['doc']});
$build_or->build('starlight');
is($build_or->{'command'}[5], 'astro.config.mjs',
    'generated Starlight configuration is relative to its project');


#  Preview host and port settings reach each backend command
#
{
    package TestServe;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish);
    sub prepare_mkdocs {return 'mkdocs.yml'}
    sub prepare_vitepress {return ('tmp', 'docs', 'vitepress.mts')}
    sub prepare_docusaurus {return ('tmp', 'docusaurus', 'docusaurus.js')}
    sub prepare_starlight {return ('tmp', 'starlight', 'astro.config.mjs')}
    sub npm_install {return 1}
    sub system_command {
        my ($self, @command)=@_;
        $self->{'command'}=\@command;
        return 1;
    }
    sub system_in_dir {
        my ($self, $dir, @command)=@_;
        $self->{'command'}=\@command;
        $self->{'astro_background'}=$ENV{'ASTRO_DEV_BACKGROUND'};
        return 1;
    }
}

my $serve_or=TestServe->new({
    mkdocs     => {address => '127.0.0.1:8000'},
    vitepress  => {port => 8001},
    docusaurus => {port => 8002},
    starlight  => {port => 8003},
});
$serve_or->serve('mkdocs');
is_deeply([@{$serve_or->{'command'}}[-2, -1]], ['-a', '127.0.0.1:8000'],
    'MkDocs preview address passed');
foreach my $backend_port_ar ([vitepress => 8001], [docusaurus => 8002], [starlight => 8003]) {
    my ($backend, $port)=@{$backend_port_ar};
    $serve_or->serve($backend);
    is_deeply([@{$serve_or->{'command'}}[-2, -1]], ['--port', $port],
        "$backend preview port passed");
}
is($serve_or->{'astro_background'}, 0, 'Starlight preview remains in the foreground');


#  Generic action dispatch keeps remote push distinct from local publication
#
{
    package TestPublish;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish);
    sub build {my ($self, $backend)=@_; $self->{'called'}=[$backend, 'build']; return 1}
    sub serve {my ($self, $backend)=@_; $self->{'called'}=[$backend, 'serve']; return 1}
    sub gh_publish {
        my ($self, $backend, $push)=@_;
        $self->{'called'}=[$backend, 'gh_publish', $push];
        return 1;
    }
}

my $test_or=TestPublish->new();
$test_or->run('mkdocs', 'gh_publish');
is_deeply($test_or->{'called'}, ['mkdocs', 'gh_publish', 0],
    'gh_publish prepares only the local branch');
$test_or->run('docusaurus', 'gh_push');
is_deeply($test_or->{'called'}, ['docusaurus', 'gh_publish', 1],
    'gh_push explicitly enables remote update');
eval {$test_or->run('unknown', 'build')};
like($@, qr/unknown publication backend/, 'unknown backend rejected');

chdir($cwd) || die "unable to restore cwd $cwd: $!";
done_testing();
