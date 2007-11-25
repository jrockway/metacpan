package MyCPAN::DB::Authors;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("authors");
__PACKAGE__->add_columns(
  "id",
  { data_type => 'INTEGER', is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "pause_id",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "email",
  { data_type => "TEXT", is_nullable => 1, size => undef },
  "website",
  { data_type => "TEXT", is_nullable => 1, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( pause => [qw/pause_id/] );
__PACKAGE__->has_many( distributions => 'MyCPAN::DB::Distributions', 'author');

1;
