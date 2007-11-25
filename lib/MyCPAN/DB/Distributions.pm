package MyCPAN::DB::Distributions;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("distributions");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "author",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "filename",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "md5",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "release_date",
  { data_type => "DATETIME", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04004 @ 2007-11-25 03:18:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CCm2iHIbt4z9nf5m23t/dw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
