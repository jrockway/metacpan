package MyCPAN::Indexer;
use strict;
use warnings;

use Cwd;
use Data::Dumper;
use File::Path;
use Log::Log4perl qw(:easy);

sub new 
        {
        my $class = shift;
        return bless { dist_info => {} }, $class;
        }

sub run 
	{
	my $self = shift;
	
	$self->set_run_info( 'root_working_dir', cwd() );
	
	my $count = 0;
	
	DIST: foreach my $dist ( @_ )
		{    
                INFO( "Processing $dist\n" );
                $self->index_dist($dist);
		INFO( "Finished processing $dist\n" );
		DEBUG( Dumper( $self ) );
		$self->report_dist_info;
		}
	}

sub index_dist {
    my $self = shift;
    my $dist = shift;
    
    $self->clear_dist_info;

    $self->set_dist_info( 'dist', $dist );
    
    $self->unpack_dist( $dist ) or next;
    my $dist_dir = $self->dist_info( 'dist_dir' );
    
    DEBUG( "Dist dir is $dist_dir\n" );
    chdir( $self->dist_info( 'dist_dir' ) )
      or do { ERROR( "Could not change to $dist_dir! $!" ); return };
    
    $self->get_file_list or return;
    
    $self->parse_meta_files;
    
    $self->run_build_file;
    
    $self->get_blib_file_list or return;
    
    $self->get_module_versions;  
    return 1;
}	

sub examine
	{
	my( $class, $dist ) = @_;
	
	my $self = bless {}, $class;
	
	ERROR( "Could not find dist file [$dist]" )
		unless -e $dist;
	
	$self->set_dist( $dist );
	
	$self->unpack_dist( $dist );
	
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# from here things get dangerous because we have to run some code
=pod
	get_file_list
	
	if get_yaml
		filter file_list based on no_index, private
	
	get file mod time
	
	foreach file
		find $VERSION line not in POD
		
		wrap version in safe package
	
			run and capture version string
	
			record pm, version, dist
=cut
	# things aren't so dangerous anymore
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
	#$self->cleanup;
	
	$self->report_findings;
	
	}

sub set_dist 
	{ 
	my $self = shift;
	my $dist = shift;
	
	if( @_ )
		{
		DEBUG( "Setting dist [$dist]\n" );
		$self->{dist_file} = $dist;
		$self->{dist_size} = -s $dist;
		$self->{dist_date} = (stat $dist)[9];
		DEBUG( "dist size [$self->{dist_size}] dist date [$self->{dist_date}]\n" );
		}
		
	return 1;
	}

sub dist_file { $_[0]->{dist_file} }
sub dist_size { $_[0]->{dist_size} }
sub dist_date { $_[0]->{dist_date} }

sub set_run_info 
	{ 
	my( $self, $key, $value ) = @_;
	
	DEBUG( "Setting run_info key [$key] to [$value]\n" );
	$self->{run_info}{$key} = $value;
	}

sub run_info 
	{ 
	my( $self, $key ) = @_;
	
	DEBUG( "Getting run_info key [$key]\n" );
	DEBUG( $self->{run_info}{$key} );
	$self->{run_info}{$key};
	}

sub clear_dist_info 
	{ 
	my( $self, $key) = @_;
	
	DEBUG( "Clearing dist_info\n" );
	$self->{dist_info} = {};
	}

sub set_dist_info 
	{ 
	my( $self, $key, $value ) = @_;
	
	DEBUG( "Setting run_info key [$key] to [$value]\n" );
	$self->{dist_info}{$key} = $value;
	}
	
sub dist_info 
	{ 
	my( $self, $key ) = @_;
	
	DEBUG( "Getting run_info key [$key]\n" );
	DEBUG( $self->{run_info}{$key} );
	$self->{dist_info}{$key};
	}

sub unpack_dist 
	{ 	
	require Archive::Extract;
	require File::Temp;

	my $self = shift;
	my $dist = shift;
	
	( my $prefix = __PACKAGE__ ) =~ s/::/-/g;
	
	my $unpack_dir = File::Temp::tempdir(
		$prefix . "-$$.XXXX",
		DIR     => $self->run_info( 'root_working_dir' ),
		CLEANUP => 1,
		); 
		
	DEBUG( "Unpacking into directory [$unpack_dir]" );

	$self->set_dist_info( 'unpack_dir', $unpack_dir );
	
	my $extractor = Archive::Extract->new( archive => $dist );
	$self->set_dist_info( 'dist_archive_type', $extractor->type );
	
	my $rc = $extractor->extract( to => $unpack_dir );
	DEBUG( "Archive::Extract returns [$rc]" );

	$self->set_dist_info( 'dist_dir', $extractor->extract_path );

	$extractor->extract_path;		
	}

sub get_file_list
	{
	my $self = shift;
	
	unless( -e 'Makefile.PL' or -e 'Build.PL' )
		{
		ERROR( "No Makefile.PL or Build.PL" );
		$self->set_dist_info( 'manifest', [] );

		return;
		}
	
	require ExtUtils::Manifest;
	
	my $manifest = [ sort keys %{ ExtUtils::Manifest::manifind() } ];
	
	$self->set_dist_info( 'manifest', $manifest );
	}

sub get_blib_file_list
	{
	my $self = shift;

	unless( -d 'blib/lib' )
		{
		ERROR( "No blib/lib found!" );
		$self->set_dist_info( 'blib', [] );

		return;
		}

	require ExtUtils::Manifest;
	
	my $blib = [ grep { m|^blib/| and ! m|.exists$| } 
		sort keys %{ ExtUtils::Manifest::manifind() } ];
	
	$self->set_dist_info( 'blib', $blib );
	}
	
sub parse_meta_files
	{
	my $self = shift;
	
	if( -e 'META.yml'  )
		{
		require YAML::Syck;
		my $yaml = YAML::Syck::LoadFile( 'META.yml' );
		$self->set_dist_info( 'META.yml', $yaml );
		}

	return 1;	
	}

sub run_build_file
	{
	my $self = shift;
	
	$self->choose_build_file;
	
	$self->setup_build;
	
	$self->run_build;
	
	return 1;	
	}

sub choose_build_file
	{
	my $self = shift;
	
	my $file =  -e "Build.PL" ? "Build.PL" :
		-e "Makefile.PL" ? "Makefile.PL" : undef;
		
	unless( defined $file )
		{
		ERROR( "Did not find Makefile.PL or Build.PL" );
		return;
		}

	$self->set_dist_info( 'build_file', $file );
	
	return 1;
	}

sub setup_build
	{
	my $self = shift;
	
	my $file = $self->dist_info( 'build_file' );
	
	my $command = "$^X $file";
	
	$self->run_something( $command, 'build_file_output' );	
	}
	
sub run_build
	{
	my $self = shift;

	my $file = $self->dist_info( 'build_file' );

	my $command = $file eq 'Build.PL' ? "$^X ./Build" : "make";
			
	$self->run_something( $command, 'build_output' );
	}

sub run_something
	{
	my $self = shift;
	my( $command, $info_key ) = @_;
	
	{
	require IPC::Open2;
	DEBUG( "Running $command" );
	my $pid = IPC::Open2::open2( my $read, my $write, $command );
	
	close $write;
	
		{ 
		local $/; 
		my $output = <$read>; 
		$self->set_dist_info( $info_key, $output );
		}
	}

	}

sub get_module_versions
	{
	my $self = shift;
		
	unless( ref $self->dist_info( 'blib' ) eq ref [] )
		{
		ERROR( "No blib list in self!" );
		$self->set_dist_info( 'module_list', [] );

		return;
		}
	
	my $modules_hash = { 
		map { my $version = $self->parse_version_safely( $_->[1] ); ( $_->[0], $version ) }
		map { my $s = $_; $s =~ s|^blib/lib/||; $s =~ s|/|::|g; $s =~ s/.pm$//; [ $s, $_ ] }
		grep { m|^blib/lib/| and  m|\.pm$| } 
		@{  $self->dist_info( 'blib' ) } 
		};
			
	$self->set_dist_info( 'module_versions', $modules_hash );
	}

sub parse_version_safely # stolen from PAUSE's mldistwatch, but refactored
	{
	my $self = shift;
	my $file = shift;
	
	local $/ = "\n";
	local $_; # don't mess with the $_ in the map calling this
	
	my $fh;
	unless( open $fh, "<", $file )
		{
		ERROR( "Could not open file [$file]: $!\n" );
		return;
		}
	
	my $in_pod = 0;
	my $version;
	while( <$fh> ) 
		{
		chomp;
		$in_pod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $in_pod;
		next if $in_pod || /^\s*#/;

		next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
		my( $sigil, $var ) = ( $1, $2 );
		
		$version = $self->eval_version( $_, $sigil, $var );
		DEBUG( "Got  version [$version]" );
		last;
		}
	close $fh;

	return $version;
	}

sub eval_version
	{
	my $self = shift;
	
	my( $line, $sigil, $var ) = @_;

	DEBUG( "Evaling line [$line] with sigil [$sigil] and var [$var]" );
	
	my $eval = qq{ 
		package ExtUtils::MakeMaker::_version;

		local $sigil$var;
		\$$var=undef; do {
			$line
			}; \$$var
		};
	
	DEBUG( "Eval string is [------\n$eval\n--------\n" );
	
	my $version = do {
		local $^W = 0;
		no strict;
		eval( $eval );
		};
	DEBUG( "Eval error is [$@]" ) if $@;

	DEBUG( "Evaled to version [$version]" );
	return $version;
	}
	
	
sub cleanup
	{
	my $self = shift;
	
	return 1;

	File::Path::rmtree(
		[
		$self->run_info( 'unpack_dir' )
		],
		0, 0
		);
		
	return 1;
	}

sub report_dist_info
	{
	no warnings 'uninitialized';
	my $self = shift;
	
	print $self->dist_info( 'dist' ), "\n\t";
	
	my $module_hash = $self->dist_info( 'module_versions' );
	
	while( my( $k, $v ) = each %$module_hash )
		{
		print "$k => $v\n\t";
		}
	
	print "\n";
	}
1;	
__END__
dist_name
dist_archive_type zip bz2 tgz
dist_date
dist_author
modules
	name version
scripts
	name version
dist_size
run info
	unpack dir
