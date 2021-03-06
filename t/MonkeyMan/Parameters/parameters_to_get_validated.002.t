#!/usr/bin/env perl

use strict;
use warnings;

use MonkeyMan;

my $monkeyman;

use Test::More tests => 1;
use Class::Unload;
use TryCatch;



# parameters_to_get_validated should be enough!

$monkeyman = MonkeyMan->new(
    app_code            => undef,
    app_name            => 'parameters_to_get_validated.002.t',
    app_description     => 'MonkeyMan::Parameters::parameters_to_get_validated testing script',
    app_version         => $MonkeyMan::VERSION,
    parameters_to_get_validated => <<__YAML__
---
w|whatever:
  whatever:
__YAML__
);

try {
    $monkeyman->get_parameters->get_whatever;
    pass('whatever');
} catch($e) {
    fail('whatever: ' . $e);
}

done_testing;
