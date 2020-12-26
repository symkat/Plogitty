package Plogitty::Command::Build;
use oCLI::Command;
use Text::Xslate qw( mark_raw ); # Get mark_raw()
use File::Find;
use File::Basename qw( fileparse );
use File::Slurper qw( write_text );
use File::Path qw( make_path remove_tree );

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
        $c->stash->{markdown_html} = $markdown->result;

        # Process the markdown file into an HTML file with its Text::Xslate template.
        $c->stash->{markdown_rendered} = $c->model("Xslate")->render($c->stash->{markdown_vars}->{template}, {
            %{ $c->stash->{markdown_vars} },
            content => mark_raw($c->stash->{markdown_html}),
        });

        # Give the user back the fully rendered markdown.
        $c->stash->{text} = $c->stash->{markdown_rendered};
    },
);

define index => (
    code => sub {
        my ( $self, $c ) = @_;

        my $plan = $self->run( qw( /quiet build:plan ) );

        my @links;
        foreach my $file ( @{$plan->stash->{files}} ) {
            my $metadata = $c->model("Markdown")->metadata($file->[-1]);

            push @links, { %{$metadata}, filename => $file->[0]  };
        }
        
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

            write_text( "build/$slug.html", $markdown->stash->{markdown_rendered} );
        }
        
        my $index = $self->run( qw( /quiet build:index ) );

        write_text( "build/index.html", $index->stash->{index_page} );

        $c->stash->{text} = "Created build/\n";
    }
);

1; 

