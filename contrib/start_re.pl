use lib 'lib';
use MyCPAN::DB;
my $s = MyCPAN::DB->connect('DBI:SQLite:database');
sub authors { $s->resultset('Authors') }
sub distros { $s->resultset('Distributions') }
sub runs    { $s->resultset('IndexingRuns') }

$s;
