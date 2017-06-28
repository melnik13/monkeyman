package MaitreD::Controller::API::V1::ProvisioningAgreement;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'Mojolicious::Controller';

use HyperMouse::Schema::ValidityCheck::Constants ':ALL';
use Method::Signatures;
use TryCatch;
use Switch;
use Data::Dumper;
use MaitreD::Extra::API::V1::TemplateSettings;

method list {
    my $settings         = $MaitreD::Extra::API::V1::TemplateSettings::settings;
    my $json             = {};
    my $mask_permitted_d = 0b000111; # FIXME: implement HyperMosuse::Schema::PermissionCheck and define the PC_* constants
    my $mask_validated_d = VC_NOT_REMOVED & VC_NOT_PREMATURE & VC_NOT_EXPIRED;
    my $mask_permitted_f = 0b000111;
    my $mask_validated_f = VC_NOT_REMOVED & VC_NOT_PREMATURE & VC_NOT_EXPIRED;
    my $tmpl_rs;
    my $datatable_params = $self->datatable_params;

    switch($self->stash->{'filter'}) {
        case('all')         {
            $mask_validated_d = VC_NOT_REMOVED & VC_NOT_PREMATURE;
            $mask_validated_f = VC_NOT_REMOVED & VC_NOT_PREMATURE;
        }
        case('active')      {
            $mask_validated_d = VC_NOT_REMOVED & VC_NOT_PREMATURE & VC_NOT_EXPIRED;
            $mask_validated_f = VC_NOT_REMOVED & VC_NOT_PREMATURE & VC_NOT_EXPIRED;
        }
        case('archived')    {
            $mask_validated_d = VC_NOT_REMOVED & VC_NOT_PREMATURE;
            $mask_validated_f = VC_NOT_REMOVED & VC_NOT_PREMATURE & VC_EXPIRED;
        }
    }
    
    switch($self->stash->{'related_element'}) {

        case('person') {

            my $person_id =
                ($self->stash->{'related_id'} ne '@') ?
                 $self->stash->{'related_id'} :
                 $self->stash->{'authorized_person_result'}->id;

            $tmpl_rs =
                    $self
                        ->hm_schema
                        ->resultset('Person')
                        ->search({ id => $person_id })
                        ->filter_validated(mask => VC_NOT_REMOVED)
                        ->search_related_deep(
                            resultset_class            => 'ProvisioningAgreement',
                            fetch_permissions_default  => $mask_permitted_f,
                            fetch_validations_default  => $mask_validated_f,
                            search_permissions_default => $mask_permitted_d,
                            search_validations_default => $mask_validated_d,
                            callout => [ 'Person->-((((@->-Corporation->-Contractor)-&-(@->-Contractor))-[client|provider]>-ProvisioningAgreement)-&-(@->-ProvisioningAgreement))' => { } ]
                        );
            
        
        } case('contractor') {
        
            my $person_id =
                ($self->stash->{'related_id'} ne '@') ?
                 $self->stash->{'related_id'} :
                 $self->stash->{'authorized_person_result'}->id;

            $tmpl_rs =
                    $self
                        ->hm_schema
                        ->resultset('Person')
                        ->search({ id => $person_id })
                        ->filter_validated(mask => VC_NOT_REMOVED)
                        ->search_related_deep(
                            resultset_class            => 'ProvisioningAgreement',
                            fetch_permissions_default  => $mask_permitted_f,
                            fetch_validations_default  => $mask_validated_f,
                            search_permissions_default => $mask_permitted_d,
                            search_validations_default => $mask_validated_d,
                            callout => [ 'Contractor-[client|provider]>-ProvisioningAgreement' => { } ]
                        );
        
        }
    }
    
    my $columns = $settings->{'provisioning_agreement'}->{'table'}->{'columns'};
                
    @{ $json->{'data'} } = map {
        my $hash = {};
        
        for my $col ( keys %$columns ){
            my $name = $columns->{$col}->{'db_name'};
            my $fh   = $columns->{$col}->{'db_value'};

            if ( defined $name && defined $fh && ref $fh eq 'CODE' ) {
                $hash->{ $name } =
                    $fh->( $self, $_ );                        
            }
            elsif( defined $name ){
                $hash->{'name'} = $_->$name;
            }
        }
        
        $hash;
    }
    @{ $json->{'data'} };
    
    $json->{'recordsFiltered'} = $json->{'recordsTotal'}; 
            
    $self->render( json => $json );      
}


__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;