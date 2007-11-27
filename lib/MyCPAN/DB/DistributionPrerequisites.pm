package MyCPAN::DB::DistributionPrerequisites;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("distribution_prerequisites");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "distribution",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "module",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "version",
  { data_type => "TEXT", is_nullable => 1, size => undef },
  "build_only",
  { data_type => 'BOOLEAN', is_nullable => 0, size => undef, default => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to( distribution => 'MyCPAN::DB::Distributions' );

1;
