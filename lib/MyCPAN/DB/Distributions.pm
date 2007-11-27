package MyCPAN::DB::Distributions;

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
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to( author => 'MyCPAN::DB::Authors' );
__PACKAGE__->has_many( modules => 'MyCPAN::DB::Modules', 'distribution' );
__PACKAGE__->has_many(
    files =>
      'MyCPAN::DB::DistributionManifest',
    'distribution'
);
__PACKAGE__->has_many(
    prerequisites =>
      'MyCPAN::DB::DistributionPrerequisites',
    'distribution'
);
__PACKAGE__->has_many(
    metadata =>
      'MyCPAN::DB::DistributionMetadata',
    'distribution'
);

1;

