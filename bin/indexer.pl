#!/usr/bin/env perl
use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use MyCPAN::Script::Indexer;
MyCPAN::Script::Indexer->new_with_options->run;
