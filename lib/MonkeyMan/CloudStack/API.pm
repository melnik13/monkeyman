package MonkeyMan::CloudStack::API;

use strict;
use warnings;

use MonkeyMan::Constants;
use MonkeyMan::Utils;

use URI::Encode qw(uri_encode uri_decode);
use Digest::SHA qw(hmac_sha1);
use MIME::Base64;
use WWW::Mechanize;
use XML::LibXML;
use POSIX qw(strftime);

use Moose;
use MooseX::UndefTolerant;
use namespace::autoclean;

with 'MonkeyMan::ErrorHandling';



has 'mm' => (
    is          => 'ro',
    isa         => 'MonkeyMan',
    predicate   => 'has_mm',
    writer      => '_set_mm',
    required    => 'yes'
);



sub BUILD {

    my $self = shift;
    my($mm, $log);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'mm'    => { variable => \$mm },
            'log'   => { variable => \$log }
        });
    };
    return($self->error($@))
        if($@);

    $log->trace(mm_sprintify("CloudStack's API connector has been initialized (MonkeyMan's instance %s)", $mm));

}



sub craft_url {

    my($self, %parameters) = @_;
    my($mm);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'mm'    => { variable => \$mm }
        });
    };
    return($self->error($@))
        if($@);

    my $parameters_string;
    my $output;
    $parameters{'apiKey'} = $mm->configuration('cloudstack::api::api_key');
    foreach my $parameter (sort(keys(%parameters))) {
        $parameters_string  .= (defined($parameters_string) ? '&' : '') . $parameter . '=' .            $parameters{$parameter};
        $output             .= (defined($output)            ? '&' : '') . $parameter . '=' . uri_encode($parameters{$parameter}, 1);
    }
    my $base64_encoded  = encode_base64(hmac_sha1(lc($output), $mm->configuration('cloudstack::api::secret_key'))); chomp($base64_encoded);
    my $url             = $mm->configuration('cloudstack::api::api_address') . '?' . $parameters_string . "&signature=" . uri_encode($base64_encoded, 1);

    return($url);

}



sub run_command {

    my($self, %input) = @_;
    my($mm, $log);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'mm'            => { variable => \$mm },
            'log'           => { variable => \$log },
            '$parameters'   => {
                value           => $input{'parameters'},
                isaref          => 'HASH'
            }
        });
    };
    return($self->error($@))
        if($@);

    # Crafting the URL

    my $url = defined($input{'url'}) ?
        defined($input{'url'}) :
        $self->craft_url(%{ $input{'parameters'} });
    return($self->error($self->error_message))
        unless(defined($url));
    return($self->error("The requested URL is invalid"))
        unless(index($url, $mm->configuration('cloudstack::api::api_address')) == 0);

    # Running the command

    $log->trace(mm_sprintify("Querying CloudStack for %s", defined($input{'url'}) ? $url : $input{'parameters'}));
    $log->trace(mm_sprintify("[CLOUDSTACK] Querying CloudStack for %s", defined($input{'url'}) ? $url : $input{'parameters'}));

    # FIXME - what about to use LWP::UserAgent here?

    my $mech = WWW::Mechanize->new(
        onerror => undef
    );
    my $response = $mech->get($url);
    $log->trace(mm_sprintify("[CLOUDSTACK] Got an HTTP-response: %s", $response->status_line));
    return($self->error(mm_sprintify("Can't %s->get(): %s", $mech, $response->status_line)))
        unless($response->is_success);

    # Parsing the response
 
    my $parser  = XML::LibXML->new();
    my $dom     = eval {
        $parser->load_xml(
            string => ($response->content)
        );
    };
    return($self->error(mm_sprintify("Can't %s->load_xml(): %s", $parser, $@)))
        unless(defined($dom));

    $log->trace(mm_sprintify("CloudStack returned %s", $dom));
    $log->trace(mm_sprintify("[CLOUDSTACK] [XML] %s contains:\n%s", $dom, $dom->toString(1)));

    # Should we wait for an async job?

    my $jobid = eval { $dom->findvalue('/*/jobid'); };
    return($self->error(mm_sprintify("Can't %s->findValue(): %s", $dom, $@)))
        if($@);

    if(defined($input{'options'}->{'wait'}) && ($jobid)) {
 
        my $alarm = time + $input{'options'}->{'wait'};

        $log->debug(mm_sprintify(
            "Waiting till %s for a responce concerning the job %s",
                strftime(MMDateTimeFormat, localtime($alarm)),
                $jobid
        ));

        while(sleep(
            $mm->configuration('time::sleep_while_waiting') ?
                $mm->configuration('time::sleep_while_waiting') :
                MMSleepWhileWaitingForAsyncJobResult
        )) {

            $dom = $self->run_command(
                parameters => {
                    command => 'queryAsyncJobResult',
                    jobid   => $jobid
                }
            );
            return($self->error($self->error_message))
                unless(defined($dom));

            if($input{'options'}->{'wait'} && (time >= $alarm)) {
                $log->warn(mm_sprintify(
                    "A timeout of %d seconds has occured while waiting for %s to be completed",
                        $input{'options'}->{'wait'},
                        $jobid
                ));
                return($dom);
            }

            return($dom)
                if($dom->findvalue('/*/jobstatus'));

        }

    }

    return($dom);

}



sub query_xpath {

    my($self, $dom, $xpath, $results_to) = @_;
    my($mm, $log);

    eval { mm_method_checks(
        'object' => $self,
        'checks' => {
            'mm'            => { variable   => \$mm },
            'log'           => { variable   => \$log },
            '$dom'          => { value      =>  $dom,           error       => "The DOM hasn't been defined" }
#           '$xpath'        => { value      =>  $xpath,         careless    => 1 },
#           '$results_to'   => { value      =>  $results_to,    careless    => 1 }
        });
    };
    return($self->error($@))
        if($@);

    # First of all, let's find out what they've passed to us - a list or a string

    my $queries = [];
    my $results = defined($results_to) ? $results_to : [];

    if(ref($xpath) eq 'ARRAY') {
        $queries = $xpath;
    } else {
        push(@{ $queries }, $xpath);
    }

    foreach my $query (@{ $queries }) {

        $log->trace(mm_sprintify("Querying %s for %s", $dom, $query));
        $log->trace(mm_sprintify("[XML] %s (queried for %s) contains:\n%s", $dom, $query, $dom->toString(1)));

        my @nodes = eval { $dom->findnodes($query); };
        return($self->error("Can't %s->findnodes(): %s", $dom, $@))
            if($@);

        foreach my $node (@nodes) {
            $log->trace(mm_sprintify("[XML] %s (the %d'st result) contains:\n%s", $node, scalar(@{ $results }), $node->toString(1)));
            push(@{$results}, $node);
        }

        $log->trace(mm_sprintify("Have found %d elements in %s", scalar(@nodes), $dom));

    }

    return($results);

}



__PACKAGE__->meta->make_immutable;

1;
