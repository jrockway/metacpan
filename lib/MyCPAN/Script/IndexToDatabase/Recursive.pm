package MyCPAN::Script::IndexToDatabase::Recursive;
use Moose;
use MooseX::Types::Path::Class qw(Dir);
use File::Find;

extends 'MyCPAN::Script::IndexToDatabase';

has '+dists' => (
    required => 0,
);

has 'path' => (
    required => 1,
    isa      => Dir,
    is       => 'ro',
    default  => $ENV{PWD},
    coerce   => 1,
);

sub BUILD {
    my $self = shift; 

    # TODO: this should be an iterator of files to examine, not a list
    my @files;
    find ( 
        sub { 
            my $f = $File::Find::name;
            push @files, $f if -r $f && !-d $f && 
              $f !~ /(?:README|META|CHECKSUMS)$/i
          }, 
        $self->path 
    );
    
    $self->{dists} = [@files];
}

1;
