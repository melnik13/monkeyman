package MonkeyMan::CloudStack::API::Element::ISO;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with 'MonkeyMan::CloudStack::API::Roles::Element';

use Method::Signatures;



our %vocabulary_tree = (
    type => 'ISO',
    name => 'iso',
    entity_node => 'iso',
    actions => {
        list => {
            request => {
                command             => 'listIsos',
                async               => 0,
                paged               => 1,
                parameters          => {
                    filter_by_type => {
                        required            => 1,
                        command_parameters  => { 'isofilter' => '<%VALUE%>' }
                    },
                    all => {
                        required            => 0,
                        command_parameters  => { 'listall' => 'true' },
                    },
                    filter_by_id => {
                        required            => 0,
                        command_parameters  => { 'id' => '<%VALUE%>' },
                    },
                    filter_by_name => {
                        required            => 0,
                        command_parameters  => { 'name' => '<%VALUE%>' },
                    },
                    filter_by_zoneid => {
                        required            => 0,
                        command_parameters  => { 'zoneid' => '<%VALUE%>' },
                    },
                }
            },
            response => {
                response_node   => 'listisosresponse',
                results         => {
                    element         => {
                        return_as       => [ qw( dom element id ) ],
                        queries         => [ '/<%OUR_RESPONSE_NODE%>/<%OUR_ENTITY_NODE%>' ],
                        required        => 0,
                        multiple        => 1
                    },
                    id              => {
                        return_as       => [ qw( value ) ],
                        queries         => [ '/<%OUR_RESPONSE_NODE%>/<%OUR_ENTITY_NODE%>/id' ],
                        required        => 0,
                        multiple        => 1
                    },
                }
            }
        },
    }
);



__PACKAGE__->meta->make_immutable;

1;
