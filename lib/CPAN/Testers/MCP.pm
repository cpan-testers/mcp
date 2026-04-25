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
use Log::Any::Adapter 'Multiplex' =>
  # Set up Log::Any to log to OpenTelemetry and Stderr so we can still
  # see the local logs.
  adapters => {
    'OpenTelemetry' => [],
    'Stderr' => [
      log_level => $ENV{LOG_LEVEL} || $ENV{MOJO_LOG_LEVEL} || "debug",
    ],
  };
use Log::Any qw( $LOG );

sub startup( $self ) {
  # Remove Mojo::Log from STDERR so that we don't double-log
  $self->log(Mojo::Log->new(handle => undef));
  # Forward Mojo::Log logs to the Log::Any logger, so that from there
  # they will be forwarded to OpenTelemetry.
  # Modules should prefer to log with Log::Any because it supports
  # structured logging.
  $self->log->on( message => sub ( $, $level, @lines ) {
    $LOG->$level(@lines);
  });

  my $server = CPAN::Testers::MCP::Server->new;
  $self->routes->get( '/' => 'index' );
  $self->routes->post( '/' => $server->to_action );
}

1;

