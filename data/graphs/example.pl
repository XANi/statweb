#!/usr/bin/perl
# Generate example graph template
use JSON;
my $json = JSON->new()->pretty();
my $g = {
name => "Test graph",
search_path => ".*\/network\/if_octets.*",
selector => ".*\/network\/if_octets-(.*)",
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
		name => "invert-tx",
		def => "0,$,-",
	      }
	     ],
graph => [
	  { type => "LINE",
	    color => "#FF0000",
	    width => "1",
	    ds => tx,
	  },
	  { type => "AREA",
	    color => "#0000FFAA",
	    ds => rx,
	  }
	 ]
	}
;
print $json->encode($g);
