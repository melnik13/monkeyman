package MonkeyMan::Configuration;

use strict;
use warnings;

# Use Moose and be happy :)
use Moose;
use MooseX::Aliases;
use namespace::autoclean;

# Inherit some essentials
with 'MonkeyMan::Essentials';

use MonkeyMan::Constants qw(:filenames);

# Use 3rd-party libraries
use Config::General qw(ParseConfig);



has 'configuration_tree' => (
    is          => 'ro',
    isa         => 'HashRef',
    reader      => 'get_configuration',
    writer      => '_set_configuration',
    builder     => '_build_configuration_tree',
    alias       => 'tree',
    required    => 1
);



__PACKAGE__->meta->make_immutable;

1;
