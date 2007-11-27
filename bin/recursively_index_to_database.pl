#!/usr/bin/env perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use MyCPAN::Script::IndexToDatabase::Recursive;
MyCPAN::Script::IndexToDatabase::Recursive->new_with_options->run;
