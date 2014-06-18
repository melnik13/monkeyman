package MonkeyMan::CloudStack::Elements::Domain;

use strict;
use warnings;

use MonkeyMan::Constants;

use Moose;
use MooseX::UndefTolerant;
use namespace::autoclean;

with 'MonkeyMan::CloudStack::Elements::_common';



sub _load_full_list_command {
    return({
        command => 'listDomains',
        listall => 'true'
    });
}

sub _generate_xpath_query {

    my($self, %parameters) = @_;

    return($self->error("Required parameters haven't been defined"))
        unless(%parameters);

    if(ref($parameters{'find'}) eq 'HASH') {
        if($parameters{'find'}->{'attribute'} eq 'RESULT') {
            return("/listdomainsresponse/domain");
        } else {
            return("/listdomainsresponse/domain[" .
                $parameters{'find'}->{'attribute'} . "='" .
                $parameters{'find'}->{'value'} . "']"
            );
        }
    }

    return($self->error("I don't understand what you're asking about"));

}


__PACKAGE__->meta->make_immutable;

1;

