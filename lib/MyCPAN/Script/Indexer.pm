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
    foo     => 1,
);

subtype 'LogLevel' 
  => as 'Num',
  => where { $_ == any(values %LOG_LEVELS) };

coerce 'LogLevel' 
  => from 'Str',
  => via { $LOG_LEVELS{$_} };

has 'dists' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    required   => 1,
    auto_deref => 1,
);

has 'log_level' => (
    isa     => 'LogLevel',
    is      => 'ro',
    default => $ERROR,
);

sub _setup_log {
    my $self = shift;
    Log::Log4perl->easy_init($self->log_level);
}

sub run {
    my $self = shift;
    foreach my $filename ($self->dists) {
        eval {
            my $dist = MyCPAN::Distribution->new(filename => $filename);
            print "Indexed $filename\n";
            print Dumper($dist);
        };
        warn "error indexing $filename: $@";
    }
}

1;
