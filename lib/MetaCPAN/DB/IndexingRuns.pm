package MetaCPAN::DB::IndexingRuns;
use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table("runs");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef,
    is_auto_increment => 1 },
  "indexing_started",
  { data_type => "datetime", is_nullable => 0, size => undef },
  "indexing_ended",
  { data_type => "datetime", is_nullable => 1, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many( distributions => 'MetaCPAN::DB::Distributions',
                       'indexing_run' );

1;
