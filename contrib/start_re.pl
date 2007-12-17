use lib 'lib';
use MetaCPAN::DB;
my $s = MetaCPAN::DB->connect('DBI:SQLite:database');
sub authors { $s->resultset('Authors') }
sub distros { $s->resultset('Distributions') }
sub runs    { $s->resultset('IndexingRuns') }

$s;
