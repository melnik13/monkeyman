package MaitreD;

use strict;
use warnings;

use Mojo::Base qw(Mojolicious);
use Mojolicious::Plugin::DateTimeDisplay;
use Mojolicious::Plugin::AssetManager;
use HyperMouse;
use MonkeyMan::Exception qw(InvalidParameterSet);
use Method::Signatures;



our $HYPER_MOUSE;



has _hypermouse => method() {
    $HYPER_MOUSE = defined($HYPER_MOUSE) ? $HYPER_MOUSE : HyperMouse->new;
};



method startup {

    $self->plugin('DateTimeDisplay');
    $self->plugin('AssetManager', {
        assets_library => {
            js  => {
                datatables  => [ qw# js/plugins/dataTables/datatables.min.js # ]
            },
            css => {
                toastr      => [ qw# css/plugins/toastr/toastr.min.css # ],
                datatables  => [ qw# css/plugins/dataTables/datatables.min.css # ],
                datepicker  => [ qw# css/plugins/datapicker/datepicker3.css # ],
                summernote  => [ qw# css/plugins/summernote/summernote.css
                                     css/plugins/summernote/summernote-bs3.css # ]
            }
        }
    });

    $self->helper(hypermouse    => sub { shift->app->_hypermouse });
    $self->helper(hm_schema     => sub { shift->app->_hypermouse->get_schema });
    $self->helper(hm_logger     => sub { shift->app->_hypermouse->get_logger });

    my $routes_unauthenticated = $self->routes;
       $routes_unauthenticated->any('/person/login')->to('person#login');
       $routes_unauthenticated->any('/person/signup')->to('person#signup');

    my $routes_authenticated = $self->routes->under->to('person#is_authenticated')
                                            ->under->to('person#load_settings')
                                            ->under->to('navigation#build_menu');
       $routes_authenticated
            ->get('/person/logout')
                ->to(
                    controller  => 'person',
                    action      => 'logout'
                );
       $routes_authenticated
            ->get('/')
                ->to('dashboard#welcome');

    my $routes_authenticated_provisioning_agreement = $routes_authenticated->under('/provisioning_agreement');
       $routes_authenticated_provisioning_agreement
            ->get('/list/:filter/:related_element/:related_id')
                ->to(
                    controller      => 'provisioning_agreement',
                    action          => 'list',
                    filter          => 'active',
                    related_element => 'person',
                    related_id      => '@'
                );

    my $routes_authenticated_person = $routes_authenticated->under('/person');
       $routes_authenticated_person
            ->get('/list/:filter/:related_element/:related_id')
                ->to(
                    controller      => 'person',
                    action          => 'list',
                    filter          => 'active',
                    related_element => 'person',
                    related_id      => '@'
                );

}



1;
