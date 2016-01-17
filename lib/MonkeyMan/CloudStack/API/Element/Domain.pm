package MonkeyMan::CloudStack::API::Element::Domain;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with 'MonkeyMan::CloudStack::API::Roles::Element';

use Method::Signatures;



our %_magic_words = (
    find_command    => 'listDomains',
    list_tag_global => 'listdomainsresponse',
    list_tag_entity => 'domain'
);

our %_related = (
    VirtualMachine  => {
        class_name  => 'MonkeyMan::CloudStack::API::Element::VirtualMachine',
        local_key   => 'id',
        foreign_key => 'domainid'
    }
);

func _criterions_to_parameters(
        :$listall,
    Str :$id,
) {
    my %parameters;
    $parameters{'listall'}  = 'true'        if(defined($listall));
    $parameters{'id'}       = $id           if(defined($id));
    return(%parameters);
}



__PACKAGE__->meta->make_immutable;

1;
