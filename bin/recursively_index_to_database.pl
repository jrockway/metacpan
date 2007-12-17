#!/usr/bin/env perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use MetaCPAN::Script::IndexToDatabase::Recursive;
MetaCPAN::Script::IndexToDatabase::Recursive->new_with_options->run;
