use Test::More tests => 5;

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

  delete $heap->{factory};

  my $check = POE::Component::Client::NRPE->check_nrpe( 
	host  => '127.0.0.1',
	port  => $port,
	event => '_response',
	usessl => 0,
	context => { thing => 'moo' },
  );

  isa_ok( $check, 'POE::Component::Client::NRPE' );

  return;
}

sub _response {
  my ($kernel,$heap,$res) = @_[KERNEL,HEAP,ARG0];
  ok( $res->{context}->{thing} eq 'moo', 'Context data was okay' );
  ok( $res->{version} eq '2', 'Response version' );
  ok( $res->{result} eq '3', 'The result code was okay' ) or diag("Got '$res->{result}', but expected '3'\n");
  diag( $res->{data}, "\n" );
  return;
}

sub _server_error {
  die "Shit happened\n";
}

sub _server_accepted {
  return;
}
