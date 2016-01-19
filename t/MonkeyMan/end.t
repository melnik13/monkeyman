#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib("$FindBin::Bin/../../lib");

use MonkeyMan;
use MonkeyMan::Constants qw(:version);

use Test::More (tests => 1);

my $monkeyman = MonkeyMan->new(
    app_code            => undef,
    app_name            => 'end.t',
    app_description     => 'MonkeyMan testing script',
    app_version         => MM_VERSION,
);

# I'd like to make sure that the END section hasn't been overriden by
# the framework on the stage of its initialization...

END {
    ok(1)
}
