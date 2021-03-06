#!/usr/bin/env perl

use strict;
use warnings;

use MonkeyMan;

use Test::More (tests => 2);



my $monkeyman = MonkeyMan->new(
    app_code            => undef,
    app_name            => 'get_cloudstack.t',
    app_description     => 'MonkeyMan::get_cloudstack() testing script',
    app_version         => $MonkeyMan::VERSION
);

ok($monkeyman->get_cloudstack == $monkeyman->get_cloudstack);
ok($monkeyman->get_cloudstack == $monkeyman->get_cloudstack($monkeyman->get_cloudstack_plug->get_actor_default));
