package MyCPAN::Script::Indexer;
use Moose;
use MooseX::Getopt;
use Moose::Util::TypeConstraints;

use Data::Dumper;
use MyCPAN::Distribution;
use Log::Log4perl qw(:easy);
use Perl6::Junction qw(any);

with 'MooseX::Getopt';

my %LOG_LEVELS = (
    error   => $ERROR,
    warning => $WARN,
    info    => $INFO,
    debug   => $DEBUG,
);

subtype 'LogLevel' 
  => as 'Num',
  => where { $_ == any(values %LOG_LEVELS) };

coerce 'LogLevel' 
  => from 'Str',
  => via { $LOG_LEVELS{$_} };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'LogLevel' => '=s'
);

has 'dists' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    required   => 1,
    auto_deref => 1,
);

has 'log_level' => (
    isa     => 'LogLevel',
    is      => 'ro',
    default => 'error',
    coerce  => 1,
);

sub BUILD {
    my $self = shift;
    $self->_setup_log;
    $SIG{__WARN__} = sub { WARN (@_) };
}

sub _setup_log {
    my $self = shift;
    Log::Log4perl->easy_init($self->log_level);
}

sub run {
    my $self = shift;
    foreach my $filename ($self->dists) {
        INFO ( "examining [$filename]" );
        eval { 
            $self->index_dist($filename);
            INFO( "successfully indexed [$filename] " );
        };
        ERROR( "error indexing $filename: $@" ) if $@;
    }
}

sub index_dist {
    my $self = shift;
    my $filename = shift;

    my $dist = MyCPAN::Distribution->new(filename => $filename);
    
    # how haskelly.  i have to force these to evaluate
    $dist->md5;
    $dist->meta_yml;
    $dist->module_files;
    $dist->module_versions;
    
    print "Indexed $filename\n";
    print Dumper($dist);
    
    return $dist;
}

1;
