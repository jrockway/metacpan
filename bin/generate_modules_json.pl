use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use MetaCPAN::Script::Export::ModulesToJSON;
MetaCPAN::Script::Export::ModulesToJSON->new_with_options->run;
