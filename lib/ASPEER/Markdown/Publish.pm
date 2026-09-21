#
#  This file is part of ASPEER::Markdown::Publish.
#
#  This software is copyright (c) 2026 by Andrew Speer <andrew.speer@isolutions.com.au>.
#
#  This is free software; you can redistribute it and/or modify it under
#  the same terms as the Perl 5 programming language system itself.
#
#  Full license text is available at:
#
#  <http://dev.perl.org/licenses/>
#
package ASPEER::Markdown::Publish;


#  Compiler pragma and package variables
#
use strict qw(vars);
use vars qw($VERSION $AUTHORITY);
use warnings;


#  Core and external packages
#
use Cwd qw(abs_path getcwd);
use File::Copy qw(copy);
use File::Find ();
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use IPC::Run3 qw(run3);
use JSON::PP qw(decode_json encode_json);


#  Version information
#
$AUTHORITY='cpan:ASPEER';
$VERSION='0.001';


#  Supported publication backends and actions
#
my %BACKEND=map {$_ => 1} qw(mkdocs vitepress docusaurus starlight);
my %ACTION=map {$_ => 1} qw(build serve gh_publish gh_push);


#  Done
#
1;


#======================================================================================================================

sub new {

    my ($class, $opt_hr)=@_;
    $opt_hr={} unless defined($opt_hr);
    die "publication configuration must be a hash reference\n"
        unless ref($opt_hr) eq 'HASH';
    my $self=bless({%{$opt_hr}}, $class);
    return $self;

}


sub load_config {


    #  Read a standalone JSON configuration and accept either the complete
    #  metadata extension or its publish section.
    #
    my ($class, $config_fn)=@_;
    open(my $config_fh, '<', $config_fn) ||
        die "unable to read publication configuration $config_fn: $!\n";
    local $/=undef;
    my $json=<$config_fh>;
    close($config_fh) ||
        die "unable to close publication configuration $config_fn: $!\n";
    my $config_hr=decode_json($json);
    die "publication configuration in $config_fn must be an object\n"
        unless ref($config_hr) eq 'HASH';

    if (ref($config_hr->{'x_documentation'}) eq 'HASH') {
        $config_hr=$config_hr->{'x_documentation'};
    }
    if (ref($config_hr->{'publish'}) eq 'HASH') {
        $config_hr=$config_hr->{'publish'};
    }
    return $class->new($config_hr);

}


sub backend_config {

    my ($self, $backend)=@_;
    $self->validate_backend($backend);
    my $config_hr=$self->{$backend};
    return {} unless defined($config_hr);
    die "$backend publication configuration must be a hash reference\n"
        unless ref($config_hr) eq 'HASH';
    return $config_hr;

}


sub option {

    my ($self, $backend, $name, $default)=@_;
    my $config_hr=$self->backend_config($backend);
    return $config_hr->{$name} if exists($config_hr->{$name});
    return $self->{$name} if exists($self->{$name});
    return $default;

}


sub validate_backend {

    my ($self, $backend)=@_;
    die "unknown publication backend: $backend\n"
        unless defined($backend) && $BACKEND{$backend};
    return 1;

}


sub validate_action {

    my ($self, $action)=@_;
    die "unknown publication action: $action\n"
        unless defined($action) && $ACTION{$action};
    return 1;

}


sub run {

    my ($self, $backend, $action)=@_;
    $self->validate_backend($backend);
    $self->validate_action($action);
    return $self->build($backend) if $action eq 'build';
    return $self->serve($backend) if $action eq 'serve';
    return $self->gh_publish($backend, 0) if $action eq 'gh_publish';
    return $self->gh_publish($backend, 1);

}


sub command {

    my ($self, @command)=@_;
    my ($output, $error);
    run3(\@command, \undef, \$output, \$error);
    die "command failed (@command): $error\n" if $?;
    return $output;

}


sub system_command {

    my ($self, @command)=@_;
    system(@command);
    die "command failed (@command)\n" if $?;
    return 1;

}


sub system_in_dir {

    my ($self, $dir, @command)=@_;
    my $cwd=getcwd();
    chdir($dir) || die "unable to chdir $dir: $!\n";
    my $ok=eval {$self->system_command(@command); 1};
    my $error=$@;
    chdir($cwd) || die "unable to chdir $cwd: $!\n";
    die $error unless $ok;
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


sub copy_tree {

    my ($self, $source_dn, $target_dn)=@_;
    return unless -d $source_dn;
    File::Find::find({
        no_chdir => 1,
        wanted   => sub {
            my $fn=$File::Find::name;
            return if -l $fn;
            my $relative=File::Spec->abs2rel($fn, $source_dn);
            my $output_fn=File::Spec->catfile($target_dn, $relative);
            if (-d $fn) {
                make_path($output_fn);
            }
            elsif (-f $fn) {
                copy($fn, $output_fn) || die "unable to copy $fn: $!\n";
            }
        }
    }, $source_dn);
    return 1;

}


sub source_directories {


    #  An explicit source list is exact. Without one, doc is the publication
    #  boundary whenever it exists; module sidecars are only a fallback.
    #
    my ($self)=@_;
    if (exists($self->{'sources'})) {
        die "publication sources must be an array reference\n"
            unless ref($self->{'sources'}) eq 'ARRAY';
        return [@{$self->{'sources'}}];
    }
    return ['doc'] if -d 'doc';
    my @source_dn=grep {-d $_} qw(lib bin);
    warn "doc directory not found; publishing module and executable sidecars\n"
        if @source_dn;
    return \@source_dn;

}


sub target_filename {

    my ($self, $source_dn, $fn)=@_;
    my $relative=File::Spec->abs2rel($fn, $source_dn);
    if ($source_dn eq 'lib') {
        $relative=~s/\.pm\.md$/.md/;
        $relative=~s{[/\\]}{_}g;
        return File::Spec->catfile('modules', $relative);
    }
    if ($source_dn eq 'bin') {
        return File::Spec->catfile('utilities', $relative);
    }
    return $relative;

}


sub prepare_docs {


    #  Assemble only the configured source roots into a disposable tree.
    #  Configuration directories and build products are not publication input.
    #
    my ($self)=@_;
    my $temporary_dn=abs_path(tempdir(CLEANUP => 1));
    my $docs_dn=File::Spec->catdir($temporary_dn, 'docs');
    make_path($docs_dn);
    my @pages;

    foreach my $source_dn (@{$self->source_directories()}) {
        die "publication source directory not found: $source_dn\n"
            unless -d $source_dn;
        File::Find::find({
            no_chdir   => 1,
            preprocess => sub {sort @_},
            wanted     => sub {
                my $fn=$File::Find::name;
                if (-d $fn && $fn=~m{[/\\](?:build|example|examples|mkdocs|node_modules|site|t)$}) {
                    $File::Find::prune=1;
                    return;
                }
                return unless -f $fn && !-l $fn && $fn=~/\.md$/;
                my $target_fn=$self->target_filename($source_dn, $fn);
                my $output_fn=File::Spec->catfile($docs_dn, $target_fn);
                my (undef, $parent_dn)=File::Spec->splitpath($output_fn);
                make_path($parent_dn);

                if ($source_dn eq 'doc') {
                    open(my $input_fh, '<', $fn) || die "unable to read $fn: $!\n";
                    local $/=undef;
                    my $markdown=<$input_fh>;
                    close($input_fh) || die "unable to close $fn: $!\n";
                    my $split_hr=$self->split($target_fn, $markdown);
                    if (keys(%{$split_hr}) > 1) {
                        foreach my $page (@{$self->{'page_order'}}) {
                            my $page_fn=File::Spec->catfile($docs_dn, $page);
                            $self->write_file($page_fn, $split_hr->{$page});
                            push(@pages, $page);
                        }
                        return;
                    }
                }
                copy($fn, $output_fn) || die "unable to copy $fn: $!\n";
                push(@pages, $target_fn);
            }
        }, $source_dn);
    }

    die "no Markdown documents discovered in publication sources\n" unless @pages;
    unless (-f File::Spec->catfile($docs_dn, 'index.md')) {
        my $index="# Documentation\n\n";
        $index.="- [$_]($_)\n" foreach @pages;
        $self->write_file(File::Spec->catfile($docs_dn, 'index.md'), $index);
        unshift(@pages, 'index.md');
    }

    foreach my $source_dn (@{$self->source_directories()}) {
        $self->copy_tree(File::Spec->catdir($source_dn, 'images'),
            File::Spec->catdir($docs_dn, 'images'));
        $self->copy_tree(File::Spec->catdir($source_dn, 'assets'),
            File::Spec->catdir($docs_dn, 'assets'));
    }
    return ($temporary_dn, $docs_dn, \@pages);

}


sub split {

    my ($self, $fn, $markdown)=@_;
    (my $stem=$fn)=~s/\.md$//;
    my (%pages, %anchor, %chapter_anchor, @order);
    my ($page, $fence, $length, $preamble)=('', '', 0, '');
    foreach my $line (split(/(?<=\n)/, $markdown)) {
        if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1);
            $length=length($1);
        }
        elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
            $fence='';
        }
        elsif (!$fence && $line=~/^#\s+(.+?)\s*$/) {
            my $title=$1;
            my ($id)=$title=~/\{#([^}]+)\}/;
            unless ($id) {
                $id=lc($title);
                $id=~s/[^a-z0-9]+/-/g;
                $id=~s/^-|-$//g;
            }
            die "empty or unsafe chapter ID in $fn\n"
                unless $id && $id=~/^[\w.-]+$/;
            $page="$stem--$id.md";
            die "duplicate chapter ID $id in $fn\n" if exists($pages{$page});
            $pages{$page}=$preamble;
            $preamble='';
            $chapter_anchor{$id}=1;
            push(@order, $page);
        }
        $anchor{$1}=$page if !$fence && $line=~/\{#([^}]+)\}/ && $page;
        if ($page) {
            $pages{$page}.=$line;
        }
        else {
            $preamble.=$line;
        }
    }

    foreach my $current_page (@order) {
        my $text='';
        my ($current_fence, $current_length)=('', 0);
        foreach my $line (split(/(?<=\n)/, $pages{$current_page})) {
            if (!$current_fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
                $current_fence=substr($1, 0, 1);
                $current_length=length($1);
            }
            elsif ($current_fence && $line=~/^ {0,3}\Q$current_fence\E{$current_length,}\s*$/) {
                $current_fence='';
            }
            elsif (!$current_fence) {
                foreach my $id (keys(%anchor)) {
                    my (undef, undef, $target)=File::Spec->splitpath($anchor{$id});
                    my $link=$target.($chapter_anchor{$id} ? '' : "#$id");
                    $line=~s{\]\(\#\Q$id\E\)}{]($link)}g;
                }
            }
            $text.=$line;
        }
        $pages{$current_page}=$text;
    }
    $self->{'page_order'}=\@order;
    return \%pages;

}


sub prepare_mkdocs {

    my ($self, $preview)=@_;
    my $config_fn=$self->option('mkdocs', 'config', undef);
    $config_fn='mkdocs.yml' if !defined($config_fn) && -f 'mkdocs.yml';
    if (defined($config_fn) && length($config_fn) &&
        ($self->option('mkdocs', 'config_mode', '') eq 'direct' || $config_fn eq 'mkdocs.yml')) {
        die "MkDocs configuration not found: $config_fn\n" unless -f $config_fn;
        return abs_path($config_fn);
    }
    $config_fn='doc/mkdocs/mkdocs.yml'
        if !defined($config_fn) && -f 'doc/mkdocs/mkdocs.yml';

    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $generated_fn=File::Spec->catfile($temporary_dn, 'mkdocs.yml');
    my $output_dn=File::Spec->rel2abs($self->option('mkdocs', 'output', 'site'));
    my $config='';
    if (defined($config_fn) && length($config_fn)) {
        die "MkDocs configuration not found: $config_fn\n" unless -f $config_fn;
        $config.='INHERIT: '.encode_json(abs_path($config_fn))."\n";
    }
    else {
        $config.='site_name: '.encode_json($self->option('mkdocs', 'name', 'Documentation'))."\n";
        $config.="theme:\n  name: material\n";
        $config.="markdown_extensions:\n  - admonition\n  - attr_list\n  - def_list\n  - footnotes\n  - tables\n  - pymdownx.superfences\n";
    }
    $config.='docs_dir: '.encode_json(abs_path($docs_dn))."\n";
    $config.='site_dir: '.encode_json($output_dn)."\n";
    $config.="plugins:\n  - search\n" if $preview;
    $config.="nav:\n";
    $config.='  - '.encode_json($_)."\n" foreach @{$pages_ar};
    $self->write_file($generated_fn, $config);
    return $generated_fn;

}


sub normalize_node_admonitions {

    my ($self, $markdown, $type)=@_;
    my %map=(
        vitepress => {
            note      => 'info',
            tip       => 'tip',
            warning   => 'warning',
            important => 'warning',
            caution   => 'warning'
        },
        docusaurus => {
            note      => 'note',
            tip       => 'tip',
            warning   => 'warning',
            important => 'warning',
            caution   => 'caution'
        },
        starlight => {
            note      => 'note',
            tip       => 'tip',
            warning   => 'caution',
            important => 'caution',
            caution   => 'caution'
        }
    );
    my @output;
    my @line=split(/(?<=\n)/, $markdown);
    for (my $index=0; $index<@line; $index++) {
        if ($line[$index]=~/^!!!\s+(\w+).*?\n?$/) {
            my $kind=$map{$type}{$1} || $1;
            push(@output, ":::$kind\n");
            while ($index + 1 < @line && $line[$index + 1]=~/^(?:    |\s*$)/) {
                $index++;
                my $admonition_line=$line[$index];
                $admonition_line=~s/^    //;
                push(@output, $admonition_line);
            }
            push(@output, ":::\n");
            next;
        }
        push(@output, $line[$index]);
    }
    return join('', @output);

}


sub normalize_node_definition_lists {

    my ($self, $markdown)=@_;
    my @line=split(/(?<=\n)/, $markdown);
    my @output;
    my ($fence, $length)=('', 0);
    for (my $index=0; $index<@line; $index++) {
        if (!$fence && $line[$index]=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1);
            $length=length($1);
        }
        elsif ($fence && $line[$index]=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
            $fence='';
        }

        #  Pandoc definition lists are not portable to the Node renderers.
        #  Their two-space continuation indent is also the content indent for
        #  the equivalent CommonMark list item, so the remaining block can be
        #  retained verbatim.
        #
        if (!$fence && $index + 2 < @line && $line[$index]!~/^\s*$/ &&
            $line[$index + 1]=~/^\s*$/ && $line[$index + 2]=~/^:\s+(.*)$/) {
            my $term=$line[$index];
            my $description=$1;
            my $newline=$line[$index + 2]=~/\n\z/ ? "\n" : '';
            $term=~s/\r?\n\z//;
            $description=~s/\r?\n\z//;
            push(@output, "- **$term**\n\n  $description$newline");
            $index+=2;
            next;
        }
        push(@output, $line[$index]);
    }
    return join('', @output);

}


sub normalize_node_attributes {

    my ($self, $markdown, $type)=@_;
    my @output;
    my ($fence, $length)=('', 0);
    foreach my $line (split(/(?<=\n)/, $markdown)) {
        if ($fence) {
            if ($line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
                $fence='';
            }
            push(@output, $line);
            next;
        }

        #  Retain an authored code-block ID as an adjacent HTML anchor and
        #  pass its first class as the conventional fenced-code language.
        #
        if ($line=~/^( {0,3})(`{3,}|~{3,})[ \t]*\{([^}\r\n]+)\}[ \t]*(\r?\n)?$/) {
            my ($indent, $delimiter, $attributes, $newline)=($1, $2, $3, $4 || '');
            my ($id)=$attributes=~/(?:^|\s)#([\w.-]+)/;
            my ($language)=$attributes=~/(?:^|\s)\.([\w+-]+)/;
            push(@output, "$indent<a id=\"$id\"></a>$newline") if defined($id);
            push(@output, $indent.$delimiter.(defined($language) ? $language : '').$newline);
            $fence=substr($delimiter, 0, 1);
            $length=length($delimiter);
            next;
        }
        if ($line=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1);
            $length=length($1);
            push(@output, $line);
            next;
        }

        #  Docusaurus and Starlight do not accept Pandoc heading attributes.
        #  A raw anchor preserves the stable identifiers used by split links.
        #
        if (($type eq 'docusaurus' || $type eq 'starlight') &&
            $line=~/^( {0,3})(#{1,6}[^\r\n]*?)\s+\{#([\w.-]+)(?:\s+[^}]*)?\}[ \t]*(\r?\n)?$/) {
            push(@output, "$1<a id=\"$3\"></a>".($4 || '').$1.$2.($4 || ''));
            next;
        }

        #  Attribute blocks on inline links and images otherwise become
        #  visible text in one or more of the Node renderers.
        #
        $line=~s{((?:!)?\[[^\]]*\]\([^\)\r\n]+\))\{[^\}\r\n]+\}}{$1}g;
        push(@output, $line);
    }
    return join('', @output);

}


sub starlight_title_heading {

    my ($self, $markdown)=@_;
    my @output;
    my ($fence, $length, $frontmatter, $removed)=('', 0, 0, 0);
    my $index=0;
    foreach my $line (split(/(?<=\n)/, $markdown)) {
        if (!$index && $line=~/^---[ \t]*\r?\n?$/) {
            $frontmatter=1;
            push(@output, $line);
            $index++;
            next;
        }
        if ($frontmatter) {
            $frontmatter=0 if $line=~/^---[ \t]*\r?\n?$/;
            push(@output, $line);
            $index++;
            next;
        }
        if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
            $fence=substr($1, 0, 1);
            $length=length($1);
        }
        elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
            $fence='';
        }
        elsif (!$fence && !$removed && $line=~/^#\s+(.+?)[ \t]*(\r?\n)?$/) {
            my ($title, $newline)=($1, $2 || '');
            my ($id)=$title=~/\s+\{#([\w.-]+)(?:\s+[^}]*)?\}\s*$/;
            unless (defined($id)) {
                $id=lc($title);
                $id=~s/[^a-z0-9]+/-/g;
                $id=~s/^-|-$//g;
            }
            push(@output, "<a id=\"$id\"></a>$newline") if length($id);
            $removed=1;
            $index++;
            next;
        }
        push(@output, $line);
        $index++;
    }
    return join('', @output);

}


sub markdown_title {

    my ($self, $fn, $markdown)=@_;
    my $title;

    #  Prefer authored frontmatter, accepting the simple quoted and unquoted
    #  title forms used by the supported documentation engines.
    #
    if ($markdown=~/\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?\n/ms) {
        my $frontmatter=$1;
        ($title)=$frontmatter=~/^title:[ \t]*(.*?)[ \t]*\r?$/m;
        if (defined($title) && $title=~/\A"/) {
            my $decoded=eval {decode_json($title)};
            $title=$decoded if defined($decoded) && !ref($decoded);
        }
        elsif (defined($title) && $title=~/\A'(.*)'\z/s) {
            $title=$1;
            $title=~s/''/'/g;
        }
    }

    #  Otherwise use the first level-one heading outside a fenced example.
    #
    unless (defined($title) && length($title)) {
        my ($fence, $length)=('', 0);
        foreach my $line (split(/(?<=\n)/, $markdown)) {
            if (!$fence && $line=~/^ {0,3}(`{3,}|~{3,})/) {
                $fence=substr($1, 0, 1);
                $length=length($1);
            }
            elsif ($fence && $line=~/^ {0,3}\Q$fence\E{$length,}\s*$/) {
                $fence='';
            }
            elsif (!$fence && $line=~/^#\s+(.+?)\s*$/) {
                $title=$1;
                last;
            }
        }
    }

    #  A filename-derived label is a last resort for headingless documents.
    #
    unless (defined($title) && length($title)) {
        (undef, undef, $title)=File::Spec->splitpath($fn);
        $title=~s/\.md$//;
        $title=~s/[-_]+/ /g;
        $title=join(' ', map {ucfirst($_)} split(/\s+/, $title));
    }
    $title=~s/\s+\{#[^}]+\}\s*$//;
    return $title;

}


sub title_frontmatter {

    my ($self, $fn, $markdown)=@_;
    my $title=$self->markdown_title($fn, $markdown);
    if ($markdown=~/\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?\n/ms) {
        my $frontmatter=$1;
        return $markdown if $frontmatter=~/^title:[ \t]*/m;
        my $title_line='title: '.encode_json($title)."\n";
        $markdown=~s/\A(---[ \t]*\r?\n)/$1$title_line/;
        return $markdown;
    }
    return "---\ntitle: ".encode_json($title)."\n---\n\n$markdown";

}


sub navigation {

    my ($self, $docs_dn, $pages_ar)=@_;
    my @navigation;
    foreach my $page (@{$pages_ar}) {
        my $fn=File::Spec->catfile($docs_dn, $page);
        open(my $input_fh, '<', $fn) || die "unable to read $fn: $!\n";
        local $/=undef;
        my $markdown=<$input_fh>;
        close($input_fh) || die "unable to close $fn: $!\n";
        (my $id=$page)=~s/\.md$//;
        $id=~s{\\}{/}g;
        push(@navigation, {
            file  => $page,
            id    => $id,
            title => $self->markdown_title($page, $markdown)
        });
    }
    return \@navigation;

}


sub normalize_node_markdown {

    my ($self, $source_dn, $type)=@_;
    File::Find::find({
        no_chdir => 1,
        wanted   => sub {
            my $fn=$File::Find::name;
            return unless -f $fn && $fn=~/\.md$/;
            open(my $input_fh, '<', $fn) || die "unable to read $fn: $!\n";
            local $/=undef;
            my $markdown=<$input_fh>;
            close($input_fh) || die "unable to close $fn: $!\n";
            $markdown=$self->normalize_node_definition_lists($markdown);
            $markdown=$self->title_frontmatter($fn, $markdown)
                if $type eq 'docusaurus' || $type eq 'starlight';
            $markdown=$self->starlight_title_heading($markdown)
                if $type eq 'starlight';
            $markdown=$self->normalize_node_attributes($markdown, $type);
            $markdown=$self->normalize_node_admonitions($markdown, $type);
            $self->write_file($fn, $markdown);
        }
    }, $source_dn);
    return 1;

}


sub prepare_vitepress {

    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $navigation_ar=$self->navigation($docs_dn, $pages_ar);
    $self->normalize_node_markdown($docs_dn, 'vitepress');
    my $version=$self->option('vitepress', 'version', 'latest');
    my $package_hr={
        type         => 'module',
        dependencies => {vitepress => $version}
    };
    $self->write_file(File::Spec->catfile($temporary_dn, 'package.json'),
        encode_json($package_hr));
    my $config_dn=File::Spec->catdir($docs_dn, '.vitepress');
    make_path($config_dn);
    my $config_fn=$self->option('vitepress', 'config', undef);
    my $prepared_config_fn;
    if (defined($config_fn) && length($config_fn)) {
        die "VitePress configuration not found: $config_fn\n" unless -f $config_fn;
        $prepared_config_fn=abs_path($config_fn);
    }
    else {
        my @items=map {
            my $link=$_->{'id'} eq 'index' ? '/' : '/'.$_->{'id'};
            "          { text: ".encode_json($_->{'title'}).
                ", link: ".encode_json($link)." }"
        } @{$navigation_ar};
        my $config="export default {\n  title: ".
            encode_json($self->option('vitepress', 'name', 'Documentation')).
            ",\n  themeConfig: {\n    sidebar: [\n".
            join(",\n", @items)."\n    ]\n  }\n};\n";
        $prepared_config_fn=File::Spec->catfile($config_dn, 'config.mts');
        $self->write_file($prepared_config_fn, $config);
    }
    return ($temporary_dn, $docs_dn, $prepared_config_fn);

}


sub prepare_docusaurus {

    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $navigation_ar=$self->navigation($docs_dn, $pages_ar);
    my $site_dn=File::Spec->catdir($temporary_dn, 'docusaurus');
    my $site_docs_dn=File::Spec->catdir($site_dn, 'docs');
    make_path($site_docs_dn);
    $self->copy_tree($docs_dn, $site_docs_dn);
    $self->normalize_node_markdown($site_docs_dn, 'docusaurus');
    my @items=map {{
        type  => 'doc',
        id    => $_->{'id'},
        label => $_->{'title'}
    }} @{$navigation_ar};
    my $version=$self->option('docusaurus', 'version', 'latest');
    my $package_hr={
        scripts      => {
            build => 'docusaurus build',
            start => 'docusaurus start --no-open'
        },
        dependencies => {
            '@docusaurus/core'           => $version,
            '@docusaurus/preset-classic' => $version
        }
    };
    $self->write_file(File::Spec->catfile($site_dn, 'package.json'), encode_json($package_hr));
    my $config_fn=$self->option('docusaurus', 'config', undef);
    my $prepared_config_fn;
    if (defined($config_fn) && length($config_fn)) {
        die "Docusaurus configuration not found: $config_fn\n" unless -f $config_fn;
        $prepared_config_fn=abs_path($config_fn);
    }
    else {
        my $config="module.exports = {\n  title: ".
            encode_json($self->option('docusaurus', 'name', 'Documentation')).
            ",\n  url: 'http://localhost',\n  baseUrl: '/',\n  onBrokenLinks: 'warn',\n".
            "  markdown: { format: 'detect' },\n".
            "  presets: [['classic', { docs: { routeBasePath: '/', sidebarPath: require.resolve('./sidebars.js') }, blog: false }]],\n};\n";
        $prepared_config_fn=File::Spec->catfile($site_dn, 'docusaurus.config.js');
        $self->write_file($prepared_config_fn, $config);
    }
    $self->write_file(File::Spec->catfile($site_dn, 'sidebars.js'),
        "module.exports = { docs: ".encode_json(\@items)." };\n");
    return ($temporary_dn, $site_dn, $prepared_config_fn);

}


sub prepare_starlight {

    my ($self)=@_;
    my ($temporary_dn, $docs_dn, $pages_ar)=$self->prepare_docs();
    my $navigation_ar=$self->navigation($docs_dn, $pages_ar);
    my $site_dn=File::Spec->catdir($temporary_dn, 'starlight');
    my $site_docs_dn=File::Spec->catdir($site_dn, 'src', 'content', 'docs');
    make_path($site_docs_dn);
    $self->copy_tree($docs_dn, $site_docs_dn);
    $self->normalize_node_markdown($site_docs_dn, 'starlight');
    my $astro_version=$self->option('starlight', 'astro_version', 'latest');
    my $starlight_version=$self->option('starlight', 'starlight_version', 'latest');
    my $package_hr={
        type         => 'module',
        scripts      => {build => 'astro build', start => 'astro dev'},
        dependencies => {astro => $astro_version, '@astrojs/starlight' => $starlight_version}
    };
    $self->write_file(File::Spec->catfile($site_dn, 'package.json'), encode_json($package_hr));
    my $config_fn=$self->option('starlight', 'config', undef);
    my $prepared_config_fn;
    if (defined($config_fn) && length($config_fn)) {
        die "Starlight configuration not found: $config_fn\n" unless -f $config_fn;
        $prepared_config_fn=abs_path($config_fn);
    }
    else {
        my @items=map {
            "      { label: ".encode_json($_->{'title'}).
                ", slug: ".encode_json($_->{'id'})." }"
        } @{$navigation_ar};
        my $config="import { defineConfig } from 'astro/config';\n".
            "import starlight from '\@astrojs/starlight';\n\n".
            "export default defineConfig({\n  integrations: [starlight({\n    title: ".
            encode_json($self->option('starlight', 'name', 'Documentation')).
            ",\n    sidebar: [{ label: 'Docs', items: [\n".
            join(",\n", @items)."\n    ] }]\n  })]\n});\n";
        $prepared_config_fn=File::Spec->catfile($site_dn, 'astro.config.mjs');
        $self->write_file($prepared_config_fn, $config);
    }
    $self->write_file(File::Spec->catfile($site_dn, 'src', 'content.config.ts'),
        "import { defineCollection } from 'astro:content';\n".
        "import { glob } from 'astro/loaders';\n".
        "import { docsSchema } from '\@astrojs/starlight/schema';\n\n".
        "export const collections = { docs: defineCollection({ loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/docs' }), schema: docsSchema() }) };\n");
    return ($temporary_dn, $site_dn, $prepared_config_fn);

}


sub npm_install {

    my ($self, $backend, $site_dn)=@_;
    my $npm=$self->option($backend, 'npm', 'npm');
    $self->system_in_dir($site_dn, $npm, 'install', '--silent');
    return 1;

}


sub build {

    my ($self, $backend)=@_;
    $self->validate_backend($backend);
    my $output_dn=File::Spec->rel2abs($self->option($backend, 'output', 'site'));
    if ($backend eq 'mkdocs') {
        my $config_fn=$self->prepare_mkdocs(0);
        my @command=($self->option('mkdocs', 'command', 'mkdocs'), 'build');
        push(@command, '--strict') if $self->option('mkdocs', 'strict', 1);
        push(@command, '-f', $config_fn, '--site-dir', $output_dn);
        $self->command(@command);
    }
    elsif ($backend eq 'vitepress') {
        my ($temporary_dn, $docs_dn, $config_fn)=$self->prepare_vitepress();
        $self->npm_install('vitepress', $temporary_dn);
        $self->system_in_dir($temporary_dn, $self->option('vitepress', 'npm', 'npm'),
            'exec', '--', 'vitepress', 'build', $docs_dn, '--config', $config_fn,
            '--outDir', $output_dn);
    }
    elsif ($backend eq 'docusaurus') {
        my (undef, $site_dn, $config_fn)=$self->prepare_docusaurus();
        $self->npm_install('docusaurus', $site_dn);
        $self->system_in_dir($site_dn, $self->option('docusaurus', 'npm', 'npm'),
            'run', 'build', '--', '--config', $config_fn, '--out-dir', $output_dn);
    }
    else {
        my (undef, $site_dn, $config_fn)=$self->prepare_starlight();
        my $config_arg=File::Spec->abs2rel($config_fn, $site_dn);
        $config_arg=$config_fn if $config_arg=~m{^\.\.[/\\]};
        $self->npm_install('starlight', $site_dn);
        $self->system_in_dir($site_dn, $self->option('starlight', 'npm', 'npm'),
            'run', 'build', '--', '--config', $config_arg, '--outDir', $output_dn);
    }
    return $output_dn;

}


sub serve {

    my ($self, $backend)=@_;
    $self->validate_backend($backend);
    if ($backend eq 'mkdocs') {
        my $config_fn=$self->prepare_mkdocs(1);
        my @command=($self->option('mkdocs', 'command', 'mkdocs'), 'serve', '-f', $config_fn);
        my $address=$self->option('mkdocs', 'address', undef);
        push(@command, '-a', $address) if defined($address) && length($address);
        $self->system_command(@command);
    }
    elsif ($backend eq 'vitepress') {
        my ($temporary_dn, $docs_dn, $config_fn)=$self->prepare_vitepress();
        $self->npm_install('vitepress', $temporary_dn);
        $self->system_in_dir($temporary_dn, $self->option('vitepress', 'npm', 'npm'),
            'exec', '--', 'vitepress', 'dev', $docs_dn, '--config', $config_fn,
            '--host', $self->option('vitepress', 'host', '127.0.0.1'),
            '--port', $self->option('vitepress', 'port', 5173));
    }
    elsif ($backend eq 'docusaurus') {
        my (undef, $site_dn, $config_fn)=$self->prepare_docusaurus();
        $self->npm_install('docusaurus', $site_dn);
        $self->system_in_dir($site_dn, $self->option('docusaurus', 'npm', 'npm'),
            'run', 'start', '--', '--config', $config_fn,
            '--host', $self->option('docusaurus', 'host', '127.0.0.1'),
            '--port', $self->option('docusaurus', 'port', 3001));
    }
    else {
        my (undef, $site_dn, $config_fn)=$self->prepare_starlight();
        my $config_arg=File::Spec->abs2rel($config_fn, $site_dn);
        $config_arg=$config_fn if $config_arg=~m{^\.\.[/\\]};
        $self->npm_install('starlight', $site_dn);
        local $ENV{'ASTRO_DEV_BACKGROUND'}=0;
        $self->system_in_dir($site_dn, $self->option('starlight', 'npm', 'npm'),
            'run', 'start', '--', '--config', $config_arg,
            '--host', $self->option('starlight', 'host', '127.0.0.1'),
            '--port', $self->option('starlight', 'port', 4321));
    }
    return 1;

}


sub gh_publish {


    #  Build first, then replace only the disposable publication worktree.
    #  A remote update is performed solely for the explicit gh_push action.
    #
    my ($self, $backend, $push)=@_;
    $self->validate_backend($backend);
    my $site_dn=$self->build($backend);
    my $branch=$self->option($backend, 'branch', 'gh-pages');
    my $remote=$self->option($backend, 'remote', 'origin');
    $self->command('git', 'check-ref-format', '--branch', $branch);
    my $temporary_dn=abs_path(tempdir(CLEANUP => 1));
    my $work_dn=File::Spec->catdir($temporary_dn, 'pages');
    my $exists=eval {
        $self->command('git', 'rev-parse', '--verify', "refs/heads/$branch");
        1;
    };
    $self->command('git', 'worktree', 'add', ($exists ? () : '--detach'), $work_dn,
        $exists ? $branch : 'HEAD');
    my $ok=eval {
        $self->command('git', '-C', $work_dn, 'checkout', '--orphan', $branch)
            unless $exists;
        $self->command('git', '-C', $work_dn, 'rm', '-r', '-f', '--ignore-unmatch', '.');
        $self->copy_tree($site_dn, $work_dn);
        $self->write_file(File::Spec->catfile($work_dn, '.nojekyll'), '');
        $self->command('git', '-C', $work_dn, 'add', '.');
        my $changed=$exists ?
            length($self->command('git', '-C', $work_dn, 'diff', '--cached', '--name-only')) : 1;
        $self->command('git', '-C', $work_dn, 'commit', '-m', 'Update documentation')
            if $changed;
        1;
    };
    my $error=$@;
    $self->command('git', 'worktree', 'remove', '--force', $work_dn);
    die $error unless $ok;
    $self->command('git', 'push', $remote, $branch) if $push;
    return $branch;

}


__END__

=begin markdown

# NAME

ASPEER::Markdown::Publish - publish Perl distribution documentation with multiple site generators

# SYNOPSIS

```perl
use ASPEER::Markdown::Publish;

my $publish_or=ASPEER::Markdown::Publish->new({
    sources => ['doc'],
    mkdocs  => {
        config => 'doc/mkdocs/mkdocs.yml',
        output => 'site',
    },
});

$publish_or->run('mkdocs', 'build');
$publish_or->run('mkdocs', 'serve');
$publish_or->run('mkdocs', 'gh_publish');
```

# DESCRIPTION

`ASPEER::Markdown::Publish` assembles Markdown documentation from a Perl
distribution and delegates rendering to MkDocs, VitePress, Docusaurus, or
Astro Starlight. It has no MakeMaker dependency. The companion
`ASPEER::MakeMaker::Markdown::Publish` module supplies Makefile targets and
passes `META_MERGE.x_documentation.publish` configuration to this module.

When `sources` is omitted, an existing `doc/` directory is the publication
boundary. If `doc/` does not exist, `lib/` and `bin/` Markdown sidecars are used
as a compatibility fallback. An existing but empty `doc/` directory does not
fall back. An explicit source list is exact:

```perl
sources => [qw(doc lib bin)]
```

Multiple top-level headings in documents beneath `doc/` are split into stable
pages. Explicit anchors and links between split chapters are preserved.
For the Node-backed generators, Pandoc definition lists and attribute syntax
are converted to portable Markdown and HTML equivalents in the disposable
publication tree. Authored source documents are not changed.

# CONFIGURATION

Common settings may be placed directly in the constructor hash. A backend hash
overrides the corresponding common value:

```perl
{
    sources => ['doc'],
    name    => 'Example documentation',
    output  => 'site',
    branch  => 'gh-pages',
    remote  => 'origin',

    mkdocs => {
        config      => 'doc/mkdocs/mkdocs.yml',
        config_mode => 'inherit',
        command     => 'mkdocs',
        strict      => 1,
        address     => '127.0.0.1:8000',
    },

    vitepress => {
        config => 'doc/vitepress/config.mts',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 5173,
        version => 'latest',
    },

    docusaurus => {
        config => 'doc/docusaurus/docusaurus.config.js',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 3001,
        version => 'latest',
    },

    starlight => {
        config => 'doc/starlight/astro.config.mjs',
        npm    => 'npm',
        host   => '127.0.0.1',
        port   => 4321,
        astro_version     => 'latest',
        starlight_version => 'latest',
    },
}
```

A root `mkdocs.yml` is used directly because it owns its complete source-tree
layout. Other MkDocs configuration paths are inherited by a temporary child
configuration which supplies the assembled documentation, navigation, and
output directory. Set `config_mode` to `direct` when a non-root configuration
also owns its complete layout.

`load_config($filename)` reads JSON in any of these forms:

```json
{"sources":["doc"]}
```

```json
{"publish":{"sources":["doc"]}}
```

```json
{"x_documentation":{"publish":{"sources":["doc"]}}}
```

# METHODS

## new

Creates a publisher from a configuration hash reference.

## load_config

Creates a publisher from a standalone JSON file.

## run

```perl
$publish_or->run($backend, $action);
```

Supported backends are `mkdocs`, `vitepress`, `docusaurus`, and `starlight`.
Supported actions are:

- `build`: render the static site.
- `serve`: run the backend's foreground preview server.
- `gh_publish`: build and commit the result to a local publication branch.
- `gh_push`: perform `gh_publish`, then push the selected branch to the selected
  remote.

Remote publication is never implicit.

## source_directories

Returns the exact configured publication roots or the default roots selected by
the `doc/` boundary rule.

## prepare_docs

Assembles source Markdown and assets in a temporary directory. It returns the
temporary root, assembled documentation directory, and ordered page list.

## split

Splits a Markdown guide at top-level ATX headings, ignoring fenced examples,
and repairs links to explicit anchors moved to another generated page.

## prepare_mkdocs

Returns a MkDocs configuration filename, generating a temporary configuration
when assembly or inheritance is required.

## prepare_vitepress

Returns a temporary root, prepared VitePress documentation directory, and
configuration filename. An authored configuration remains at its original
location so its relative imports continue to resolve correctly. Generated
navigation uses each page's authored title and preserves source order.

## prepare_docusaurus

Returns a temporary root, prepared Docusaurus project directory, and
configuration filename. Generated pages receive explicit title frontmatter and
the sidebar preserves authored titles and source order.

## prepare_starlight

Returns a temporary root, prepared Astro Starlight project directory, and
configuration filename. Generated navigation lists every page explicitly so
root documents retain their authored titles and source order.

## build

Builds one supported backend and returns the absolute output directory.

## serve

Starts one supported backend's foreground development server.

## gh_publish

Builds a backend, updates a local publication branch through a temporary Git
worktree, and optionally pushes when its second argument is true. Callers should
normally use `run()` so local publication and explicit push remain distinct.

# ERRORS

Invalid configuration, missing source/configuration files, failed external
commands, unsafe chapter identifiers, and Git failures are fatal.

# SEE ALSO

`ASPEER::MakeMaker::Markdown::Publish`, `ASPEER::MakeMaker::Markdown::Pod`

# AUTHOR

Andrew Speer <andrew.speer@isolutions.com.au>

# LICENSE AND COPYRIGHT

This file is part of ASPEER::Markdown::Publish.

This software is copyright (c) 2026 by Andrew Speer
<andrew.speer@isolutions.com.au>.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=end markdown


=head1 NAME

ASPEER::Markdown::Publish - publish Perl distribution documentation with multiple site generators


=head1 SYNOPSIS


 use ASPEER::Markdown::Publish;

 my $publish_or=ASPEER::Markdown::Publish->new({
     sources => ['doc'],
     mkdocs  => {
         config => 'doc/mkdocs/mkdocs.yml',
         output => 'site',
     },
 });

 $publish_or->run('mkdocs', 'build');
 $publish_or->run('mkdocs', 'serve');
 $publish_or->run('mkdocs', 'gh_publish');

=head1 DESCRIPTION

C<ASPEER::Markdown::Publish> assembles Markdown documentation from a Perl
distribution and delegates rendering to MkDocs, VitePress, Docusaurus, or
Astro Starlight. It has no MakeMaker dependency. The companion
C<ASPEER::MakeMaker::Markdown::Publish> module supplies Makefile targets and
passes C<META_MERGE.x_documentation.publish> configuration to this module.

When C<sources> is omitted, an existing C<doc/> directory is the publication
boundary. If C<doc/> does not exist, C<lib/> and C<bin/> Markdown sidecars are used
as a compatibility fallback. An existing but empty C<doc/> directory does not
fall back. An explicit source list is exact:


 sources => [qw(doc lib bin)]
Multiple top-level headings in documents beneath C<doc/> are split into stable
pages. Explicit anchors and links between split chapters are preserved.
For the Node-backed generators, Pandoc definition lists and attribute syntax
are converted to portable Markdown and HTML equivalents in the disposable
publication tree. Authored source documents are not changed.


=head1 CONFIGURATION

Common settings may be placed directly in the constructor hash. A backend hash
overrides the corresponding common value:


 {
     sources => ['doc'],
     name    => 'Example documentation',
     output  => 'site',
     branch  => 'gh-pages',
     remote  => 'origin',

     mkdocs => {
         config      => 'doc/mkdocs/mkdocs.yml',
         config_mode => 'inherit',
         command     => 'mkdocs',
         strict      => 1,
         address     => '127.0.0.1:8000',
     },

     vitepress => {
         config => 'doc/vitepress/config.mts',
         npm    => 'npm',
         host   => '127.0.0.1',
         port   => 5173,
         version => 'latest',
     },

     docusaurus => {
         config => 'doc/docusaurus/docusaurus.config.js',
         npm    => 'npm',
         host   => '127.0.0.1',
         port   => 3001,
         version => 'latest',
     },

     starlight => {
         config => 'doc/starlight/astro.config.mjs',
         npm    => 'npm',
         host   => '127.0.0.1',
         port   => 4321,
         astro_version     => 'latest',
         starlight_version => 'latest',
     },
 }
A root C<mkdocs.yml> is used directly because it owns its complete source-tree
layout. Other MkDocs configuration paths are inherited by a temporary child
configuration which supplies the assembled documentation, navigation, and
output directory. Set C<config_mode> to C<direct> when a non-root configuration
also owns its complete layout.

C<load_config($filename)> reads JSON in any of these forms:


 {"sources":["doc"]}

 {"publish":{"sources":["doc"]}}

 {"x_documentation":{"publish":{"sources":["doc"]}}}

=head1 METHODS


=head2 new

Creates a publisher from a configuration hash reference.


=head2 load_config

Creates a publisher from a standalone JSON file.


=head2 run


 $publish_or->run($backend, $action);
Supported backends are C<mkdocs>, C<vitepress>, C<docusaurus>, and C<starlight>.
Supported actions are:

=over

=item -

C<build>: render the static site.


=item -

C<serve>: run the backend's foreground preview server.


=item -

C<gh_publish>: build and commit the result to a local publication branch.


=item -

C<gh_push>: perform C<gh_publish>, then push the selected branch to the selected
  remote.


=back

Remote publication is never implicit.


=head2 source_directories

Returns the exact configured publication roots or the default roots selected by
the C<doc/> boundary rule.


=head2 prepare_docs

Assembles source Markdown and assets in a temporary directory. It returns the
temporary root, assembled documentation directory, and ordered page list.


=head2 split

Splits a Markdown guide at top-level ATX headings, ignoring fenced examples,
and repairs links to explicit anchors moved to another generated page.


=head2 prepare_mkdocs

Returns a MkDocs configuration filename, generating a temporary configuration
when assembly or inheritance is required.


=head2 prepare_vitepress

Returns a temporary root, prepared VitePress documentation directory, and
configuration filename. An authored configuration remains at its original
location so its relative imports continue to resolve correctly. Generated
navigation uses each page's authored title and preserves source order.


=head2 prepare_docusaurus

Returns a temporary root, prepared Docusaurus project directory, and
configuration filename. Generated pages receive explicit title frontmatter and
the sidebar preserves authored titles and source order.


=head2 prepare_starlight

Returns a temporary root, prepared Astro Starlight project directory, and
configuration filename. Generated navigation lists every page explicitly so
root documents retain their authored titles and source order.


=head2 build

Builds one supported backend and returns the absolute output directory.


=head2 serve

Starts one supported backend's foreground development server.


=head2 gh_publish

Builds a backend, updates a local publication branch through a temporary Git
worktree, and optionally pushes when its second argument is true. Callers should
normally use C<run()> so local publication and explicit push remain distinct.


=head1 ERRORS

Invalid configuration, missing source/configuration files, failed external
commands, unsafe chapter identifiers, and Git failures are fatal.


=head1 SEE ALSO

C<ASPEER::MakeMaker::Markdown::Publish>, C<ASPEER::MakeMaker::Markdown::Pod>


=head1 AUTHOR

Andrew Speer L<mailto:andrew.speer@isolutions.com.au>


=head1 LICENSE AND COPYRIGHT

This file is part of ASPEER::Markdown::Publish.

This software is copyright (c) 2026 by Andrew Speer
L<mailto:andrew.speer@isolutions.com.au>.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
