package Plogitty::Command::New;
use oCLI::Command;

setup new => (
    desc => 'Create a new plogitty project directory',
);

define default => (
    validate => [
        0 => [ [ qw( defined ) ], { name => 'Directory Name', desc => 'Directory name to create project in'  } ],
    ],
    code => sub {
        my ( $self, $c ) = @_;

        my $target = $c->req->args->[0];

        if ( -e $target ) {
            die "Error: target directory ($target) exists, refusing to overwrite.\n";
        }

        mkdir $target;
        mkdir "$target/static";
        mkdir "$target/content";
        mkdir "$target/build";
        mkdir "$target/template";

        $c->stash->{text} = "Created $target\n";
    },
);

1; 
