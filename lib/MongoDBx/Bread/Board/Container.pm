package MongoDBx::Bread::Board::Container;
use Moose;
use Bread::Board;
use MongoDB;

extends 'Bread::Board::Container';

has '+name' => ( default => 'MongoDB' );
has 'host'  => ( is => 'ro', isa => 'Str', default => 'localhost' );
has 'port'  => ( is => 'ro', isa => 'Int', default => 27017 );

has 'database_layout' => (
    is       => 'ro',
    isa      => 'HashRef[ ArrayRef[ Str ] ]',
    required => 1,
);

has 'additional_connection_params' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} }
);

sub BUILD {
    my $self = shift;

    container $self => as {

        service 'host' => $self->host;
        service 'port' => $self->port;

        service 'connection' => (
            class => 'MongoDB::Connection',
            block => sub {
                my $s = shift;
                MongoDB::Connection->new(
                    host => $s->param('host'),
                    port => $s->param('port'),
                    %{ $self->additional_connection_params }
                );
            },
            dependencies => [ 'host', 'port' ],
        );

        foreach my $db_name ( keys %{ $self->database_layout } ) {

            my $dbh = "${db_name}_dbh";

            service $dbh => (
                block => sub {
                    (shift)->param('connection')
                           ->get_database( $db_name );
                },
                dependencies => [ 'connection' ]
            );

            container $db_name => as {

                foreach my $coll_name ( @{ $self->database_layout->{ $db_name } } ) {
                    service $coll_name => (
                        block => sub {
                            (shift)->param( $dbh )
                                   ->get_collection( $coll_name );
                        },
                        dependencies => [ "../../../$dbh" ]
                    );
                }

            };
        }

    };
}

no Moose; no Bread::Board; 1;
# ABSTRACT: An easy to use Bread::Board container for MongoDB

=head1 SYNOPSIS

  use MongoDBx::Bread::Board::Container;

  # create a container

  my $c = MongoDBx::Bread::Board::Container->new(
      name            => 'MongoDB',
      host            => $HOST,
      database_layout => {
          test     => [qw[ foo bar ]],
          test_too => [qw[ baz gorch ]]
      }
  );

  # fetch the 'foo' collection
  # from the 'test' database
  my $foo = $c->resolve( service => 'MongoDB/test/foo');

  # get the MongoDB::Database
  # object for the 'test' db
  my $test = $c->resolve( service => 'MongoDB/test_dbh');

  # get the MongoDB::Connection
  # object used for all the above
  my $conn = $c->resolve( service => 'MongoDB/connection');

  # you can also create the container
  # within an existing Bread::Board config

  container 'MyProject' => as {

      # embed the Mongo container ...
      container(
          MongoDBx::Bread::Board::Container->new(
              name            => 'MyMongoDB',
              host            => $HOST,
              database_layout => {
                  test     => [qw[ foo bar ]],
                  test_too => [qw[ baz gorch ]]
              }
          )
      );

      # create services that depend
      # on the MongoDB container
      service 'foobar' => (
          class        => 'FooBar',
          dependencies => {
              collection => 'MyMongoDB/test/foo'
          }
      );
  };

=head1 DESCRIPTION

This is a subclass of L<Bread::Board::Container> which
can be used to wrap your L<MongoDB> code. It manages your
connection and additionally using the C<database_layout>
attribute can provide services to access your databases
and collections as well.

=attribute name

This is inherited from L<Bread::Board::Container>, this
defaults to 'MongoDB' in this container.

=attribute host

The hostname passed to L<MongoDB::Connection>, this
defaults to 'localhost'.

=attribute port

The port number passed to L<MongoDB::Connection>, this
defaults to 27017.

=attribute additional_connection_params

If you want to pass additional parameters to the
L<MongoDB::Connection> constructor, just supply them
here and they will get merged in with the C<host> and
C<port> params.

=attribute connection_lifecycle

By default each request for the connection object

=attribute database_layout





