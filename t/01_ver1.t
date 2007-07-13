use Test::More tests => 10;

BEGIN {	use_ok( 'POE::Component::Client::NRPE' ) };

use Socket;
use POE qw(Wheel::SocketFactory Filter::Stream);

POE::Session->create(
  package_states => [
	'main' => [qw(
			_start 
			_server_error 
			_server_accepted 
			_response 
			_client_error 
			_client_input
			_client_flush
	)],
  ],
);

$poe_kernel->run();
exit 0;

sub _start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  $heap->{factory} = POE::Wheel::SocketFactory->new(
	BindAddress => '127.0.0.1',
        SuccessEvent => '_server_accepted',
        FailureEvent => '_server_error',
  );
  my $port = ( unpack_sockaddr_in $heap->{factory}->getsockname() )[0];

  my $check = POE::Component::Client::NRPE->check_nrpe( 
	host  => '127.0.0.1',
	port  => $port,
	event => '_response',
	version => 1,
	context => { thing => 'moo' },
  );

  isa_ok( $check, 'POE::Component::Client::NRPE' );

  return;
}

sub _response {
  my ($kernel,$heap,$res) = @_[KERNEL,HEAP,ARG0];
  ok( $res->{context}->{thing} eq 'moo', 'Context data was okay' );
  ok( $res->{version} eq '1', 'Response version' );
  ok( $res->{result} eq '0', 'The result code was okay' );
  ok( $res->{data} eq 'NRPE v1.9', 'And the data was cool' ) or diag("Got '$res->{data}', expected 'NRPE v1.9'\n");
  delete $heap->{factory};
  return;
}

sub _server_error {
  die "Shit happened\n";
}

sub _server_accepted {
  my ($kernel,$heap,$socket) = @_[KERNEL,HEAP,ARG0];
  my $wheel = POE::Wheel::ReadWrite->new(
	Handle => $socket,
	Filter => POE::Filter::Stream->new(),
	InputEvent => '_client_input',
        ErrorEvent => '_client_error',
	FlushedEvent => '_client_flush',
  );
  $heap->{clients}->{ $wheel->ID() } = $wheel;
  return;
}

sub _client_flush {
  my ($heap,$wheel_id) = @_[HEAP,ARG0];
  delete $heap->{clients}->{ $wheel_id };
  return;
}

sub _client_error {
  my ( $heap, $wheel_id ) = @_[ HEAP, ARG3 ];
  delete $heap->{clients}->{$wheel_id};
  return;
}

sub _client_input {
  my ($kernel,$heap,$input,$wheel_id) = @_[KERNEL,HEAP,ARG0,ARG1];
  my @args = unpack "NNNNa*", $input;
  $args[4]  =~ s/\x00*$//g;
  ok( $args[0] eq '1', 'Version check' );
  ok( $args[1] eq '1', 'Query check' );
  ok( $args[3] == length($args[4]), 'Data length check' ) or diag( "Got '$args[3]', but the length was '" . length($args[4]) . "'" );
  ok( $args[4] eq '_NRPE_CHECK', 'Got a valid command' );
  $args[0] = 2;
  $args[4] = 'NRPE v1.9';
  $args[2] = 0;
  $args[3] = length $args[4];
  my $response = pack "NNNNa[1024]", @args;
  $heap->{clients}->{ $wheel_id }->put( $response );
  return;
}
