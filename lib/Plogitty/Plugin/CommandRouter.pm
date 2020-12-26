package Plogitty::Plugin::CommandRouter;
use Moo;
use oCLI::Context;

sub after_context {
    my ( $self, $c ) = @_;
    
    if ( ( $c->req->command_name eq $c->req->command ) and ( $c->req->command_class eq "" ) ) {
        my $data = $c->req;
        delete $data->{command_class};
        my $command = delete $data->{command_name};
        
        $c->req( oCLI::Request->new( { %{$data}, command => "$command:default" } ) );
    }
}

sub after_code { }
sub before_code { }

1;
