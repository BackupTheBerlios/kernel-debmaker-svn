#!/usr/bin/perl

# This script runs the kernel-debmaker test suite.





# TODO test everything in the examples/ directory with this test suite
# TODO grab exotic kernel configurations from the net (2.4, etc...).
#      patches: get ckx and acx patches to test patching.
# TODO log
# TODO bad cases to test:
#      -> no debianized module sources
#      -> files not here
#      -> some modules fail to build
#      -> working dir parameter w/wo slash at the end
#      -> xml file argument stress

use strict;
use warnings;
#use diagnostics -verbose;

use Test::Builder;



print "starting kernel-debmaker test suite ...\n\n";
my $test = Test::Builder->new;
# set tests total
$test->plan(tests => 2);

# run tests
$test->ok(0, "kernel.xml not here");
$test->ok(1, "-f not used");

exit 0;
