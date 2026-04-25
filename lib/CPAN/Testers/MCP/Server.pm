package CPAN::Testers::MCP::Server;
our $VERSION = '0.001';
# ABSTRACT: Model Context Protocol server for CPAN Testers data

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use v5.40;
use Mojo::Base 'MCP::Server', -signatures, -async_await;
use Mojo::UserAgent;
use Mojo::Promise;
use List::Util qw( maxstr );
use Log::Any qw( $LOG );
use Scalar::Util qw( blessed );

has ua => sub { Mojo::UserAgent->new };

sub new($class, @args) {
  my $self = $class->SUPER::new(@args);

  $self->tool(
    name => 'list_reports_by_dist',
    description => 'List reports from CPAN Testers by distribution',
    input_schema => {
      type => 'object',
      required => [qw( dist )],
      properties => {
        dist => {
          type => 'string',
        },
        version => {
          type => 'string',
        },
        grade => {
          type => 'array',
          items => {
            type => 'string',
            enum => [qw( pass fail na unknown )],
          },
        },
      },
    },
    code => async sub ($tool, $args) {
      # If no version, get the latest version of the dist
      my $version = $args->{version};
      if (!$version) {
        $LOG->info('Fetching versions', {dist => $args->{dist}});
        my $tx = await $self->ua->get_p('https://api.cpantesters.org/v3/upload/dist/' . $args->{dist});
        $version = maxstr map { $_->{version} } @{ $tx->res->json };
      }

      my $url = sprintf 'https://api.cpantesters.org/v3/summary/%s/%s', $args->{dist}, $version;
      my @reports;
      if (my $grade = $args->{grade}) {
        my $txs = await Mojo::Promise->all(
          map { $self->ua->get_p( "$url?grade=$_" ) } @$grade,
        );
        for my $tx ( @$txs ) {
          if (!blessed($tx) || !$tx->isa('Mojo::Transaction')) {
            $LOG->warn('Bad response', { tx => $tx });
            next;
          }
          if (!$tx->res->is_success) {
            $LOG->warn('Bad response', { code => $tx->res->code, body => $tx->res->body });
            next;
          }
          push @reports, @{ $tx->res->json };
        }
      }
      else {
        my $tx = await $self->ua->get_p( $url );
        if (!$tx->res->is_success) {
          $LOG->warn('Bad response', { code => $tx->res->code, body => $tx->res->body });
          return "Error: " . $tx->res->body;
        }
        push @reports, @{ $tx->res->json };
      }

      return join "\n\n", map {
        "GUID: $_->{guid}\nOS: $_->{osname}\nPlatform: $_->{platform}\nPerl: $_->{perl}\nGrade: $_->{grade}"
      } @reports;
    },
  );

  $self->tool(
    name => 'list_dists_by_author',
    description => 'List distributions by a CPAN author PAUSE ID',
    input_schema => {
      type => 'object',
      required => [qw( author )],
      properties => {
        author => {
          type => 'string',
        },
      },
    },
    code => async sub ($tool, $args) {
      my $url = sprintf 'https://api.cpantesters.org/v3/upload/author/%s', $args->{author};
      my $tx = await $self->ua->get_p( $url );
      my @uploads = @{ $tx->res->json };
      my %max_version;
      for my $upload ( @uploads ) {
        my ($dist, $version) = (@{$upload}{qw( dist version )});
        if (!$max_version{$dist} || $max_version{$dist}{version} lt $version) {
          $max_version{$dist} = $upload;
        }
      }

      return join "\n\n", map {
        "Dist: $_->{dist}\nVersion: $_->{version}\nDate: $_->{release}"
      } values %max_version;
    },
  );

  $self->tool(
    name => 'read_report',
    description => 'Read the full output of a test report by GUID.',
    input_schema => {
      type => 'object',
      properties => {
        guid => { type => 'string' },
      },
    },
    code => async sub ($tool, $args) {
      my $url = 'https://api.cpantesters.org/v3/report/' . $args->{guid};
      my $tx = await $self->ua->get_p( $url );
      return join "\n", values $tx->res->json('/result/output')->%*;
    },
  );

  return $self;
}

1;
