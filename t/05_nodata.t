use Test::More tests => 8;

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
	usessl => 0,
	timeout => 5,
	context => { thing => 'moo' },
  );

  isa_ok( $check, 'POE::Component::Client::NRPE' );

  return;
}

sub _response {
  my ($kernel,$heap,$res) = @_[KERNEL,HEAP,ARG0];
  ok( $res->{context}->{thing} eq 'moo', 'Context data was okay' );
  ok( $res->{version} eq '2', 'Response version' );
  ok( $res->{result} eq '3', 'The result code was okay' );
  diag($res->{data}, "\n");
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
  my @args = unpack "nnNnZ*", $input;
  $args[4]  =~ s/\x00*$//g;
  ok( $args[0] eq '2', 'Version check' );
  ok( $args[1] eq '1', 'Query check' );
  ok( $args[4] eq '_NRPE_CHECK', 'Got a valid command' ) or diag( "Got '$args[5]', expected '_NRPE_CHECK'\n");
  #my $response = _gen_packet_ver2( 'NRPE v2.8.1' );
  #$heap->{clients}->{ $wheel_id }->put( $response );
  delete $heap->{clients}->{ $wheel_id };
  return;
}

sub _gen_packet_ver2 {
  my $data = shift;
  for ( my $i = length ( $data ); $i < 1024; $i++ ) {
    $data .= "\x00";
  }
  $data .= "SR";
  my $res = pack "n", 0;
  my $packet = "\x00\x02\x00\x02";
  my $tail = $res . $data;
  my $crc = ~POE::Component::Client::NRPE::_crc32( $packet . "\x00\x00\x00\x00" . $tail );
  $packet .= pack ( "N", $crc ) . $tail;
  return $packet;
}

