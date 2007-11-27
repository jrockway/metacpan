package MyCPAN::Script::IndexToDatabase;
use Moose;

use MyCPAN::DB;
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
    lazy    => 1,
    default => sub { MyCPAN::DB->connect($_[0]->database) },
);

override 'index_dist' => sub {
    my ($self, $filename) = @_;
    my $schema = $self->_schema;
    my $dist = MyCPAN::Distribution->new(filename => $filename);
    
    $schema->txn_do(
        sub {
            # add author
            my $db_author = $schema->resultset('Authors')->find_or_create({ 
                pause_id => 'NULL', # for testing only
                name     => 'Null Author',
            });
            
            # add dist
            my $db_dist = $db_author->create_related( distributions => {
                filename     => $dist->filename,
                md5          => $dist->md5,
                # normally populated by modules@ mailing list parser
                release_date => DateTime->now, 
            });

            # add modules
            foreach my $module ($dist->modules){
                $db_dist->create_related( modules => {
                    package => $module,
                    version => $dist->module_version($module),
                });
            }

            # add manifest
            foreach my $file ($dist->manifest){
                $db_dist->create_related( files => {
                    path => $file,
                });
            }
            
            # add prereqs
            my %requires       = %{$dist->meta_yml->{requires}};
            my %build_requires = %{$dist->meta_yml->{build_requires}};
            
            while(my ($module, $version) = each %requires){
                $db_dist->create_related( prerequisites => {
                    module     => $module,
                    version    => $version,
                    build_only => 0,
                });
            }
            
            while(my ($module, $version) = each %build_requires){
                $db_dist->create_related( prerequisites => {
                    module     => $module,
                    version    => $version,
                    build_only => 1,
                });
            }

            # add other info from META.yml that's easy to extract
            # TODO: translate something like:
            #   { foo => { bar => [qw/baz quux/], fooo => 'bar' } }
            # to
            #   foo.bar  => baz
            #   foo.bar  => quux
            #   foo.fooo => bar
            # sort of like clearsilver's HDF
            my %meta = $dist->meta_yml;
            my @stringy_keys = grep { !ref $meta{$_} } keys %meta;
            foreach my $key (@stringy_keys){
                $db_dist->create_related( metadata => {
                    key   => $key,
                    value => $meta{$key},
                });
            }
        }
    );
};

1;
