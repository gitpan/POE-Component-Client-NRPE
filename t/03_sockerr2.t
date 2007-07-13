use Test::More tests => 5;

BEGIN {	use_ok( 'POE::Component::Client::NRPE' ) };

use POE;

POE::Session->create(
  package_states => [
	'main' => [qw(
			_start 
			_response 
	)],
  ],
);

$poe_kernel->run();
exit 0;

sub _start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];

  my $check = POE::Component::Client::NRPE->check_nrpe( 
	host  => 'zxkchzxkchzkxhckjhkzjhckzcxkhzk',
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
  ok( $res->{result} eq '3', 'The result code was okay' );
  diag( $res->{data}, "\n" );
  return;
}
