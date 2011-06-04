use JSON;
my $g = {
name => "Test graph",
search_path => ".*cpu.*",
data_sources => [
		 { name => 'tx',
		   type => 'single',
		   source => ".*if_octets-$1",
		   rra => AVERAGE,
		 },
		 { name => 'tx',
		   type => 'single',
		   source => ".*if_octets-$1",
		   rra => AVERAGE,
		 },
		],
data_math => [
	      { type => "cdef-single",
		source => tx,
		name => "invert-$1",
		def => "0,$,-",
	      }
	     ],
graph => [
	  { type => "LINE",
	    color => "#FF0000",
	    width => "1"
	    ds => tx,
	  },
	  { type => "AREA",
	    color => "#0000FFAA",
	    ds => rx,
	  }
	 ]
	}
	    
		
