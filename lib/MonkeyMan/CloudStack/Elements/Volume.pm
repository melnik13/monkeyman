package MonkeyMan::CloudStack::Elements::Volume;

use strict;
use warnings;

use MonkeyMan::Constants;
use MonkeyMan::Utils;
use MonkeyMan::CloudStack::Elements::AsyncJob;

use Moose;
use MooseX::UndefTolerant;
use namespace::autoclean;

with 'MonkeyMan::CloudStack::Element';



sub element_type {
    return('volume');
}



sub _load_full_list_command {
    return({
        command => 'listVolumes',
        listall => 'true'
    });
}



sub _load_dom_xpath_query {

    my($self, %parameters) = @_;

    return($self->error("Required parameters haven't been defined"))
        unless(%parameters);

    if($parameters{'attribute'} eq 'FINAL') {
        return("/listvolumesresponse/volume");
    } else {
        return("/listvolumesresponse/volume[" .
            $parameters{'attribute'} . "='" .
            $parameters{'value'} . "']"
        );
    }

}



sub _get_parameter_xpath_query {

    my($self, $parameter) = @_;

    return($self->error("Required parameters haven't been defined"))
        unless(defined($parameter));

    return("/volume/$parameter");

}



sub _find_related_to_given_conditions {

    my($self, $key_element) = @_;

    return($self->error("The key element hasn't been defined"))
        unless(defined($key_element));

    return(
        $key_element->element_type . "id" => $key_element->get_parameter('id')
    );

}



sub create_snapshot {

    my($self, %input) = @_;

    return($self->error("Required parameters haven't been defined"))
        unless(%input);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'log'       => { variable => \$log },
            'cs_api'    => { variable => \$api }
        }
    ); };
    return($self->error($@))
        if($@);

    my $job = eval {
        MonkeyMan::CloudStack::Elements::AsyncJob->new(
            mm  => $mm,
            run => {
                parameters  => {
                    command     => 'createSnapshot',
                    volumeid    => $self->get_parameter('id')
                },
                wait    => $input{'wait'}
            }
        );
    };
    return($self->error(mm_sprintify("Can't MonkeyMan::CloudStack::Elements::AsyncJob->new(): %s", $@)))
        if($@);

    return($job);

}



sub cleanup_snapshots {

    my $self = shift;
    my($keep, $mm, $api, $log);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'log'       => { variable   => \$log },
            'cs_api'    => { variable   => \$api },
            '$keep'     => {
                             variable   => \$keep,
                             value      => shift
            }
        }
    ); };
    return($self->error($@))
        if($@);

    $log->trace(mm_sprintify(
        "Going to cleanup old snapshots for the %s volume (%d snapshot(s) will be kept)",
            $self->get_parameter('id'),
            $keep
    ));

    my $snapshots = $self->find_related_to_me('snapshot', 1);
    return($self->error($self->error_message))
        unless(defined($snapshots));

    my $snapshots_deleted = 0;
    my $snapshots_found = 0;

    foreach my $snapshot (sort { $b->get_parameter('created') cmp $a->get_parameter('created') } (@{ $snapshots })) {
        $log->trace(mm_sprintify(
            "Found the %s snapshot created on %s related to the %s volume",
                $snapshot->get_parameter('id'),
                $snapshot->get_parameter('created'),
                $self->get_parameter('id')
        ));
        if($snapshot->get_parameter('state') eq 'BackedUp') {

            if(++$snapshots_found > $keep) {
                my $job = $snapshot->delete;
                return($self->error($snapshot->error_message))
                    unless(defined($job));
                $log->info(mm_sprintify(
                    "The %s snapshot has been requested for deletion, the %s job has been started",
                        $snapshot->get_parameter('id'),
                             $job->get_parameter('jobid')
                ));
            }

        }
    }

    return($snapshots_deleted);

}



__PACKAGE__->meta->make_immutable;

1;
