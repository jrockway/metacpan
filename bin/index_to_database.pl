#!/usr/bin/env perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use MetaCPAN::Script::IndexToDatabase;
MetaCPAN::Script::IndexToDatabase->new_with_options->run;
