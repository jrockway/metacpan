package MyCPAN::DB::Modules;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("modules");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "distribution",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "package",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "version",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to( distribution => 'MyCPAN::DB::Distributions' );

1;
