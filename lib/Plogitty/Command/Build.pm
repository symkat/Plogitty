package Plogitty::Command::Build;
use oCLI::Command;
use Text::Xslate qw( mark_raw ); # Get mark_raw()
use File::Find;
use File::Basename qw( fileparse dirname );
use File::Slurper qw( write_text );
use File::Path qw( make_path remove_tree );
use File::Copy::Recursive qw(dircopy);
use XML::RSS;
use DateTime;
use CPAN::Meta::YAML;

setup build => (
    desc => 'Create Build Directory',
);

define html => (
    validate => [
        0 => [ [ sub { -e $_[2] || die "$_[2]: $!\n"; $_[2] } ], { name => "File Name", desc => "Markdown file to render in HTML." } ],
    ],
    code => sub {
        my ( $self, $c ) = @_;
        my $markdown_file = $c->req->args->[0];

        # Load up a Markdown::Compiler with this content.
        my $markdown = $c->model("Markdown")->spawn_from_file($markdown_file);

        # Store Markdown Values
        $c->stash->{markdown_vars} = $markdown->parser->metadata;
        $c->stash->{markdown_html} = $markdown->compiler_for('+Plogitty::MarkdownTarget')->result;

        # Process the markdown file into an HTML file with its Text::Xslate template.
        $c->stash->{markdown_rendered} = $c->model("Xslate")->render($c->stash->{markdown_vars}->{template}, {
            %{ $c->stash->{markdown_vars} },
            content => mark_raw($c->stash->{markdown_html}),
        });

        # Give the user back the fully rendered markdown.
        $c->stash->{text} = $c->stash->{markdown_rendered};
    },
);

define rss => (
    code => sub {
        my ( $self, $c ) = @_;

        my $plan = $self->run( qw( /quiet build:plan ) );

        my @links;
        foreach my $file ( @{$plan->stash->{files}} ) {
            my $metadata = $c->model("Markdown")->metadata_from_file($file->[-1]);

            next if $metadata->{index} and $metadata->{index} eq 'no';

            push @links, { %{$metadata}, filename => $file->[0]  };
        }

        @links = sort { $b->{weight} <=> $a->{weight} } @links;

        open my $lf, "<", 'config.yml'
            or die "Failed to read config.yml: $!";
        my $config_content = do { local $/; <$lf> };
        close $lf;

        my $data = CPAN::Meta::YAML->read_string( $config_content );


        my $build_date = DateTime->now->strftime("%a, %d %b %Y %H:%M:%S %z");
        my $rss = XML::RSS->new( version => '2.0' );
        $rss->channel(
            title         => $data->[0]{title},
            link          => $data->[0]{link},
            language      => $data->[0]{language},
            description   => $data->[0]{description},
            pubDate       => $build_date,
            lastBuildDate => $build_date,
        );

        foreach my $link ( @links ) {

            my $date;
            if ( $link->{date} =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
                $date = DateTime->new(
                    year  => $1,
                    month => $2,
                    day   => $3,
                )->strftime( "%a, %d %b %Y %H:%M:%S %z" );
            }

            $rss->add_item(
                title     => $link->{title},
                permaLink => $data->[0]{link} . $link->{slug} . '.html',
                link      => $data->[0]{link} . $link->{slug} . '.html',
                pubDate   => $date,
            );
        }

        # Give the user back the fully rendered RSS file.
        $c->stash->{text} = $rss->as_string;
    }
);

define index => (
    code => sub {
        my ( $self, $c ) = @_;

        my $plan = $self->run( qw( /quiet build:plan ) );

        my @links;
        foreach my $file ( @{$plan->stash->{files}} ) {
            my $metadata = $c->model("Markdown")->metadata_from_file($file->[-1]);

            next if $metadata->{index} and $metadata->{index} eq 'no';

            push @links, { %{$metadata}, filename => $file->[0]  };
        }

        @links = sort { $b->{weight} <=> $a->{weight} } @links;
        
        $c->stash->{index_page} = $c->model("Xslate")->render('index.tx', {
                links => [ @links ],
        });

        # Give the user back the fully rendered markdown.
        $c->stash->{text} = $c->stash->{index_page};
    }
);

define plan => (
    code => sub {
        my ( $self, $c ) = @_;

        find(sub {
            return unless $_ =~ /\.md$/;
            push @{$c->stash->{files}}, [ $_, $File::Find::name ];
        }, 'content');

        $c->stash->{text} = join "", map {
            $_->[0] . " " . $_->[1] . "\n"
        } @{$c->stash->{files}};
    }
);

define build => (
    code => sub {
        my ( $self, $c ) = @_;

        remove_tree( "build" );
        make_path( "build" );

        my $plan = $self->run( qw( /quiet build:plan ) );

        foreach my $file ( @{$plan->stash->{files}} ) {
            my $markdown = $self->run( qw( /quiet build:html ), $file->[1] );

            my $path = $file->[1];

            # Figure out where to put this file.
            $path =~ s|^content/||;    # content/blog/2020-09-13.md -> blog/2020-09-13.md
            $path = "build/$path";  # blog/2020-09-13.md /fullpath/blog/2020-09-13.md
            my ( $slug, $dir ) = fileparse($file->[0], qr|\.md$|);
            $slug = $markdown->stash->{markdown_vars}->{slug}
                if $markdown->stash->{markdown_vars}->{slug};

	    my $dirname = dirname("build/$slug.html");
	    make_path($dirname);

            write_text( "build/$slug.html", $markdown->stash->{markdown_rendered} );
        }
        
        my $index = $self->run( qw( /quiet build:index ) );
        write_text( "build/index.html", $index->stash->{index_page} );

        my $rss = $self->run( qw( /quiet build:rss ) );
        write_text( "build/rss.xml", $rss->stash->{text} );

        $self->run( qw( /quiet build:static ) );

        $c->stash->{text} = "Created build/\n";
    }
);

define static => (
    code => sub {
        my ( $self, $c ) = @_;

        # Copy template/static into build/
        dircopy( 'template/static', 'build' );
        

        # Copy static into build/
        dircopy( 'static', 'build' );
    },
);

1; 

