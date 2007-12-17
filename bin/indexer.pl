#!/usr/bin/env perl
use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use MetaCPAN::Script::Indexer;
MetaCPAN::Script::Indexer->new_with_options->run;
