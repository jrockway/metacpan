package MyCPAN::Distribution;
use Moose;
use MooseX::Types::Path::Class qw(File Dir);
use MooseX::AttributeHelpers;

use File::Spec;
use Archive::Extract;
use File::Temp;
use Log::Log4perl qw(:easy);
use Moose::Util::TypeConstraints;
use ExtUtils::Manifest;
use YAML::Syck ();
use IPC::Open2;
use File::Path;
use File::pushd;
use Digest::MD5 ();

enum 'ArchiveType' => qw(tgz bz2);

subtype 'MD5' 
  => as 'Str'
  => where { /^[0-9a-f]{32}$/ };

has 'filename' => (
    is        => 'ro',
    isa       => File,
    required  => 1,
    coerce    => 1,
);

has 'root_working_dir' => (
    is        => 'ro',
    isa       => Dir,
    default   => File::Spec->tmpdir,
    coerce    => 1,
);

has 'unpack_dir' => (
    is        => 'ro',
    isa       => Dir,
    coerce    => 1,
    
    # default is /tmp/MyCPAN-Distribution-PID.1234 or similar
    lazy      => 1,
    default   => sub { 
        my $self = shift;
        File::Temp::tempdir(
            do { (my $p = __PACKAGE__) =~ s/::/-/g; $p } . "-$$.XXXX",
            DIR => $self->root_working_dir,
        ),
    },
);

# information after we unpack
# XXX: rebless into MyCPAN::Dist::Unpacked?

has 'dist_dir' => (
    is         => 'rw',
    isa        => Dir,
    coerce     => 1,
    predicate  => 'has_dist_dir',
);

sub extracted { shift->has_dist_dir } # alias

has 'archive_type' => (
    is         => 'rw',
    isa        => 'ArchiveType',
    predicate  => 'has_archive_type',
);

has 'manifest' => (
    is         => 'rw',
    isa        => 'ArrayRef[Str]', # TODO: ArrayRef[File]
    predicate  => 'has_manifest',
    default    => sub { [] },
    auto_deref => 1,
);

has 'blib' => (
    is         => 'rw',
    isa        => 'ArrayRef[Str]', # TODO: ArrayRef[File]
    predicate  => 'has_blib',
    default    => sub { [] },
    auto_deref => 1,
);

has 'meta_yml' => (
    is         => 'rw',
    isa        => 'HashRef',
    predicate  => 'has_meta_yml',
    default    => sub { {} },
);

has 'build_file' => (
    is         => 'rw',
    isa        => File,
    predicate  => 'has_build_file',
    coerce     => 1,
);

has 'build_file_output' => (
    is  => 'rw',
    isa => 'Str',
);

has 'build_output' => (
    is  => 'rw',
    isa => 'Str',
);

has 'module_list' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'module_versions' => (
    metaclass  => 'Collection::Hash',
    is         => 'rw',
    isa        => 'HashRef',
    default    => sub { {} },
    provides   => {
        keys => 'modules',
        get  => 'module_version',
    },
    auto_deref => 1,
);

has 'md5' => (
    is        => 'rw',
    isa       => 'MD5',
    predicate => 'has_md5',
);

# this is where we index everything, so that the above attributes
# are always populated
sub BUILD {
    my $self = shift;
    my $filename = $self->filename;
    die "[$filename] does not exist" unless -e $filename;
    
    $self->calc_md5;
    $self->unpack;
    { 
        my $dir = pushd($self->dist_dir);
        $self->get_file_list;
        $self->parse_meta_files;
        $self->run_build_file;
        $self->get_blib_file_list;
        $self->get_module_versions;  
    }
}

sub unpack {
    my ($self) = @_;
    my $dist = $self->filename;
    my $unpack_dir = $self->unpack_dir;
    
    DEBUG( "Unpacking into directory [$unpack_dir]" );
    
    my $extractor = Archive::Extract->new( archive => $dist );
    $self->archive_type( $extractor->type );
    
    my $rc = $extractor->extract( to => $unpack_dir );
    DEBUG( "Archive::Extract returns [$rc]" );
    
    $self->dist_dir( $extractor->extract_path );
    return $extractor->extract_path;        
}

sub get_file_list {
    my $self = shift;
    
    die "No Makefile.PL or Build.PL"    
      unless( -e 'Makefile.PL' or -e 'Build.PL' );
    
    my $manifest = [ sort keys %{ ExtUtils::Manifest::manifind() } ];
    $self->manifest($manifest);
    
    return $self->manifest; # arrayref in scalar context, list otherwise
}

sub get_blib_file_list {
    my $self = shift;
    
    die "No blib/lib found!" 
      unless( -d 'blib/lib' );

    my $blib = [ grep { m|^blib/| and ! m|.exists$| } 
                   sort keys %{ ExtUtils::Manifest::manifind() } ];
    $self->blib($blib);

    return $self->blib;
}

sub parse_meta_files {
    my $self = shift;
    
    if( -e 'META.yml'  ){
        my $yaml = YAML::Syck::LoadFile( 'META.yml' );
        $self->meta_yml($yaml);
    }
    
    return 1;    
}

sub run_build_file {
    my $self = shift;
    
    $self->choose_build_file;
    $self->setup_build;
    $self->run_build;

    return 1;    
}

sub choose_build_file {
    my $self = shift;
    
    my $file =  -e "Build.PL"    ? "Build.PL" :
                -e "Makefile.PL" ? "Makefile.PL" : undef;
        
    die "Did not find Makefile.PL or Build.PL" 
      unless( defined $file );

    $self->build_file($file);
    
    return 1;
}

sub setup_build {
    my $self = shift;

    my $file = $self->build_file;
    my $command = "$^X $file";
    
    $self->_run_something( $command, 'build_file_output' );    
}
    
sub run_build    {
    my $self = shift;
    
    my $file = $self->build_file;
    my $command = $file eq 'Build.PL' ? "$^X ./Build" : "make";
    
    $self->_run_something( $command, 'build_output' );
}
        
sub _run_something   {
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
            $self->$info_key( $output );
        }
    }
}

sub get_module_versions {
    my $self = shift;
    
    die "No blib list in self!" unless $self->has_blib;
    
    my $modules_hash = { 
        map { my $version = $self->parse_version_safely( $_->[1] ); 
              ( $_->[0], $version ) 
          }
          map { my $s = $_; 
                $s =~ s|^blib/lib/||; 
                $s =~ s|/|::|g; $s =~ s/.pm$//; 
                [ $s, $_ ] 
            }
            grep { m|^blib/lib/| and  m|\.pm$| } $self->blib 
        };
    
    $self->module_versions( $modules_hash );
}

sub parse_version_safely # stolen from PAUSE's mldistwatch, but refactored
    {
    my $self = shift;
    my $file = shift;
    
    local $/ = "\n";
    local $_; # don't mess with the $_ in the map calling this
    
    my $fh;

    die "Could not open file [$file]: $!"
      unless( open $fh, "<", $file );
    
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

sub eval_version {
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

sub calc_md5 {
    my $self = shift;
    my $filename = $self->filename;
    
    DEBUG( "computing md5 of [$filename]" );

    open my $fh, '<', $filename 
      or die "failed to open $filename for reading: $!";
    
    my $ctx = Digest::MD5->new;
    $ctx->addfile($fh);
    my $md5 = $ctx->hexdigest;

    DEBUG( "md5 of [$filename] is [$md5]" );
    
    return $self->md5($md5);
}

sub cleanup {
    my $self = shift;
    File::Path::rmtree(
        [
            $self->unpack_dir,
        ],
        0, 0
    );
    
    return 1;
}

sub DEMOLISH {
    my $self = shift;
    $self->cleanup;
    DEBUG( "DEMOLISHing $self (". $self->filename. ')' );
}
  
1;
