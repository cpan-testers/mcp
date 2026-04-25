package CPAN::Testers::MCP;
our $VERSION = '0.001';
# ABSTRACT: Model Context Protocol server for CPAN Testers data

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use v5.40;
use Mojo::Base 'Mojolicious', -signatures, -async_await;
use CPAN::Testers::MCP::Server;

sub startup( $self ) {
  my $server = CPAN::Testers::MCP::Server->new;
  my $mcp_action = $server->to_action;
  $self->routes->get( '/' => 'index' );
  $self->routes->post( '/' => $server->to_action );
}

1;

