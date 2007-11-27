#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 18;

use ok 'MyCPAN::Distribution::Full';
my $dist;

sub assert_unset($) {
    my $thingie = shift;
    ok !$dist->{$thingie}, "no $thingie yet";
}

# XXX: no.
my $test_dist = '/cpan/authors/id/J/JR/JROCKWAY/Angerwhale-0.062.tar.gz';

$dist = MyCPAN::Distribution::Full->new( filename => $test_dist );
isa_ok $dist, 'MyCPAN::Distribution::Full';

assert_unset 'build_file';
assert_unset 'build_file_output';
assert_unset 'build_output';
assert_unset 'blib';
assert_unset 'module_files';
assert_unset 'dist_dir';

is $dist->build_file, 'Build.PL', 'got Build.PL';
assert_unset 'module_files';
assert_unset 'blib';
assert_unset 'build_output';

ok $dist->build_output;
assert_unset 'blib';
assert_unset 'module_files';

ok $dist->blib;
assert_unset 'module_files';

ok $dist->module_files;

