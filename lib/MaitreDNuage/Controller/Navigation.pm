package MaitreDNuage::Controller::Navigation;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'Mojolicious::Controller';

use Method::Signatures;
use TryCatch;



has 'menu_full' => (
    is          => 'rw',
    isa         => 'HashRef',
    reader      =>   '_get_menu_full',
    writer      =>   '_set_menu_full',
    builder     => '_build_menu_full',
    lazy        => 1
);

method _build_menu_full {
    {
        'Dashboard'     => { order => 1, destination => '/' },
        'Agreements'    => { order => 2, destination => {
            'Create New'    => { order => 1, destination => '/service_agreement/new' },
            'List Active'   => { order => 2, destination => '/service_agreement/list_active' },
            'List Archived' => { order => 3, destination => '/service_agreement/list_archived' },
            'List All'      => { order => 4, destination => '/service_agreement/list' }
        } },
        'Services'      => { order => 3, destination => {
            'Order New'     => { order => 1, destination => '/service/new' },
            'List Active'   => { order => 2, destination => '/service/list_active' },
            'List Archived' => { order => 3, destination => '/service/list_archived' },
            'List All'      => { order => 4, destination => '/service/list' }
        } }
    }
}



method build_menu {
    $self->stash(navigation_menu => $self->_get_menu_full);
}


__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
