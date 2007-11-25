#!/usr/bin/env perl
use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use Log::Log4perl qw(:easy);
use MyCPAN::Indexer;

Log::Log4perl->easy_init( $ERROR );
MyCPAN::Indexer->run( @ARGV );
