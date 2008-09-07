package MetaCPAN::Script::IndexToDatabase;
use Moose;

use MetaCPAN::DB;
use DateTime;
use Log::Log4perl qw(:easy);

extends 'MetaCPAN::Script::Indexer';
with 'MetaCPAN::Script::Role::WithDatabase';

has '_indexing_run' => (
    isa => 'MetaCPAN::DB::IndexingRuns',
    is  => 'rw',
);

has 'skip_duplicates' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { 1 },
);

sub BUILD {
    my $self = shift;
    $self->_indexing_run($self->_schema->resultset('IndexingRuns')->create({
        indexing_started => DateTime->now,
    }));
}

sub DEMOLISH {
    my $self = shift;
    $self->_indexing_run->update({
        indexing_ended => DateTime->now,
    });
}

override 'index_dist' => sub {
    my ($self, $filename) = @_;
    my $schema = $self->_schema;
    my $dist = MetaCPAN::Distribution->new(filename => $filename);

    # skip duplicates
    if($self->skip_duplicates &&
         $schema->resultset('Distributions')->
           search( { md5 => $dist->md5 } )->count > 0)
      {
          DEBUG( "Skipping $filename; already indexed");
          return;
      }

    $schema->txn_do(
        sub {
            # add author
            $filename =~ m{id/[A-Za-z]/[A-Za-z]{2}/([A-Za-z]+)/};
            my $pause = $1 || 'NULL';

            my $db_author = $schema->resultset('Authors')->find_or_create({
                pause_id => uc $pause,
            });

            # add dist
            my $db_dist = $db_author->create_related( distributions => {
                filename     => $dist->filename,
                md5          => $dist->md5,
                release_date => $dist->date || DateTime->now,
                indexing_run => $self->_indexing_run,
            });

            # add modules
            foreach my $module ($dist->modules){
                $db_dist->create_related( modules => {
                    package => $module,
                    version => $dist->module_version($module),
                });
            }

            # add manifest / checksums
            my %files = $dist->file_checksums;
            foreach my $file (keys %files){
                $db_dist->create_related( files => {
                    path    => $file,
                    sha1sum => $files{$file},
                });
            }

            # add prereqs
            my %requires       = %{$dist->meta_yml->{requires} || {}};
            my %build_requires = %{$dist->meta_yml->{build_requires} || {}};

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
        });
};

1;
