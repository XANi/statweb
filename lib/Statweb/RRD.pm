package Statweb::RRD;

use 5.010000;
use strict;
use warnings;
use Carp qw(cluck croak);
use Data::Dumper;
use Dancer ':syntax';
use RRDs;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Statweb::RRD ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

use vars qw($RRD_DIR $RRD_INDEX);

sub new {
    my $self = shift;
    my $rrd_dir = shift;
    if (!defined ($rrd_dir)) {
	croak("RRD dir not defined!");
    }
    else {
	$RRD_DIR = $rrd_dir;
	$RRD_INDEX = {};
    }
    $self->index();
    return bless({},$self);
}

sub index {
    use vars qw/*name *dir *prune/;
    use File::Find;
    *name   = *File::Find::name;
    *dir    = *File::Find::dir;
    *prune  = *File::Find::prune;
    my $self = shift;
    File::Find::find( {wanted => \&_find_wanted, follow => 1}, '/var/lib/collectd');
    while(my ($key, $val) = each %$RRD_INDEX) {
	    $RRD_INDEX->{$key}{'ds'} = Dumper $self->get_ds($key);
	}
 }

sub info {
    my $self = shift;
    my $rrd_name = shift;
    if( !defined($RRD_INDEX->{$rrd_name}) ) {
	cluck("RRD not in index");
    }
    return RRDs::info( $RRD_INDEX->{$rrd_name}{'path'} );
}

sub get_ds {
    my $self = shift;
    my $rrd_name = shift;
    my $rrd_info = $self->info($rrd_name);
    my @ds_list;
    if ( !defined($rrd_info) ) {
	cluck(q{$self->info() did not retur anything, bad RRD file?});
	return
    }
    while( my($key, $val) = each %$rrd_info) {
	if ($key =~ /^ds\[(.+)\]\.type$/) {
	    push @ds_list, $1
	}
    }
    return \@ds_list;
}

sub _find_wanted {
    use Fcntl ':mode';
    my $file_name = $_;
    my $file_path = $File::Find::name;
    my $file_dir =  $File::Find::dir;
    my $rrd_name;
    # TODO check if its a dir

    if ($file_name =~ /.*\.rrd$/i ) {
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	 $atime,$mtime,$ctime,$blksize,$blocks)
	  = stat($_);
	if ($mode & S_IFREG) { # regular file
	    ($rrd_name) = $file_path =~ /^$RRD_DIR\/(.*)/;
	    $rrd_name =~ s/\.rrd$//;
	    $RRD_INDEX->{$rrd_name} = 
	      {
	       path => $file_path,
	       filename => $file_name,
	       time => time(),
	      };
	}
    }
}

sub generate_graph_config {
    my $self = shift;
    my $template = shift;
    my $params = shift;
    my @selected_rrd;
    while (my ($name, $desc) = each (%$RRD_INDEX)) {
	if ($name =~ /$template->{'search_path'}/) {
	    push @selected_rrd, $name;
	}
    }
    return \@selected_rrd;
}

# get list of names matching template
sub get_template_selection {
    my $self = shift;
    my $template_name = shift;
    # load template
    open(TEMP, '>', config->{'template_path'} . '/' . $template_name . '.json');
    my $template = from_json ( do { local $/;  <TEMP> } );
    my %selection;
    while (my ($name, $desc) = each (%$RRD_INDEX)) {
	if ($name =~ /$template->{'search_path'}/) {
	    my $sel_name = $1;
	    my $tmp_cnt=1;
	    while (defined ${$tmp_cnt + 1} && $tmp_cnt < 10) {
		$sel_name .= '-' . ${$tmp_cnt};
	    }
	    $selection{$sel_name}++;
	}
    }
    return \%selection;
}
sub get_index {
    my $self = shift;
    return $RRD_INDEX;
}



# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Statweb::RRD - RRD files handling

=head1 SYNOPSIS

  use Statweb::RRD;
  $rrddb = Statweb::RRD->new($rrd_dir);

=head1 DESCRIPTION

Stub documentation for Statweb::RRD, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

xani, E<lt>xani@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by xani

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
