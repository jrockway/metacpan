package MetaCPAN::Script::Role::WithDatabase;
use Moose::Role;
use Moose::Util::TypeConstraints;
use MetaCPAN::DB;

subtype DSN => as Str => where { /DBI:/i };

has 'database' => (
    is       => 'ro',
    isa      => 'DSN',
    required => 1,
);

has '_schema' => (
    is      => 'rw',
    isa     => 'MetaCPAN::DB',
    lazy    => 1,
    default => sub { MetaCPAN::DB->connect($_[0]->database) },
);

1;
