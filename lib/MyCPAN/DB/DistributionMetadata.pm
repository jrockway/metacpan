package MyCPAN::DB::DistributionMetadata;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("distribution_metadata");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "distribution",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "key",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "value",
  { data_type => "TEXT", is_nullable => 1, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to( distribution => 'MyCPAN::DB::Distributions' );

1;
