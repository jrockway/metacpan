package MetaCPAN::DB::Distributions;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table("distributions");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "author",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "filename",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "md5",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "release_date",
  { data_type => "datetime", is_nullable => 0, size => undef },
  "indexing_run",
  { data_type => 'INTEGER', is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to( author => 'MetaCPAN::DB::Authors' );
__PACKAGE__->belongs_to( indexing_run => 'MetaCPAN::DB::IndexingRuns' );
__PACKAGE__->has_many( modules => 'MetaCPAN::DB::Modules', 'distribution' );
__PACKAGE__->has_many(
    files =>
      'MetaCPAN::DB::DistributionManifest',
    'distribution'
);
__PACKAGE__->has_many(
    prerequisites =>
      'MetaCPAN::DB::DistributionPrerequisites',
    'distribution'
);
__PACKAGE__->has_many(
    metadata =>
      'MetaCPAN::DB::DistributionMetadata',
    'distribution'
);

1;
