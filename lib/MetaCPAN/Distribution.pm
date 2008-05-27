package MetaCPAN::Distribution;
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
use DateTime;

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

has 'date' => (
    is      => 'ro',
    isa     => 'DateTime',
    lazy    => 1,
    default => sub { DateTime->from_epoch( epoch => [stat shift->filename]->[9] )},
);

has 'root_working_dir' => (
    is        => 'ro',
    isa       => Dir,
    default   => File::Spec->tmpdir,
    coerce    => 1,
);

has 'unpack_root' => (
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
        );
    },
);

has 'dist_dir' => (
    is         => 'ro',
    isa        => Dir,
    predicate  => 'has_dist_dir',
    default    => sub { shift->_unpack },
    lazy       => 1,
    coerce     => 1,
);

sub extracted { shift->has_dist_dir } # alias

has 'md5' => (
    is        => 'ro',
    isa       => 'MD5',
    predicate => 'has_md5',
    lazy      => 1,
    default   => sub { shift->_md5 },
);

has 'manifest' => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]', # TODO: ArrayRef[File]
    predicate  => 'has_manifest',
    default    => sub { shift->_manifest },
    auto_deref => 1,
    lazy       => 1,
);

has 'module_files' => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    default     => sub { [grep { m!lib/.+[.]pm$! } shift->manifest] },
    auto_deref  => 1,
    lazy        => 1,
);

has 'meta_yml' => (
    is         => 'ro',
    isa        => 'HashRef',
    predicate  => 'has_meta_yml',
    default    => sub { shift->_meta_yml },
    auto_deref => 1,
    lazy       => 1,
);

has 'module_versions' => (
    metaclass  => 'Collection::Hash',
    is         => 'ro',
    isa        => 'HashRef',
    default    => sub { shift->_module_versions },
    auto_deref => 1,
    lazy       => 1,
    provides   => {        
        keys => 'modules',
        get  => 'module_version',
    },
);

sub path_to {
    my ($self, @parts) = @_;
    my $file = Path::Class::file($self->dist_dir, @parts);

    return Path::Class::dir($file) if -d $file; # coerce into directory
    return $file;
}

sub _cd_to_dist {
    my $self = shift;
    return pushd($self->dist_dir);
}

sub _unpack {
    my ($self) = @_;
    my $dist = $self->filename;
    my $unpack_root = $self->unpack_root;
    
    DEBUG( "Unpacking into directory [$unpack_root]" );
    my $extractor = Archive::Extract->new( archive => $dist );
    my $rc = $extractor->extract( to => $unpack_root );
    DEBUG( "Archive::Extract returns [$rc]" );
    
    return $extractor->extract_path;        
}

sub _manifest {
    my $self = shift;
    my $dir = $self->_cd_to_dist;
    return [ sort keys %{ ExtUtils::Manifest::manifind() } ];
}

sub _meta_yml {
    my $self = shift;
    my $meta = $self->path_to('META.yml');

    return YAML::Syck::LoadFile( $meta ) if -e $meta;
    return {};
}

sub _module_versions {
    my $self = shift;
    
    die "No module list in self!" unless $self->module_files;

    my $modules_hash = { 
        map { my $version = $self->_parse_version_safely( $_->[1] ); 
              ( $_->[0], $version ) 
          }
          map { my $s = $_; 
                $s =~ s|^(?:blib/)?lib/||; 
                $s =~ s|/|::|g; $s =~ s/.pm$//; 
                [ $s, $_ ] 
            } $self->module_files
    };
    
    return $modules_hash;
}

sub _parse_version_safely # stolen from PAUSE's mldistwatch, but refactored
    {
    my $self = shift;
    my $file = shift;
    
    local $/ = "\n";
    local $_; # don't mess with the $_ in the map calling this
    
    open my $fh, "<", $self->path_to($file) or
      die "Could not open file [$file]: $!";
    
    my $in_pod = 0;
    my $version;
    while( <$fh> ) 
        {
        chomp;
        $in_pod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $in_pod;
        next if $in_pod || /^\s*#/;

        next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
        my( $sigil, $var ) = ( $1, $2 );
        
        $version = $self->_eval_version( $_, $sigil, $var );
        DEBUG( "Got  version [$version]" );
        last;
        }
    close $fh;
    
    return $version;
}

sub _eval_version {
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

sub _md5 {
    my $self = shift;
    my $filename = $self->filename;
    
    DEBUG( "computing md5 of [$filename]" );

    open my $fh, '<', $filename 
      or die "failed to open $filename for reading: $!";
    
    my $ctx = Digest::MD5->new;
    $ctx->addfile($fh);
    my $md5 = $ctx->hexdigest;

    DEBUG( "md5 of [$filename] is [$md5]" );
    
    return $md5;
}

sub cleanup {
    my $self = shift;
    File::Path::rmtree(
        [
            $self->unpack_root,
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
