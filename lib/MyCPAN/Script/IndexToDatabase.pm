package MyCPAN::Script::IndexToDatabase;
use Moose;

use MyCPAN::DB;
use Digest::MD5 qw(md5_hex);
use DateTime;

extends 'MyCPAN::Script::Indexer';

has 'database' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has '_schema' => (
    is      => 'rw',
    isa     => 'MyCPAN::DB',
    default => sub { MyCPAN::DB->connect($_[0]->database) },
);

override 'index_dist' => sub {
    my ($self, $filename) = @_;
    my $schema = $self->_schema;
    my $dist = MyCPAN::Distribution->new(filename => $filename);
    
    $schema->txn_do(
        sub {
            # for testing only
            my $db_author = $schema->resultset('Authors')->find_or_create({ 
                pause_id => 'NULL',
                name     => 'Null Author',
            });
            
            my $db_dist = $db_author->create_related( distributions => {
                filename     => $dist->filename,
                md5          => $dist->md5,
                # normally populated by modules@ mailing list parser
                release_date => DateTime->now, 
            });

            my $modules = $dist->module_versions;
            foreach my $module (keys %$modules){
                $db_dist->create_related( modules => {
                    package => $module,
                    version => $modules->{$module},
                });
            }
        }
    );
};

1;
