package MetaCPAN::Distribution::Full;
use Moose;
use Moose::Util::TypeConstraints;
use Log::Log4perl qw(:easy);

extends 'MetaCPAN::Distribution';

=head1 NAME

MetaCPAN::Distribution::Full - C<MetaCPAN::Distribution> that runs
Makefile.PL and make before doing its thing

=cut

subtype 'BuildFile'
  => as 'Str',
  => where { /^(?:Makefile[.]PL|Build[.]PL)$/ };

has 'build_file' => (
    is         => 'rw',
    isa        => 'BuildFile',
    predicate  => 'has_build_file',
    lazy       => 1,
    default    => sub { shift->_build_file },
);

has 'build_file_output' => (
    is  => 'rw',
    isa => 'Str',
    lazy       => 1,
    default    => sub { shift->_run_build_file },
);

has 'build_output' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { shift->_run_build },
);

has 'blib' => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]', # TODO: ArrayRef[File]
    predicate  => 'has_blib',
    default    => sub { shift->_blib },
    auto_deref => 1,
    lazy       => 1,
);

has '+module_files' => (
    default => sub { [ grep { /[.]pm$/ } shift->blib ] },
);

sub _blib {
    my $self = shift;

    die 'need to have had successful build'
      unless $self->build_output;    
    
    my $blib_dir = $self->path_to('blib', 'lib');
    die "No blib/lib found!" unless -d $blib_dir;
    
    my $dir = $self->_cd_to_dist;
    return [ grep { m|^blib/| and ! m|.exists$| } 
               sort keys %{ ExtUtils::Manifest::manifind() } ];
}

sub _build_file {
    my $self = shift;
    
    my $dir = $self->_cd_to_dist;
    my $file =  -e "Build.PL"    ? "Build.PL" :
                -e "Makefile.PL" ? "Makefile.PL" : undef;
        
    die "Did not find Makefile.PL or Build.PL" 
      unless( defined $file );

    return $file;
}

sub _run_build_file {
    my $self = shift;

    my $file = $self->build_file;
    my $command = "$^X $file";
    
    return $self->_run_something( $command );
}
    
sub _run_build    {
    my $self = shift;

    die 'need to have had successful build file invocation'
      unless $self->build_file_output;

    my $file = $self->build_file;
    my $command = $file eq 'Build.PL' ? "$^X ./Build" : "make";
    
    return $self->_run_something( $command );
}
        
sub _run_something   {
    my $self = shift;
    my $command = shift;
    my $dir = $self->_cd_to_dist;
    
    DEBUG( "Running $command" );
    my $pid = IPC::Open2::open2( my $read, my $write, $command );
    close $write;

    my $out = do { local $/; <$read> };
    DEBUG( "Output was [\n$out\n]" );
    return $out;
}

1;
