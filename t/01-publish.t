#!perl

use strict;
use warnings;
use lib 'lib';

use Cwd qw(abs_path getcwd);
use IPC::Run3 qw(run3);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json);
use Test::More;

use ASPEER::Markdown::Publish;
use ASPEER::Markdown::Publish::MkDocs;
use ASPEER::Markdown::Publish::VitePress;
use ASPEER::Markdown::Publish::Docusaurus;
use ASPEER::Markdown::Publish::Starlight;

local $ENV{'MARKDOWN_PUBLISH_MODULE'};
delete($ENV{'MARKDOWN_PUBLISH_MODULE'});


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
my $constant_fn=abs_path($INC{'ASPEER/Markdown/Publish/Constant.pm'});
my $temporary_dn=tempdir(CLEANUP => 1);
chdir($temporary_dn) || die "unable to chdir $temporary_dn: $!";
make_path('doc/mkdocs', 'lib/Sample', 'bin/nested', 'config');
blurp('doc/guide.md', "# Start {#start}\n\n[Module](lib/Sample/Module.pm.md)\n\n[Utility](bin/nested/example.md)\n\n[Next](#next)\n\n# Next {#next}\n\nDone.\n");
blurp('lib/Sample/Module.pm.md', "# Sample::Module\n\nModule documentation.\n");
blurp('bin/nested/example.md', "# example\n\nUtility documentation.\n");


#  doc is the default publication boundary when present
#
my $publish_or=ASPEER::Markdown::Publish::MkDocs->new();
my ($assembly_dn, $docs_dn, $pages_ar)=$publish_or->prepare_docs();
ok(-f "$docs_dn/guide--start.md", 'doc guide is split into publication pages');
ok(!-e "$docs_dn/modules/Sample_Module.md", 'module sidecar is excluded by default');
is(slurp("$docs_dn/lib/Sample/Module.pm.md"), slurp('lib/Sample/Module.pm.md'),
    'nested module sidecar is mirrored with its name intact');
is(slurp("$docs_dn/bin/nested/example.md"), slurp('bin/nested/example.md'),
    'nested executable Markdown is mirrored with its path intact');
ok(!-e 'doc/lib' && !-e 'doc/bin', 'assembly leaves authored doc directory untouched');
like(slurp("$docs_dn/guide--start.md"), qr/\[Module\]\(lib\/Sample\/Module\.pm\.md\)/,
    'chapter link to mirrored module is preserved');
like(slurp("$docs_dn/guide--start.md"), qr/\[Next\]\(guide--next\.md\)/,
    'chapter links use the split page without a redundant heading fragment');
is_deeply($pages_ar, ['guide--start.md', 'guide--next.md'],
    'first split section leads navigation without the generated index or sidecars');
unlike(slurp("$docs_dn/index.md"), qr{lib/Sample|bin/nested},
    'generated index omits mirrored sidecars');
my $navigation_fn=$publish_or->prepare();
like(slurp($navigation_fn), qr/^nav:\n  - "index\.md"\n  - "guide--next\.md"/m,
    'MkDocs places the first split section at the site root');
my ($mkdocs_dn)=$navigation_fn=~m{^(.*)/mkdocs\.yml$};
is(slurp("$mkdocs_dn/docs/index.md"), slurp("$mkdocs_dn/docs/guide--start.md"),
    'MkDocs home page contains the first split section');
blurp('doc/index.md', "# Authored home\n\nKeep this page.\n");
$navigation_fn=$publish_or->prepare();
($mkdocs_dn)=$navigation_fn=~m{^(.*)/mkdocs\.yml$};
is(slurp("$mkdocs_dn/docs/index.md"), slurp('doc/index.md'),
    'authored home page is preserved');
unlink('doc/index.md') || die "unable to remove disposable home page: $!";


#  Explicit lib/bin sources retain their established publication paths
#
$publish_or=ASPEER::Markdown::Publish::MkDocs->new({sources => [qw(doc lib bin)]});
(undef, $docs_dn, $pages_ar)=$publish_or->prepare_docs();
ok(-f "$docs_dn/modules/Sample_Module.md", 'explicit lib source publishes module sidecar');
ok(-f "$docs_dn/utilities/nested/example.md", 'explicit bin source publishes utility sidecar');


#  An existing empty doc directory remains an intentional boundary
#
unlink('doc/guide.md') || die "unable to remove disposable guide: $!";
eval {ASPEER::Markdown::Publish::MkDocs->new()->prepare_docs()};
like($@, qr/no Markdown documents discovered/, 'empty doc does not fall back to sidecars');
blurp('doc/guide.md', "# Guide\n\nText.\n");


#  Standalone JSON accepts the same x_documentation metadata shape
#
blurp('config/project.json', encode_json({
    x_documentation => {
        publish => {
            module  => 'ASPEER::Markdown::Publish::MkDocs',
            sources => ['doc'],
            config  => 'doc/mkdocs/custom.yml'
        }
    }
}));
$publish_or=ASPEER::Markdown::Publish->load_config('config/project.json');
is_deeply($publish_or->{'sources'}, ['doc'], 'metadata publication sources loaded');
isa_ok($publish_or, 'ASPEER::Markdown::Publish::MkDocs');
is($publish_or->{'config'}, 'doc/mkdocs/custom.yml',
    'selected backend configuration loaded');
isa_ok(ASPEER::Markdown::Publish->new({config_file => 'config/project.json'}),
    'ASPEER::Markdown::Publish::MkDocs');
eval {ASPEER::Markdown::Publish->new({
    config_file => 'config/project.json', module => 'ASPEER::Markdown::Publish::MkDocs'
})};
like($@, qr/config_file cannot be combined/, 'file and inline settings cannot conflict');


#  Custom backend configuration paths are applied to prepared trees
#
blurp('doc/mkdocs/custom.yml', "site_name: Custom\n");
my $mkdocs_fn=$publish_or->prepare(1);
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
$publish_or=ASPEER::Markdown::Publish::VitePress->new({sources => ['doc']});
my (undef, $generated_vitepress_dn, $generated_vitepress_fn)=$publish_or->prepare();
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

$publish_or=ASPEER::Markdown::Publish::VitePress->new({
    sources => ['doc'], config => 'config/vitepress.mts'
});
my (undef, $vitepress_dn, $vitepress_config_fn)=$publish_or->prepare();
is($vitepress_config_fn, abs_path('config/vitepress.mts'),
    'custom VitePress configuration location retained');

blurp('config/docusaurus.js', "module.exports = { title: 'Custom' };\n");
blurp('doc/guide.md', "# Guide {#guide}\n\nText.\n");
$publish_or=ASPEER::Markdown::Publish::Docusaurus->new({sources => ['doc']});
my (undef, $generated_docusaurus_dn, $generated_docusaurus_fn)=
    $publish_or->prepare();
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
$publish_or=ASPEER::Markdown::Publish::Docusaurus->new({
    sources => ['doc'], config => 'config/docusaurus.js'
});
my (undef, $docusaurus_dn, $docusaurus_config_fn)=$publish_or->prepare();
is($docusaurus_config_fn, abs_path('config/docusaurus.js'),
    'custom Docusaurus configuration location retained');
like(slurp("$docusaurus_dn/docs/guide.md"), qr/<a id="guide"><\/a>/,
    'Docusaurus receives explicit HTML heading anchors');

blurp('config/astro.mjs', "export default {};\n");
blurp('doc/ModuleName.md', "# Mixed Case Module\n\nText.\n");
$publish_or=ASPEER::Markdown::Publish::Starlight->new({sources => ['doc']});
my (undef, $generated_starlight_dn, $generated_starlight_fn)=$publish_or->prepare();
my $starlight_config=slurp($generated_starlight_fn);
like($starlight_config,
    qr/label: "First Chapter", slug: "chapters--first".*label: "Second Chapter", slug: "chapters--second"/s,
    'Starlight navigation includes root pages in source order');
like($starlight_config, qr/label: "Mixed Case Module", slug: "modulename"/,
    'Starlight navigation uses Astro-normalized lower-case slugs');
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

$publish_or=ASPEER::Markdown::Publish::Starlight->new({
    sources => ['doc'], config => 'config/astro.mjs'
});
my (undef, $starlight_dn, $starlight_config_fn)=$publish_or->prepare();
is($starlight_config_fn, abs_path('config/astro.mjs'),
    'custom Starlight configuration location retained');


#  Backend methods receive their own configuration and command overrides
#
{
    package TestBuild;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish::Starlight);
    sub npm_install {return 1}
    sub system_in_dir {
        my ($self, $dir, @command)=@_;
        $self->{'site_dn'}=$dir;
        $self->{'command'}=\@command;
        return 1;
    }
}
my $build_or=TestBuild->new({sources => ['doc']});
$build_or->build();
is($build_or->{'command'}[5], 'astro.config.mjs',
    'generated Starlight configuration is relative to its project');

{
    package TestServeMkDocs;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish::MkDocs);
    sub prepare {return 'mkdocs.yml'}
    sub system_command {my ($self, @command)=@_; $self->{'command'}=\@command; return 1}
}
my $serve_or=TestServeMkDocs->new({address => '127.0.0.1:8000'});
$serve_or->serve();
is_deeply([@{$serve_or->{'command'}}[-2, -1]], ['-a', '127.0.0.1:8000'],
    'MkDocs preview address passed');

foreach my $spec_ar (
    ['VitePress', 'docs', 'vitepress.mts', 8001],
    ['Docusaurus', 'site', 'docusaurus.js', 8002],
    ['Starlight', 'site', 'astro.config.mjs', 8003]
) {
    my ($name, $dir, $config, $port)=@{$spec_ar};
    my $class="ASPEER::Markdown::Publish::$name";
    my $test_class="TestServe$name";
    {
        no strict qw(refs);
        @{$test_class.'::ISA'}=($class);
        *{$test_class.'::prepare'}=sub {return ('tmp', $dir, $config)};
        *{$test_class.'::npm_install'}=sub {return 1};
        *{$test_class.'::system_in_dir'}=sub {
            my ($self, $work_dn, @command)=@_;
            $self->{'command'}=\@command;
            $self->{'astro_background'}=$ENV{'ASTRO_DEV_BACKGROUND'};
            return 1;
        };
    }
    my $test_or=$test_class->new({port => $port});
    $test_or->serve();
    is_deeply([@{$test_or->{'command'}}[-2, -1]], ['--port', $port],
        "$name preview port passed");
    is($test_or->{'astro_background'}, 0, 'Starlight preview remains foreground')
        if $name eq 'Starlight';
}

#  Factory dispatch uses MkDocs unless configuration or environment selects a module
#
my $factory_or=ASPEER::Markdown::Publish->new({
    module => 'ASPEER::Markdown::Publish::MkDocs', sources => ['doc']
});
isa_ok($factory_or, 'ASPEER::Markdown::Publish::MkDocs');
isa_ok(ASPEER::Markdown::Publish->new({sources => ['doc']}),
    'ASPEER::Markdown::Publish::MkDocs', 'missing module defaults to MkDocs');
blurp('config/default-project.json', encode_json({publish => {sources => ['doc']}}));
isa_ok(ASPEER::Markdown::Publish->load_config('config/default-project.json'),
    'ASPEER::Markdown::Publish::MkDocs', 'configuration without module defaults to MkDocs');
{
    local $ENV{'MARKDOWN_PUBLISH_MODULE'}='ASPEER::Markdown::Publish::VitePress';
    isa_ok(ASPEER::Markdown::Publish->new({module => 'ASPEER::Markdown::Publish::MkDocs'}),
        'ASPEER::Markdown::Publish::VitePress', 'environment overrides inline module');
    isa_ok(ASPEER::Markdown::Publish->load_config('config/project.json'),
        'ASPEER::Markdown::Publish::VitePress', 'environment overrides JSON module');
}
{
    local $ENV{'MARKDOWN_PUBLISH_MODULE'}='Other::Module';
    eval {ASPEER::Markdown::Publish->new({})};
    like($@, qr/invalid publication module/, 'invalid environment module rejected');
}
eval {ASPEER::Markdown::Publish->new({module => 'Other::Module'})};
like($@, qr/invalid publication module/, 'module outside namespace rejected');

#  A fresh interpreter loads permanent local preferences, then matching
#  environment variables take precedence before constants are exported.
#
make_path('local-lib/ASPEER/Markdown/Publish');
blurp('local-lib/ASPEER/Markdown/Publish/Constant.pm', slurp($constant_fn));
my $local_fn='local-lib/ASPEER/Markdown/Publish/Constant.pm.local';
blurp($local_fn, <<'LOCAL_CONSTANTS');
+{
    MARKDOWN_PUBLISH_MODULE    => 'ASPEER::Markdown::Publish::VitePress',
    MARKDOWN_PUBLISH_OUTPUT_DN => 'local-site',
    MARKDOWN_PUBLISH_BRANCH    => 'local-pages'
}
LOCAL_CONSTANTS
my $constant_code='print join("|", map {$ASPEER::Markdown::Publish::Constant::Constant{$_}} '.
    'qw(MARKDOWN_PUBLISH_MODULE MARKDOWN_PUBLISH_OUTPUT_DN MARKDOWN_PUBLISH_BRANCH))';
my ($constant_output, $constant_error);
{
    local $ENV{'MARKDOWN_PUBLISH_OUTPUT_DN'};
    local $ENV{'MARKDOWN_PUBLISH_BRANCH'};
    delete($ENV{'MARKDOWN_PUBLISH_OUTPUT_DN'});
    delete($ENV{'MARKDOWN_PUBLISH_BRANCH'});
    run3([$^X, '-Ilocal-lib', '-MASPEER::Markdown::Publish::Constant',
        '-e', $constant_code], \undef, \$constant_output, \$constant_error);
    is($?, 0, 'adjacent local constants load');
    is($constant_output, 'ASPEER::Markdown::Publish::VitePress|local-site|local-pages',
        'local file overrides built-in constants');
    run3([$^X, '-Ilocal-lib', "-I$cwd/lib", '-MASPEER::Markdown::Publish',
        '-e', 'print ref(ASPEER::Markdown::Publish->new({}))'],
        \undef, \$constant_output, \$constant_error);
    is($?, 0, 'publisher loads with local constants');
    is($constant_output, 'ASPEER::Markdown::Publish::VitePress',
        'factory uses local publisher default');
}
{
    local $ENV{'MARKDOWN_PUBLISH_MODULE'}='ASPEER::Markdown::Publish::Docusaurus';
    local $ENV{'MARKDOWN_PUBLISH_OUTPUT_DN'}='environment-site';
    local $ENV{'MARKDOWN_PUBLISH_BRANCH'}='environment-pages';
    run3([$^X, '-Ilocal-lib', '-MASPEER::Markdown::Publish::Constant',
        '-e', $constant_code], \undef, \$constant_output, \$constant_error);
    is($?, 0, 'matching environment constants load');
    is($constant_output,
        'ASPEER::Markdown::Publish::Docusaurus|environment-site|environment-pages',
        'environment overrides local constants');
}

{
    package TestPublish;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish::MkDocs);
    sub build {my ($self)=@_; $self->{'called'}='build'; return 1}
    sub serve {my ($self)=@_; $self->{'called'}='serve'; return 1}
    sub publish_gh {my ($self)=@_; $self->{'called'}='gh'; return 1}
}
my $test_or=TestPublish->new();
$test_or->run('build');
is($test_or->{'called'}, 'build', 'build action dispatches');
$test_or->run('serve');
is($test_or->{'called'}, 'serve', 'serve action dispatches');
$test_or->run('gh');
is($test_or->{'called'}, 'gh', 'gh action dispatches');
eval {$test_or->run('unknown')};
like($@, qr/unknown publication action/, 'unknown action rejected');


#  Cloudflare deployment uses the built site and an authored Worker config
#
{
    package TestCloudflare;
    use vars qw(@ISA);
    @ISA=qw(ASPEER::Markdown::Publish::MkDocs);
    sub build {
        my ($self)=@_;
        $self->{'build_count'}++;
        return $self->{'site_dn'};
    }
    sub system_command {
        my ($self, @command)=@_;
        $self->{'command'}=\@command;
        return 1;
    }
}
blurp('config/wrangler.jsonc', "{\"name\":\"docs-test\",\"compatibility_date\":\"2026-09-22\"}\n");
make_path('site-test');
my $site_dn=abs_path('site-test');
my $cloudflare_or=TestCloudflare->new({
    site_dn    => $site_dn,
    cloudflare => {
        config      => 'config/wrangler.jsonc',
        wrangler    => 'local-wrangler',
        environment => 'preview',
    }
});
is($cloudflare_or->run('cloudflare'), $site_dn, 'Cloudflare action returns built site');
is_deeply($cloudflare_or->{'command'}, [
    'local-wrangler', 'deploy', '--config', abs_path('config/wrangler.jsonc'),
    '--assets', $site_dn, '--env', 'preview'
], 'Wrangler deploy receives the authored configuration and built assets');
is($cloudflare_or->{'build_count'}, 1, 'Cloudflare action builds exactly once');

my $missing_or=TestCloudflare->new({site_dn => $site_dn});
eval {$missing_or->publish_cloudflare()};
like($@, qr/configuration must be a hash reference/, 'missing Cloudflare configuration rejected');
ok(!$missing_or->{'build_count'}, 'missing configuration fails before building');
$missing_or->{'cloudflare'}={config => 'config/missing.jsonc'};
eval {$missing_or->publish_cloudflare()};
like($@, qr/Wrangler configuration not found/, 'missing Wrangler file rejected');
ok(!$missing_or->{'build_count'}, 'missing Wrangler file fails before building');
$missing_or->{'cloudflare'}={config => 'config/wrangler.jsonc'};
$missing_or->{'site_dn'}='missing-site';
eval {$missing_or->publish_cloudflare()};
like($@, qr/built site directory not found/, 'missing build output rejected');
ok(!$missing_or->{'command'}, 'missing output cannot invoke Wrangler');

chdir($cwd) || die "unable to restore cwd $cwd: $!";
done_testing();
