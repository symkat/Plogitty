package Plogitty::Model::Markdown;
use warnings;
use strict;
use Markdown::Compiler;
use File::Slurper qw( read_text );

sub new {
    return bless {}, shift;
}

sub spawn_from_file {
    my ( $self, $file ) = @_;

    return Markdown::Compiler->new( source => read_text( $file ) );
}

sub metadata_from_file {
    my ( $self, $file ) = @_;

    return Markdown::Compiler->new( source => read_text( $file ) )->parser->metadata;
}

sub spawn_from_content {
    my ( $self, $content ) = @_;

    return Markdown::Compiler->new( source => $content );
}

sub metadata_from_content {
    my ( $self, $content ) = @_;

    return Markdown::Compiler->new( source => $content )->parser->metadata;
}

1;
