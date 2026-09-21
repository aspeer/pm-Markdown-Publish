package Markdown::MkDocs;
use strict;
use warnings;
use File::Find ();
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);
use IPC::Run3 qw(run3);
use JSON::PP qw(encode_json);
use vars qw($VERSION);
$VERSION='0.001';

sub new {
    my ($class, $opt_hr)=@_;
    return bless({%{$opt_hr || {}}}, $class);
}

sub command {
    my ($self, @command)=@_;
    my ($output, $error);
    run3(\@command, \undef, \$output, \$error);
    die "command failed (@command): $error\n" if $?;
    return $output;
}

sub copy_tree {
    my ($self, $source_dn, $target_dn)=@_;
    return unless -d $source_dn;
    File::Find::find({no_chdir => 1, wanted => sub {
        my $fn=$File::Find::name;
        return if -l $fn;
        my $relative=File::Spec->abs2rel($fn, $source_dn);
        my $output_fn=File::Spec->catfile($target_dn, $relative);
        if (-d $fn) { make_path($output_fn) }
        elsif (-f $fn) { copy($fn, $output_fn) || die "unable to copy $fn: $!\n" }
    }}, $source_dn);
}

sub prepare_docs {
    my ($self)=@_;
    my $temporary_dn=tempdir(CLEANUP => 1);
    my $docs_dn="$temporary_dn/docs";
    make_path($docs_dn);
    my @pages;
    foreach my $source_dn ('doc', 'lib', 'bin') {
        next unless -d $source_dn;
        File::Find::find({no_chdir => 1, preprocess => sub { sort @_ }, wanted => sub {
            my $fn=$File::Find::name;
            if (-d $fn && $fn=~m{/(?:build|example|examples|mkdocs|node_modules|t)$}) {
                $File::Find::prune=1;
                return;
            }
            return unless -f $fn && !-l $fn && $fn=~/\.md$/;
            my $relative=File::Spec->abs2rel($fn, $source_dn);
            $relative=~s/\.pm\.md$/.md/;
            $relative=~s{/}{_}g if $source_dn eq 'lib';
            my $prefix=$source_dn eq 'doc' ? '' : $source_dn eq 'lib' ? 'modules/' : 'utilities/';
            my $target_fn="$docs_dn/$prefix$relative";
            my (undef, $parent_dn)=File::Spec->splitpath($target_fn);
            make_path($parent_dn);
            if ($source_dn eq 'doc') {
                open(my $input_fh, '<', $fn) || die "unable to read $fn: $!\n";
                local $/;
                my $markdown=<$input_fh>;
                close($input_fh);
                my $split_hr=$self->split($relative, $markdown);
                if (keys %{$split_hr} > 1) {
                    foreach my $page (@{$self->{'page_order'}}) {
                        open(my $page_fh, '>', "$docs_dn/$page") || die "unable to write $page: $!\n";
                        print {$page_fh} $split_hr->{$page};
                        close($page_fh) || die "unable to close $page: $!\n";
                        push @pages, $page;
                    }
                }
                else {
                    copy($fn, $target_fn) || die "unable to copy $fn: $!\n";
                    push @pages, "$prefix$relative";
                }
            }
            else {
                copy($fn, $target_fn) || die "unable to copy $fn: $!\n";
                push @pages, "$prefix$relative";
            }
        }}, $source_dn);
    }
    die "no Markdown documents discovered\n" unless @pages;
    unless (-f "$docs_dn/index.md") {
        open(my $index_fh, '>', "$docs_dn/index.md") || die "unable to write site index: $!\n";
        print {$index_fh} "# Documentation\n\n";
        print {$index_fh} "- [$_]($_)\n" foreach @pages;
        close($index_fh) || die "unable to close site index: $!\n";
        unshift @pages, 'index.md';
    }
    $self->copy_tree('doc/images', "$docs_dn/images");
    $self->copy_tree('doc/assets', "$docs_dn/assets");
    return ($temporary_dn, $docs_dn, \@pages);
}

sub prepare {
    my ($self)=@_;
    #  Preserve project-authored relative paths when a MkDocs tree exists.
    if (-f 'mkdocs.yml') {
        return abs_path('mkdocs.yml');
    }
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $config_fn="$temporary_dn/mkdocs.yml";
    open(my $output_fh, '>', $config_fn) || die "unable to write $config_fn: $!\n";
    print {$output_fh} 'site_name: ', encode_json($self->{'name'} || 'Documentation'), "\n";
    print {$output_fh} "theme:\n  name: material\n";
    print {$output_fh} "markdown_extensions:\n  - admonition\n  - attr_list\n  - def_list\n  - footnotes\n  - tables\n  - pymdownx.superfences\n";
    print {$output_fh} 'docs_dir: ', encode_json(abs_path($docs_dn)), "\n";
    print {$output_fh} 'site_dir: ', encode_json(File::Spec->rel2abs('site')), "\n";
    print {$output_fh} "nav:\n";
    print {$output_fh} '  - ', encode_json($_), "\n" foreach @{$pages_ar};
    close($output_fh) || die "unable to close $config_fn: $!\n";
    return $config_fn;
}


sub prepare_preview {

    my ($self)=@_;


    #  A root configuration already owns its complete source-tree layout
    #
    return abs_path('mkdocs.yml') if -f 'mkdocs.yml';


    #  Apply a project presentation configuration to the assembled preview
    #
    my $project_config_fn='doc/mkdocs/mkdocs.yml';
    return $self->prepare() unless -f $project_config_fn;
    $project_config_fn=abs_path($project_config_fn);
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $config_fn="$temporary_dn/mkdocs.yml";
    open(my $output_fh, '>', $config_fn) || die "unable to write $config_fn: $!\n";
    print {$output_fh} 'INHERIT: ', encode_json($project_config_fn), "\n";
    print {$output_fh} 'docs_dir: ', encode_json(abs_path($docs_dn)), "\n";
    print {$output_fh} 'site_dir: ', encode_json(File::Spec->rel2abs('site')), "\n";
    print {$output_fh} "plugins:\n  - search\n";
    print {$output_fh} "nav:\n";
    print {$output_fh} '  - ', encode_json($_), "\n" foreach @{$pages_ar};
    close($output_fh) || die "unable to close $config_fn: $!\n";
    return $config_fn;

}

sub split {
    my ($self, $fn, $markdown)=@_;
    (my $stem=$fn)=~s/\.md$//;
    my (%pages, %anchor, @order);
    my ($page, $fence, $length, $preamble)=('', '', 0, '');
    foreach my $line (split(/(?<=\n)/, $markdown)) {
        if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1); $length=length($1);
        }
        elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
            $fence='';
        }
        elsif (!$fence && $line=~/^#\s+(.+?)\s*$/) {
            my $title=$1;
            my ($id)=$title=~/\{#([^}]+)\}/;
            if (!$id) { $id=lc($title); $id=~s/[^a-z0-9]+/-/g; $id=~s/^-|-$//g }
            die "empty or unsafe chapter ID in $fn\n" unless $id && $id=~/^[\w.-]+$/;
            $page="$stem--$id.md";
            die "duplicate chapter ID $id in $fn\n" if exists $pages{$page};
            $pages{$page}=$preamble;
            $preamble='';
            push @order, $page;
        }
        if (!$fence && $line=~/\{#([^}]+)\}/ && $page) { $anchor{$1}=$page }
        if ($page) { $pages{$page}.=$line } else { $preamble.=$line }
    }
    foreach my $page (@order) {
        my $text='';
        my ($fence, $length)=('', 0);
        foreach my $line (split(/(?<=\n)/, $pages{$page})) {
            if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
                $fence=substr($1, 0, 1); $length=length($1);
            }
            elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) { $fence='' }
            elsif (!$fence) {
                foreach my $id (keys %anchor) {
                    my (undef, undef, $target)=File::Spec->splitpath($anchor{$id});
                    $line=~s{\]\(\#\Q$id\E\)}{]($target#$id)}g;
                }
            }
            $text.=$line;
        }
        $pages{$page}=$text;
    }
    $self->{'page_order'}=\@order;
    return \%pages;
}

sub build {
    my ($self)=@_;
    my $config_fn=$self->prepare();
    $self->command($self->{'mkdocs'} || 'mkdocs', 'build', '--strict', '-f', $config_fn,
        '--site-dir', File::Spec->rel2abs('site'));
    return File::Spec->rel2abs('site');
}

sub serve {
    my ($self)=@_;
    my $config_fn=$self->prepare_preview();
    system($self->{'mkdocs'} || 'mkdocs', 'serve', '-f', $config_fn);
    die "MkDocs preview failed\n" if $?;
}

sub system_in_dir {
    my ($self, $dir, @command)=@_;
    my $cwd=File::Spec->rel2abs('.');
    chdir($dir) || die "unable to chdir $dir: $!\n";
    system(@command);
    my $status=$?;
    chdir($cwd) || die "unable to chdir $cwd: $!\n";
    die "command failed (@command)\n" if $status;
    return 1;
}

sub write_file {
    my ($self, $fn, $text)=@_;
    my (undef, $parent_dn)=File::Spec->splitpath($fn);
    make_path($parent_dn) if length($parent_dn) && !-d $parent_dn;
    open(my $output_fh, '>', $fn) || die "unable to write $fn: $!\n";
    print {$output_fh} $text;
    close($output_fh) || die "unable to close $fn: $!\n";
    return 1;
}

sub node_command {
    my ($self, @package)=@_;
    my $npx=$self->{'npx'} || 'npx';
    return ($npx, '--yes', map { ('--package', $_) } @package);
}

sub normalize_node_markdown {
    my ($self, $source_dn, $type)=@_;
    File::Find::find({no_chdir => 1, wanted => sub {
        my $fn=$File::Find::name;
        return unless -f $fn && $fn=~/\.md$/;
        open(my $input_fh, '<', $fn) || die "unable to read $fn: $!\n";
        local $/;
        my $markdown=<$input_fh>;
        close($input_fh);
        $markdown=~s/^(#{1,6}[^\n]*?)\s+\{#[^}]+\}\s*$/$1/gm;
        $markdown=~s/(!\[[^\]]*\]\([^\)]+\))\{[^}]+\}/$1/g;
        $markdown=~s/\s+\{#[^}]+\}//g;
        $markdown=$self->normalize_node_admonitions($markdown, $type);
        $markdown=$self->astro_frontmatter($fn, $markdown) if $type eq 'astro';
        $self->write_file($fn, $markdown);
    }}, $source_dn);
    return 1;
}

sub astro_frontmatter {
    my ($self, $fn, $markdown)=@_;
    return $markdown if $markdown=~/\A---\s*\n/;
    my ($title)=$markdown=~/^#\s+(.+?)\s*$/m;
    unless ($title) {
        (undef, undef, $title)=File::Spec->splitpath($fn);
        $title=~s/\.md$//;
    }
    $title=~s/\s+\{#[^}]+\}\s*$//;
    return "---\ntitle: ".encode_json($title)."\n---\n\n$markdown";
}

sub normalize_node_admonitions {
    my ($self, $markdown, $type)=@_;
    my %map=(
        vitepress => {note => 'info', tip => 'tip', warning => 'warning', important => 'warning', caution => 'warning'},
        docusaurus => {note => 'note', tip => 'tip', warning => 'warning', important => 'warning', caution => 'warning'},
        astro => {note => 'note', tip => 'tip', warning => 'caution', important => 'caution', caution => 'caution'},
    );
    my @output;
    my @line=split(/(?<=\n)/, $markdown);
    for (my $idx=0; $idx<@line; $idx++) {
        if ($line[$idx]=~/^!!!\s+(\w+).*?\n?$/) {
            my $kind=$map{$type}{$1} || $1;
            push @output, ":::$kind\n";
            while ($idx + 1 < @line && $line[$idx + 1]=~/^(?:    |\s*$)/) {
                $idx++;
                my $admonition_line=$line[$idx];
                $admonition_line=~s/^    //;
                push @output, $admonition_line;
            }
            push @output, ":::\n";
            next;
        }
        push @output, $line[$idx];
    }
    return join('', @output);
}

sub prepare_vitepress {
    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    $self->normalize_node_markdown($docs_dn, 'vitepress');
    my $config_dn="$docs_dn/.vitepress";
    make_path($config_dn);
    my @items=map { "          { text: ".encode_json($_).", link: ".encode_json('/'.$_)." }" } @{$pages_ar};
    my $config="export default {\n  title: ".encode_json($self->{'name'} || 'Documentation').",\n  themeConfig: {\n    sidebar: [\n".join(",\n", @items)."\n    ]\n  }\n};\n";
    $self->write_file("$config_dn/config.mts", $config);
    return ($temporary_dn, $docs_dn);
}

sub serve_vitepress {
    my ($self)=@_;
    my ($temporary_dn, $docs_dn)=$self->prepare_vitepress();
    system($self->node_command('vitepress'), 'vitepress', 'dev', $docs_dn, '--host', '127.0.0.1');
    die "VitePress preview failed\n" if $?;
}

sub prepare_docusaurus {
    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $site_dn="$temporary_dn/docusaurus";
    make_path("$site_dn/docs");
    $self->copy_tree($docs_dn, "$site_dn/docs");
    $self->normalize_node_markdown("$site_dn/docs", 'docusaurus');
    my @items=map { (my $id=$_)=~s/\.md$//; $id } @{$pages_ar};
    $self->write_file("$site_dn/package.json", encode_json({scripts => {start => 'docusaurus start --host 127.0.0.1 --port 3001 --no-open'}, dependencies => {'@docusaurus/core' => 'latest', '@docusaurus/preset-classic' => 'latest'}}));
    $self->write_file("$site_dn/docusaurus.config.js", "module.exports = {\n  title: ".encode_json($self->{'name'} || 'Documentation').",\n  url: 'http://localhost',\n  baseUrl: '/',\n  onBrokenLinks: 'warn',\n  onBrokenMarkdownLinks: 'warn',\n  presets: [['classic', { docs: { sidebarPath: require.resolve('./sidebars.js') }, blog: false }]],\n};\n");
    $self->write_file("$site_dn/sidebars.js", "module.exports = { docs: ".encode_json(\@items)." };\n");
    $self->system_in_dir($site_dn, $self->{'npm'} || 'npm', 'install', '--silent');
    return ($temporary_dn, $site_dn);
}

sub serve_docusaurus {
    my ($self)=@_;
    my ($temporary_dn, $site_dn)=$self->prepare_docusaurus();
    $self->system_in_dir($site_dn, $self->{'npm'} || 'npm', 'run', 'start');
}

sub prepare_astro {
    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $site_dn="$temporary_dn/astro";
    make_path("$site_dn/src/content/docs");
    $self->copy_tree($docs_dn, "$site_dn/src/content/docs");
    $self->normalize_node_markdown("$site_dn/src/content/docs", 'astro');
    $self->write_file("$site_dn/package.json", encode_json({type => 'module', scripts => {dev => 'astro dev --host 127.0.0.1'}, dependencies => {astro => 'latest', '@astrojs/starlight' => 'latest'}}));
    $self->write_file("$site_dn/astro.config.mjs", "import { defineConfig } from 'astro/config';\nimport starlight from '\@astrojs/starlight';\n\nexport default defineConfig({\n  integrations: [starlight({\n    title: ".encode_json($self->{'name'} || 'Documentation').",\n    sidebar: [{ label: 'Docs', items: [{ autogenerate: { directory: '.' } }] }]\n  })]\n});\n");
    $self->write_file("$site_dn/src/content.config.ts", "import { defineCollection } from 'astro:content';\nimport { glob } from 'astro/loaders';\nimport { docsSchema } from '\@astrojs/starlight/schema';\n\nexport const collections = { docs: defineCollection({ loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/docs' }), schema: docsSchema() }) };\n");
    $self->system_in_dir($site_dn, $self->{'npm'} || 'npm', 'install', '--silent');
    return ($temporary_dn, $site_dn);
}

sub serve_astro {
    my ($self)=@_;
    my ($temporary_dn, $site_dn)=$self->prepare_astro();
    $self->system_in_dir($site_dn, $self->{'npm'} || 'npm', 'run', 'dev');
}

sub pages {
    my ($self)=@_;
    my $site_dn=$self->build();
    my $branch=$self->{'branch'} || 'gh-pages';
    $self->command('git', 'check-ref-format', '--branch', $branch);
    my $temporary_dn=tempdir(CLEANUP => 1);
    my $work_dn="$temporary_dn/pages";
    my $exists=eval { $self->command('git', 'rev-parse', '--verify', "refs/heads/$branch"); 1 };
    $self->command('git', 'worktree', 'add', ($exists ? () : '--detach'), $work_dn,
        $exists ? $branch : 'HEAD');
    my $ok=eval {
        $self->command('git', '-C', $work_dn, 'checkout', '--orphan', $branch) unless $exists;
        $self->command('git', '-C', $work_dn, 'rm', '-r', '-f', '--ignore-unmatch', '.');
        $self->copy_tree($site_dn, $work_dn);
        open(my $marker_fh, '>', "$work_dn/.nojekyll") || die "unable to create .nojekyll: $!\n";
        close($marker_fh);
        $self->command('git', '-C', $work_dn, 'add', '.');
        my $changed=$exists ? length($self->command('git', '-C', $work_dn, 'diff', '--cached', '--name-only')) : 1;
        $self->command('git', '-C', $work_dn, 'commit', '-m', 'Update documentation') if $changed;
        1;
    };
    my $error=$@;
    $self->command('git', 'worktree', 'remove', '--force', $work_dn);
    die $error unless $ok;
    $self->command('git', 'push', $self->{'remote'} || 'origin', $branch) if $self->{'push'};
    return $branch;
}
1;
__END__

=begin markdown

# NAME

Markdown::MkDocs - build, preview, and publish repository Markdown

# SYNOPSIS

```perl
use Markdown::MkDocs;
my $site_or=Markdown::MkDocs->new({name => 'Example'});
$site_or->build();
$site_or->pages();
```

# PUBLIC METHODS

`new(\%options)` accepts name, mkdocs (executable), branch (default gh-pages),
remote (default origin), and push (false by default).

`prepare()` returns a MkDocs configuration path. With an existing mkdocs.yml,
that configuration is returned unchanged. Otherwise a temporary source tree is
assembled from doc, lib, and bin Markdown. Generated temporary files are removed
at process exit.

`prepare_preview()` also recognises `doc/mkdocs/mkdocs.yml`. It assembles the
current Markdown into a temporary docs tree and creates a temporary
configuration inheriting the project file. The project theme, extensions and
presentation settings are retained while the generated docs directory,
navigation and built-in search plugin are selected for the local preview. A
root `mkdocs.yml` continues to own its complete source-tree layout.

`split($filename, $markdown)` returns a hash reference mapping stable page names
to Markdown. It recognises top-level ATX headings outside backtick/tilde fences,
uses explicit IDs where supplied, and rewrites explicit internal anchor links.
Duplicate chapter IDs are errors.

`build()` runs a strict MkDocs build and returns the absolute site/ directory.
`serve()` starts the foreground preview server until it is interrupted.
`pages()` builds and commits to the publication branch, optionally pushing.
An unchanged site does not create another commit. Existing branch history is
preserved. Git refuses publication if the branch is already checked out elsewhere.

Commands failing to run or returning nonzero throw exceptions. An existing
mkdocs.yml is responsible for its own navigation, hooks, and source assembly.

=end markdown


=head1 NAME

Markdown::MkDocs - build, preview, and publish repository Markdown


=head1 SYNOPSIS


 use Markdown::MkDocs;
 my $site_or=Markdown::MkDocs->new({name => 'Example'});
 $site_or->build();
 $site_or->pages();

=head1 PUBLIC METHODS

C<new(\%options)> accepts name, mkdocs (executable), branch (default gh-pages),
remote (default origin), and push (false by default).

C<prepare()> returns a MkDocs configuration path. With an existing mkdocs.yml,
that configuration is returned unchanged. Otherwise a temporary source tree is
assembled from doc, lib, and bin Markdown. Generated temporary files are removed
at process exit.

C<prepare_preview()> also recognises C<doc/mkdocs/mkdocs.yml>. It assembles the
current Markdown into a temporary docs tree and creates a temporary
configuration inheriting the project file. The project theme, extensions and
presentation settings are retained while the generated docs directory,
navigation and built-in search plugin are selected for the local preview. A
root C<mkdocs.yml> continues to own its complete source-tree layout.

C<split($filename, $markdown)> returns a hash reference mapping stable page names
to Markdown. It recognises top-level ATX headings outside backtick/tilde fences,
uses explicit IDs where supplied, and rewrites explicit internal anchor links.
Duplicate chapter IDs are errors.

C<build()> runs a strict MkDocs build and returns the absolute site/ directory.
C<serve()> starts the foreground preview server until it is interrupted.
C<pages()> builds and commits to the publication branch, optionally pushing.
An unchanged site does not create another commit. Existing branch history is
preserved. Git refuses publication if the branch is already checked out elsewhere.

Commands failing to run or returning nonzero throw exceptions. An existing
mkdocs.yml is responsible for its own navigation, hooks, and source assembly.

=cut
