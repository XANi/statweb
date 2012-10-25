package Statweb;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->get('/datatables' => sub {
	my $self    = shift;
	my $datatable = {
		"aaData" => [
			[
				"Trident",
				"Internet Explorer 4.0",
				"Win 95+",
				"4",
				"X"
			],
			[
				"Trident",
				"Internet Explorer 5.0",
				"Win 95+",
				"5",
				"C"
			],
			[
				"Trident",
				"Internet Explorer 5.5",
				"Win 95+",
				"5.5",
				"A"
			],
			[
				"Trident",
				"Internet Explorer 6",
				"Win 98+",
				"6",
				"A"
			],
		]
	};

	$self->respond_to(
		json => {json => $datatable},
		xml  => {json => $datatable},
		txt  => {json => $datatable},
		html => {json => $datatable},
	);
	return "asdasd\n";
  });
  $r->get('/test')->to('example#welcome');

}

1;
#			$self->content_for(head => '<meta name="author" content="sri" />');
#			$self->render(template => 'hello', message => 'world')
