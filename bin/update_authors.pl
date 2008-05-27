#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use MetaCPAN::Script::AddAuthors;
MetaCPAN::Script::AddAuthors->new_with_options->run;
