#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 20;

use ok 'MetaCPAN::Distribution';
my $dist;

sub assert_unset($) {
    my $thingie = shift;
    ok !$dist->{$thingie}, "no $thingie yet";
}

# XXX: no.
my $test_dist = '/cpan/authors/id/J/JR/JROCKWAY/Angerwhale-0.062.tar.gz';

$dist = MetaCPAN::Distribution->new( filename => $test_dist );
isa_ok $dist, 'MetaCPAN::Distribution';

# test laziness
assert_unset 'dist_dir';
assert_unset 'meta_yml';
assert_unset 'md5';
assert_unset 'module_files';
assert_unset 'manifest';
assert_unset 'module_versions';

# try md5, shouldn't trigger extraction
ok $dist->md5, 'we have an md5';
assert_unset 'dist_dir';

# get the path_to Makefile.PL
my $makefile = $dist->path_to('Makefile.PL'); # and the unpack happens!
like $makefile, qr{/tmp/.+/Makefile.PL$}, 'got the makefile!';
ok -e $makefile, 'it exists';
ok -d $dist->dist_dir;

# still should be lazy
assert_unset 'meta_yml';
assert_unset 'module_files';
assert_unset 'module_versions';

my $module_versions = $dist->module_versions;
is $module_versions->{Angerwhale}, '0.062', 'got module_versions';

assert_unset 'meta_yml';
my $meta = $dist->meta_yml;

ok ref $meta, 'got meta';
is $meta->{name}, 'Angerwhale';
