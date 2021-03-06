package MonkeyMan::CloudStack::API::Roles::Element;

use strict;
use warnings;

# Use Moose and be happy :)
use Moose::Role;
use namespace::autoclean;

with 'MonkeyMan::Roles::WithTimer';

use MonkeyMan::Logger qw(mm_sprintf);
use MonkeyMan::Exception qw(
    UndeterminableElementType
    MagicWordsArentDefined
    InvalidParametersValue
);

use Method::Signatures;



has 'logger' => (
    is          => 'ro',
    isa         => 'MonkeyMan::Logger',
    reader      =>   '_get_logger',
    writer      =>   '_set_logger',
    builder     => '_build_logger',
    lazy        => 1,
    required    => 0
);

method _build_logger {
    return(MonkeyMan::Logger->instance);
}



has 'api' => (
    is          => 'ro',
    isa         => 'MonkeyMan::CloudStack::API',
    reader      =>  'get_api',
    writer      => '_set_api',
    predicate   => '_has_api',
    required    => 1,
);



has 'type' => (
    is          => 'ro',
    isa         => 'MonkeyMan::CloudStack::Types::ElementType',
    reader      =>    'get_type',
    writer      =>   '_set_type',
    builder     => '_build_type',
    lazy        => 1
);

method _build_type {

    my($type) = blessed($self) =~ /::((?!.*::.*).+)$/;

    if(defined($type)) {
        return($type);
    } else {
        (__PACKAGE__ . '::Exception::UndeterminableElementType')->throwf(
            "Can't determine the %s element's type.", $self
        );
    }

}

around 'get_type' => sub {

    my $orig = shift;
    my $self = shift;

    if(@_) {
        return($self->get_api->translate_type(type => $self->$orig, @_));
    } else {
        return($self->$orig);
    }
};



has 'vocabulary' => (
    is          => 'ro',
    isa         => 'MonkeyMan::CloudStack::API::Vocabulary',
    reader      =>    'get_vocabulary',
    writer      =>   '_set_vocabulary',
    builder     => '_build_vocabulary',
    lazy        => 1,
    handles     => [ qw(
        vocabulary_lookup
        compose_command
        interpret_response
    ) ]
);

method _build_vocabulary {

    return($self->get_api->get_vocabulary($self->get_type));

}



has 'criterions' => (
    is          => 'ro',
    isa         => 'HashRef',
    reader      =>    'get_criterions',
    writer      =>   '_set_criterions',
    predicate   =>    'has_criterions',
    builder     => '_build_criterions',
    lazy        => 1
);

method _build_criterions {
    return({});
}



has 'dom_updated' => (
    is          => 'rw',
    isa         => 'Int',
    reader      =>    'get_dom_updated',
    writer      =>   '_set_dom_updated',
    predicate   =>    'has_dom_updated',
    clearer     => '_clear_dom_updated',
    builder     => '_build_dom_updated',
    lazy        => 1
);

method _build_dom_updated {
    if($self->has_dom) {
        return(${$self->get_time_started}[0]);
    } else {
        return(0);
    }
}

has 'dom_best_before' => (
    is          => 'rw',
    isa         => 'Int',
    reader      =>    'get_dom_best_before',
    writer      =>   '_set_dom_best_before',
    predicate   =>    'has_dom_best_before',
    clearer     => '_clear_dom_best_before',
    builder     => '_build_dom_best_before',
    lazy        => 1
);

method _build_dom_best_before {
    my $default_cache_time = $self
                                ->get_api
                                    ->get_configuration
                                        ->{'cache'}
                                            ->{'default_cache_time'};
}

has 'dom' => (
    is          => 'rw',
    isa         => 'XML::LibXML::Document',
    reader      =>    'get_dom',
    writer      =>   '_set_dom',
    predicate   =>    'has_dom',
    clearer     => '_clear_dom',
    builder     => '_build_dom',
    lazy        => 1
);

method _build_dom {
    XML::LibXML::Document->new;
}

around '_clear_dom' => sub {
    my $orig = shift;
    my $self = shift;

    $self->_clear_dom_updated;
    $self->$orig;
};

around '_set_dom' => sub {
    my $orig = shift;
    my $self = shift;
    my $dom = shift;

    my $message = $self->has_dom ?
        mm_sprintf(
            "The %s element already have the %s DOM loaded, " .
            "overloading it with the %s DOM",
            $self, $self->get_dom, $dom
        ) :
        mm_sprintf(
            "The %s element's will be loaded with the %s DOM",
            $self, $dom
        );

    $self->_set_dom_updated($self->get_time_current_rough);
    $self->$orig($dom);

};

before 'get_dom' => sub {
    my $orig = shift;
    my $self = shift;
};

method refresh_dom {

    my $logger = $self->_get_logger;

    my $id = $self->get_id;
    unless(defined($id)) {
        $logger->tracef(
            "The %s %s can't be refreshed, as it's ID hasn't been set",
            $self,
            $self->get_type(noun => '1')
        );
        return(undef);
    }

    $logger->tracef(
        "Refreshing the %s %s's (has ID = %s) DOM",
        $self,
        $self->get_type(noun => '1'),
        $id
    );

    $self->_clear_dom;

    foreach my $dom ($self->get_api->get_doms(
        type        => $self->get_type,
        criterions  => { id => $id }
    )) {
        $self->_set_dom($dom);
    }

    return($self->get_dom);

}

=head2 C<is_dom_expired()>

Requires the anonymous C<Str> to be passed as the only parameter. Finds out if
the element's DOM expired and needs to be refreshed.

If it equals to 'C<never>', the method always returns false, so the DOM is
always being considered as up to date.

    ok(!$self->is_dom_expired('never') );

If it equals to 'C<always>', the method always returns true, so the DOM is being
considered as outdated at any moment.

    ok( $self->is_dom_expired('always') );

If it equals to some number (C<N>), the method returns true if the DOM has been
refreshed not later than at C<N> seconds of Unix Epoch, so it's considered as
expired.

    # Let's assume it's 1000 seconds of Unix Epoch now
    # and the DOM has been refreshed at 300
    #
    ok( $self->is_dom_expired(299) );
    ok( $self->is_dom_expired(300) );
    ok(!$self->is_dom_expired(301) );

If it equals to C<+N>, the method returns true (expired) if the DOM update time
plus C<N> is not greater than the current time.

    # Let's assume it's 1000 seconds of Unix Epoch now
    # and the DOM has been refreshed at 300
    #
    ok( $self->is_dom_expired('+699') );
    ok( $self->is_dom_expired('+700') );
    ok(!$self->is_dom_expired('+701') );

If equals to C<-N>, the method returns true (expired) if the DOM has been
refreshed not less than N seconds ago.

    # Let's assume it's 1000 seconds of Unix Epoch now
    # and the DOM has been refreshed at 300
    #
    ok( $self->is_dom_expired('-701') );
    ok( $self->is_dom_expired('-700') );
    ok(!$self->is_dom_expired('-699') );

=cut

method is_dom_expired(Maybe[Str] $best_before) {

    $best_before = '+' . $self->get_dom_best_before
        unless(defined($best_before));
    my $is_expired = 0;
    my $now = $self->get_time_current_rough;
    if($best_before =~ /^\s*([\+\-])?\s*(\d+)\s*$/) {
        $is_expired = 1 if(
            (
                defined($1) && ($1 eq '+') &&
                    ($self->get_dom_updated + $2 <= $now)
            ) || (
                defined($1) && ($1 eq '-') &&
                    ($self->get_dom_updated <= $now - $2)
            ) || (
              ! defined($1) &&
                    ($self->get_dom_updated <= $2)
            )
        );
    } elsif ($best_before =~ /^\s*never\s*$/i) {
        $is_expired = 0;
    } elsif ($best_before =~ /^\s*always\s*$/i) {
        $is_expired = 1;
    } else {
        (__PACKAGE__ . '::Exception::InvalidParametersValue')->throwf(
            "Invalid parameter's value: %s", $best_before
        )
    }
    $self->_get_logger->tracef(
        "The DOM of %s has been refreshed at %s, " .
        "so it's considered as %s if it's best before %s",
            $self,
            $self->get_dom_updated,
            ($is_expired ? 'expired' : 'up to date'),
            $best_before
    );
    return($is_expired);

}



has 'id' => (
    is          => 'rw',
    isa         => 'Maybe[Str]',
    reader      =>    'get_id',
    writer      =>   '_set_id',
    predicate   =>    'has_id',
    builder     => '_build_id',
    lazy        => 1
);

method _build_id {
    $self->get_id;
}

around 'get_id' => sub {
    my $orig = shift;
    my $self = shift;

    return($self->get_value('/id'));
};

method get_value(
    Str         $q!,
    Str         :$query?        = $q,
    Maybe[Bool] :$fatal?        = 0,
    Maybe[Str]  :$best_before
) {
    my @values = $self->get_values($query, fatal => $fatal, best_before => $best_before);
    if(@values > 1) {
        #FIXME: Throw a warning
    } elsif(@values < 1) {
        #FIXME: Throw an exception if $fatal
    }
    return($values[0]);
}
    
method get_values(
    Str         $q!,
    Str         :$query?        = $q,
    Maybe[Bool] :$fatal?        = 0,
    Maybe[Str]  :$best_before
) {
    return(
        $self->qxp(
            query       => $query,
            return_as   => 'value'
        )
    );
}



method monkeyman_info {
    my $information = $self->get_vocabulary->vocabulary_lookup(
        words       => [ 'information' ],
        fatal       => 0,
        resolve     => 0
    );
    return(join('|', map { sprintf("%s:%s", $_, $self->get_value($information->{ $_ })); } (sort(keys( %{ $information })))));
}



#
# Proxy methods go here...
#

method perform_action(
    Str                                         :$action!,
    Maybe[HashRef]                              :$parameters,
    Maybe[HashRef]                              :$macros,
    HashRef|ArrayRef[HashRef]                   :$requested!,
    Maybe[Str]                                  :$best_before
) {

    my $macros_complete = { defined($macros) ? %{ $macros } : () };

    $macros_complete->{'OUR_ID'} = $self->get_id;

    return($self->get_api->perform_action(
        type        => $self->get_type,
        action      => $action,
        parameters  => $parameters,
        macros      => $macros_complete,
        requested   => $requested,
        best_before => $best_before
    ));

}

method get_related(
    Str                                         :$related!,
    Maybe[Str]                                  :$best_before,
    Maybe[Bool]                                 :$fatal     = 0,
    MonkeyMan::CloudStack::Types::ReturnAs      :$return_as = 'element'
) {

    return($self->get_api->get_related(
        element     => $self,
        related     => $related,
        fatal       => $fatal,
        best_before => $best_before,
        return_as   => $return_as
    ));

}

method qxp(
    Str                     :$query!,
    XML::LibXML::Document   :$dom = $self->get_dom,
    Maybe[Bool]             :$fatal,
    Maybe[Str]              :$best_before,
    Maybe[Str]              :$return_as
) {

    # FIXME: make the fatal and best_before parameters working!

    my $full_query = sprintf('/%s%s%s',
        $self->get_vocabulary->vocabulary_lookup(
            words       => [ 'entity_node' ],
            fatal       => 1,
            resolve     => 0
        ),
        $query =~ qr(^/) ? '' : '/',
        $query
    );

    my @results = $self->get_api->qxp(
        query       => $full_query,
        dom         => $dom,
        return_as   => $return_as
    );

    return(@results);

}

1;
