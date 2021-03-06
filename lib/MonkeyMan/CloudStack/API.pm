package MonkeyMan::CloudStack::API;

=head1 NAME

MonkeyMan::CloudStack::API - Apache CloudStack API class

=head1 DESCRIPTION

The L<MonkeyMan::CloudStack::API> class encapsulates the interface to the
Apache CloudStack.

=head1 SYNOPSIS

    my $api = MonkeyMan::CloudStack::API->new(
        configuration   => ...
    );

    my $result = $api->run_command(
        parameters  => {
            command     => 'login',
            username    => 'admin',
            password    => '1z@Lo0pA3',
            domain      => 'ZALOOPA'
        },
        wait        => 0,
        fatal_empty => 1,
        fatal_fail  => 1
    );

=cut

use strict;
use warnings;

# Use Moose and be happy :)
use Moose;
use namespace::autoclean;

# Inherit some essentials
with 'MonkeyMan::Roles::WithTimer';

use MonkeyMan::CloudStack::Types qw(ElementType ReturnAs);
use MonkeyMan::Plug qw(load_package);
use MonkeyMan::Exception qw(
    CanNotLoadPackage
    InvalidParametersValue
    InvalidResponse
    CommandFailed
    MagicWordsArentDefined
    DOMIsNotDefined
    NoParameters
    NoKeyValue
    Timeout
);
use MonkeyMan::CloudStack::API::Cache;
use MonkeyMan::CloudStack::API::Command;
use MonkeyMan::CloudStack::API::Vocabulary;

use constant CLOUDSTACK_API_WAIT_FOR_FINISH     => 3600;
use constant CLOUDSTACK_API_SLEEP               => 10;
use constant CLOUDSTACK_API_DEFAULT_CACHE_TIME  => 600;

use TryCatch;
use Method::Signatures;
use Lingua::EN::Inflect qw(A PL);
use URI::Encode qw(uri_encode uri_decode);
use Digest::SHA qw(hmac_sha1);
use MIME::Base64;
use XML::LibXML;
use Module::List qw(list_modules);
use Data::Dumper;



=head1 METHODS

=head2 C<new()>

    $api = MonkeyMan::CloudStack::API->new(%parameters);

This method initializes the Apache CloudStack's API connector;

There are a few parameters that can (and need to) be defined:

=head3 Parental Object Parameters

=head4 C<cloudstack>

MANDATORY. Supposed to be a reference to the L<MonkeyMan::CloudStack> object. The
connecter can't be initialized outside of MonkeyMan, so you need to have the
parental object initialized if you need to use CloudStack's API.

The value is readable by C<get_cloudstack()>.

=cut

# See the MonkeyMan::CloudStack::Essentials role manual


=head3 Configuration-Related Parameters

=head4 C<configuration>

Optional. A C<HashRef> pointing to the configuration tree. If it's not defined,
the builder will try to fetch it from the parental L<MonkeyMan::CloudStack>'s
configuration tree.

The value is readable by C<get_configuration()>.

=cut

has 'configuration' => (
    is          => 'ro',
    isa         => 'HashRef',
    reader      =>    'get_configuration',
    writer      =>   '_set_configuration',
    predicate   =>   '_has_configuration',
    builder     => '_build_configuration',
    lazy        => 1
);

method _build_configuration {
    return( {} );
}



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



=head3 Useragent-Related Parameters

=head4 C<useragent>

Optional. By default the builder creates a new L<LWP::UserAgent> object and use it
for making calls to Apache CloudStack API. I don't recommend you to redefine it,
but you can do it.

The value is readable by C<get_useragent()>.

=cut

has useragent => (
    is          => 'ro',
    isa         => 'Object',
    reader      =>    'get_useragent',
    writer      =>   '_set_useragent',
    predicate   =>    'has_useragent',
    builder     => '_build_useragent',
    lazy        => 1
);

method _build_useragent {

    return(LWP::UserAgent->new(
        agent       => $self->get_useragent_signature,
        ssl_opts    => { verify_hostname => 0 } #FIXME 20151219
    ));

}




=head4 C<useragent_signature>

Optional. Contains a C<Str> of the signature that will be used as the User-Agent
header in all outgoing HTTP requests. By default it looks like that:

=over

APP-6.6.6 (powered by MonkeyMan-6.6.6) (libwww-perl/6.6.6)

=back

The value is readable by C<get_useragent_signature()>, writeable as
C<set_useragent_signature()>.

Please, note: if you use your own useragent instead of the default one, you
should make it always taking into consideration this parameter's value!

=cut

has useragent_signature => (
    is          => 'ro',
    isa         => 'Str',
    reader      =>    'get_useragent_signature',
    writer      =>    'set_useragent_signature',
    predicate   =>    'has_useragent_signature',
    builder     => '_build_useragent_signature',
    lazy        => 1
);

method _build_useragent_signature {

    my $useragent_signature =
        $self->get_configuration->{'useragent_signature'};

    unless(defined($useragent_signature)) {
        $useragent_signature = sprintf(
            "%s (powered by MonkeyMan::CloudStack-%s) (libwww-perl/#.###)",
                $0,
                $MonkeyMan::CloudStack::VERSION
        );
    }

    return($useragent_signature)
}

=head3 Caching Parameters

=head4 C<cache>

=cut

has cache => (
    is          => 'ro',
    isa         => 'MonkeyMan::CloudStack::API::Cache',
    reader      =>    'get_cache',
    writer      =>   '_set_cache',
    predicate   =>    'has_cache',
    builder     => '_build_cache',
    lazy        => 1
);

method _build_cache {
    return(MonkeyMan::CloudStack::API::Cache->new(
        cache_time  => defined($self->get_configuration->{'cache'}->{'default_cache_time'}) ?
                               $self->get_configuration->{'cache'}->{'default_cache_time'} :
                               CLOUDSTACK_API_DEFAULT_CACHE_TIME,
        logger      => $self->_get_logger
    ));
}



=head2 C<test()>

    $api->test;

This method doesn't do anything but testing connection to the API. It raises
an exception if something's wrong with it.

=cut

method test {

    $self->run_command(
        parameters  => {
            command     => 'listApis'
        },
        wait        => 0,
        fatal_empty => 1,
        fatal_fail  => 1,
        fatal_431   => 1,
        best_before => 0
    );

}



=head2 C<run_command()>

This method is needed to run an API command.

    # Defining some options
    my %options = (
        wait        => 0,
        fatal_empty => 1,
        fatal_fail  => 1,
        fatal_431   => 0
    );

    # Running a command with a list of parameters
    my $parameters => {
        command => 'listApis',
        listAll => 'true'
    };
    $api->run_command(
        parameters => $parameters,
        %options
    );

    # Running a pre-defined command object
    my $command = MonkeyMan::CloudStack::API::Command->new(
        parameters => $parameters
    );
    $api->run_command(
        command => $command,
        %options
    );

    # Touching a pre-defined URL
    $url = $command->get_url;
    $api->run_command(
        url => $url
        %options
    );

Reurns a reference to the L<XML::LibXML::Document> DOM containing the responce.

This method recognizes the following parameters:

=head3 What To Run?

It's mandatory to set one of below-mentioned parameters. If there are no
C<parameters>, C<command> or C<url> defined, the exception will be raised.

=head4 C<parameters>

The command can be run with a hash of parameters including the command's name.
The key and the signature will be applied automatically.

=head4 C<command>

The command can be set as a pre-created L<MonkeyMan::CloudStack::API::Command>
object. Although, it's being created automatically when C<parameters> are set.

=head4 C<url>

The command can be run by touching an URL containing the command, its
parameters, the key and the signature.

=head3 How To Run?

Also it accepts the following optional parameters.

=head4 C<wait>

Contains and C<Int>. If it turns out to be an asynchronous job, how much time
should we wait for the result.

If it's greater than 0, we'll wait N seconds for the asynchronous job
to complete, where N is the parameter's value.

    $api->run(
        parameters => { command => 'performSomeCoolThing', id => '...' },
        wait => 300
    );
    # Will wait for 300 seconds and either return the result or raise an
    # exception if timeout occures.

If it less than 0, we'll wait N seconds, where N will be got either
from the C<$self->get_configuration->{'wait'}> configuration optopm or from the
C<CLOUDSTACK_API_WAIT_FOR_FINISH> constant.

    $api->run(
        parameters => { command => 'performSomeCoolThing', id => '...' },
        wait => -1
    );
    # Will wait as long as possible.

If it eqials 0, we won't wait for the result, but we won't raise an
exception, we'll just pass the result to the caller as is.

    $api->run(
        parameters => { command => 'performSomeCoolThing', id => '...' },
        wait => 0
    );
    # Won't wait for anything, just returns the job information.

=head4 C<fatal_empty>

Contains C<Bool>. Raises an exception if the result is empty. Deafault value is
0.

=head4 C<fatal_fail>

Contains C<Bool>. Raises an exception if the failure is occured. Deafault value
is 1.

=head4 C<fatal_431>

...

=cut

method run_command(
    MonkeyMan::CloudStack::API::Command :$command,
    HashRef     :$parameters,
    Str         :$url,
    Maybe[Int]  :$wait          = 0,
    Maybe[Bool] :$fatal_empty   = 0,
    Maybe[Bool] :$fatal_fail    = 1,
    Maybe[Bool] :$fatal_431     =
        ! $self->get_configuration->{'ignore_431_code'},
    Maybe[Str]  :$best_before
) {

    my $configuration   = $self->get_configuration;
    my $logger          = $self->_get_logger;

    my $command_to_run;

    if(defined($command)) {
        $logger->tracef("The %s API-command is given to be run", $command);
        $command_to_run = $command;
    }

    if(defined($url)) {
        $logger->tracef("The %s URL is given to be run as a command", $url);
        unless(defined($command_to_run)) {
            $command_to_run = MonkeyMan::CloudStack::API::Command->new(
                api     => $self,
                url     => $url
            );
        } else {
            $logger->warnf(
                "The %s API-command is already present, " .
                "the %s URL will be ignored",
                    $command_to_run, \$url
            );
        }
    }

    if(defined($parameters)) {
        $logger->tracef("The %s set of parameters is given to be run as a command",
            $parameters
        );
        unless(defined($command_to_run)) {
            $command_to_run = MonkeyMan::CloudStack::API::Command->new(
                api         => $self,
                parameters  => $parameters
            );
        } else {
            $logger->warnf(
                "The %s API-command is already present, " .
                "the %s set of parameters will be ignored",
                    $command_to_run, $parameters
            );
        }
    }

    unless(defined($command_to_run)) {
        (__PACKAGE__ . '::Exception::NoParameters')->throw(
            "Neither parameters, command nor URL are given"
        );
    }

    my $job_run = $self->get_time_current_rough;

    my $result;
    my $failure;
    try {
        $result  = $command_to_run->run(
            fatal_fail  => 1,
            fatal_431   => $fatal_431,
            best_before => $best_before
        );
    } catch (MonkeyMan::Exception $failure_api) {
        $failure = $failure_api->{'message'};
        $result  = $command_to_run->get_http_response->content
                if($command_to_run->has_http_response);
    } catch ($failure_api) {
        $failure = $failure_api;
    }
    if(defined($failure)) {
        $logger->tracef(
            "The %s command has failed to run: %s (contents %s)",
            $command_to_run, $failure, \$result
        );
    }

    my $dom;
    try {
        $dom = XML::LibXML->new->load_xml(string => $result);
    } catch ($failure_xml) {
        $failure = $failure_xml
            unless(defined($failure));
    }
    if(defined($dom)) {
        $logger->tracef(
            "The %s reply has been recognized as a DOM: %s",
                \$result, $dom
        );
    }

    if($failure && $fatal_fail) {
        if(defined($dom) && blessed($dom) && $dom->DOES('XML::LibXML::Document')) {
            my $errorcode = $dom->findvalue('/*/errorcode');
            my $errortext = $dom->findvalue('/*/errortext');
            (__PACKAGE__ . '::Exception::CommandFailed')->throwf(
                "In reply to the %s command CloudStack returned: %s %s (%s)",
                $command_to_run, $errorcode, $errortext, $failure
            );
        } else {
            (__PACKAGE__ . '::Exception::CommandFailed')->throwf(
                "In reply to the %s command CloudStack returned: %s",
                $command_to_run, $failure
            );
        }
    }

    if(my $jobid = $dom->findvalue('/*/jobid')) {

        $logger->tracef("We've got an asynchronous job, the job ID is: %s", $jobid);

        if($wait) {

            $wait =
                ($wait > 0) ?
                    $wait :
                    defined($configuration->{'wait'}) ?
                            $configuration->{'wait'} :
                            CLOUDSTACK_API_WAIT_FOR_FINISH;

            $logger->tracef(
                "We'll wait %d seconds for the result of the %s job",
                    $wait,
                    $jobid
            );

            while() {

                my $job_result = $self->get_job_result($jobid);

                my $job_status = $job_result->findvalue('/queryasyncjobresultresponse/jobstatus');
                if($job_status eq '0') {
                    $logger->tracef("The %s job is running", $jobid);
                } elsif($job_status eq '1') {
                    $logger->tracef("The %s job is finished", $jobid);
                    $dom = $job_result;
                    last;
                } elsif($job_status eq '2') {
                    $logger->tracef("The %s job is failed", $jobid);
                    my $jobresultcode = $job_result->findvalue('/queryasyncjobresultresponse/jobresultcode');
                    my $errorcode     = $job_result->findvalue('/queryasyncjobresultresponse/jobresult/errorcode');
                    my $errortext     = $job_result->findvalue('/queryasyncjobresultresponse/jobresult/errortext');
                    (__PACKAGE__ . '::Exception::CommandFailed')->throwf(
                        "The %s asynchronous command failed: %s %s (%s)",
                        $command_to_run, $errorcode, $errortext, $jobresultcode
                    );
                } else {
                    $logger->warnf(
                        "The %s job result %s doesn't seem to be valid: can't get /queryasyncjobresultresponse/jobstatus",
                        $command_to_run, $job_result
                    );
                }

                if(
                    ($wait > 0) &&
                    ($wait + $job_run <= $self->get_time_current_rough)
                ) {
                    (__PACKAGE__ . '::Exception::Timeout')->throwf(
                        "We can't wait for the %s job to finish anymore: " .
                        "%d seconds have passed, which is more than %d",
                            $jobid,
                            $self->get_time_current_rough - $job_run,
                            $wait
                    );
                }

                my $time_to_sleep = defined($configuration->{'sleep'}) ?
                            $configuration->{'sleep'} :
                            CLOUDSTACK_API_SLEEP;
                $logger->tracef(
                    "Sleeping for %d seconds while waiting for the %s job",
                    $time_to_sleep,
                    $jobid
                );
                sleep($time_to_sleep);

            }

        } else {

            $logger->tracef("This time we won't wait for the result of the %s job", $jobid);

        }
    }

    return($dom);

}



method get_job_result(Str $jobid!) {

    $self->run_command(
        parameters  => {
            command     => 'queryAsyncJobResult',
            jobid       => $jobid
        },
        fatal_fail  => 1,
        fatal_empty => 1,
        best_before => 0
    );

}





method compose_request(
    MonkeyMan::CloudStack::Types::ElementType   :$type!,
    Str                                         :$action!,
    Maybe[HashRef]                              :$parameters,
    Maybe[HashRef]                              :$macros,
    Maybe[Bool]                                 :$return_as_hashref
) {

    return($self->get_vocabulary($type)->compose_request(
        action              => $action,
        parameters          => $parameters,
        macros              => $macros,
        return_as_hashref   => $return_as_hashref
    ));

}

method apply_filters(
    XML::LibXML::Document                               :$dom!,
    Maybe[MonkeyMan::CloudStack::Types::ElementType]    :$type,
    Maybe[Str]                                          :$action,
    Maybe[HashRef]                                      :$parameters,
    Maybe[ArrayRef[Str]]                                :$filters,
    Maybe[MonkeyMan::CloudStack::API::Request]          :$request,
    Maybe[HashRef]                                      :$macros
) {

    return($self->get_vocabulary(
        defined($type) ? $type : ($self->recognize_response(dom => $dom))[0]
    )->apply_filters(
        dom         => $dom,
        action      => $action,
        parameters  => $parameters,
        filters     => $filters,
        request     => $request,
        macros      => $macros
    ));

}

method interpret_response(
    XML::LibXML::Document :$dom!,
    Maybe[MonkeyMan::CloudStack::Types::ElementType]    :$type,
    Maybe[Str]                                          :$action,
    Maybe[HashRef]                                      :$macros,
    HashRef|ArrayRef[HashRef]                           :$requested!
) {

    return($self->get_vocabulary(
        defined($type) ? $type : ($self->recognize_response(dom => $dom))[0]
    )->interpret_response(
        dom         => $dom,
        action      => $action,
        macros      => $macros,
        requested   => $requested
    ));

}

method mimic_empty_response(
    MonkeyMan::CloudStack::Types::ElementType   :$type!,
    Str                                         :$action!,
) {
    return($self->get_vocabulary($type)->mimic_empty_response($action));
}

method perform_action(
    MonkeyMan::CloudStack::Types::ElementType   :$type!,
    Str                                         :$action!,
    Maybe[Int]                                  :$wait,
    Maybe[HashRef]                              :$parameters,
    Maybe[HashRef]                              :$macros,
    HashRef|ArrayRef[HashRef]                   :$requested,
    Maybe[Str]                                  :$best_before
) {

    my $logger = $self->_get_logger;

    $logger->tracef(
        "Performing the %s action, elements' type is %s, " .
        "parameters are contained in %s, macroses are in %s",
        $action, $type, $parameters, $macros
    );

    my $request = $self->compose_request(
        type        => $type,
        action      => $action,
        parameters  => $parameters,
        macros      => $macros
    );

    my $dom = $self->run_command(
        command     => $request->get_command,
        wait        => defined($wait) ? $wait : $request->get_async ? -1 : 0,
        best_before => $best_before
    );

    $dom = $self->apply_filters(
        dom         => $dom,
        type        => $type,
        request     => $request
    );
    # If we've got an empty DOM after applying filters, let's mimic an empty
    # DOM that would look like a proper response
    $dom = $self->mimic_empty_response(
        type    => $type,
        action  => $action
    )
        unless(defined($dom));

    # The wantarray() function will detect what exactly the caller expects
    return($self->interpret_response(
        dom         => $dom,
        type        => $type,
        action      => $action,
        requested   => $requested
    ))

}



=head2 C<get_related>

    Interprets this structure in the element type's vocabulary:

    related => {
        our_virtual_machines => {
            type    => 'VirtualMachine',
            keys    => {
                own     => { queries    => [ '/<%OUR_ENTITY_NODE%>/id' ] },
                foreign => { parameters => { filter_by_domain_id => '<%OWN_KEY_VALUE%>' } },
            }
        },
    }

=cut

method get_related(
    MonkeyMan::CloudStack::API::Roles::Element  :$element!,
    Str                                         :$related!,
    Maybe[Str]                                  :$best_before,
    Maybe[Bool]                                 :$fatal     = 0,
    MonkeyMan::CloudStack::Types::ReturnAs      :$return_as = 'element',
) {

    my $logger = $self->_get_logger;

    my $vocabulary = $element->get_vocabulary;
    # related => {
    #     our_virtual_machines => {
    my $vocabulary_subtree_profile = $vocabulary->vocabulary_lookup(
        words   => [ 'related', $related ],
        fatal   => 1
    );
    # related => {
    #     our_virtual_machines => {
    #         keys    => {
    my $vocabulary_subtree_keys = $vocabulary->vocabulary_lookup(
        words   => [ 'keys' ],
        tree    => $vocabulary_subtree_profile,
        fatal   => 1
    );
    # related => {
    #     our_virtual_machines => {
    #         type    => 'VirtualMachine',
    my $type = $vocabulary->vocabulary_lookup(
        words   => [ 'type' ],
        tree    => $vocabulary_subtree_profile,
        fatal   => 1
    );

    $logger->tracef(
        "Going to find the %s related as %s to the %s %s",
        $self->translate_type(type => $type, plural => 1),
        $related,
        $element,
        $element->get_type(noun => 1)
    );

    my @criterions;
    my @xpaths;

    # related => {
    #     our_virtual_machines => {
    #         keys    => {
    #             own     => {
    #                 queries    => [ '/<%OUR_ENTITY_NODE%>/id' ]
    my $vocabulaty_subtree_key_own = $vocabulary->vocabulary_lookup(
        words           => [ 'own' ],
        tree            => $vocabulary_subtree_keys,
        fatal           => 1
    );
    my $own_key_queries = $vocabulary->vocabulary_lookup(
        words           => [ 'queries' ],
        tree            => $vocabulaty_subtree_key_own,
        fatal           => 1,
        resolve         => 1,
        resolve_deeper  => 1
    );
    my @own_key_values = $self->qxp(
        query           => $own_key_queries,
        dom             => $element->get_dom,
        return_as       => 'value'
    );
    if(@own_key_values > 1) {
        $logger->warnf("Too many values for the OWN_KEY_VALUE macros: %s", join(', ', @own_key_values));
    } elsif(@own_key_values < 1) {
        my $message = 'No value for the OWN_KEY_VALUE macros';
        if($fatal) {
            (__PACKAGE__ . '::Exeption::NoKeyValue')->throw($message);
        } else {
            $logger->trace($message);
            return;
        }
    }
    my $macros = { OWN_KEY_VALUE => shift(@own_key_values) };

    # related => {
    #     our_virtual_machines => {
    #         keys    => {
    #             foreign => {
    my $vocabulary_subtree_key_foreign = $vocabulary->vocabulary_lookup(
        words       => [ 'foreign' ],
        tree        => $vocabulary_subtree_keys,
        fatal       => 1
    );

    my @results = $self->perform_action(
        type        => $type,
        action      => 'list',
        macros      => $macros,
        # related => {
        #     our_virtual_machines => {
        #         keys    => {
        #             foreign => {
        #                 parameters => { filter_by_domain_id => '<%OWN_KEY_VALUE%>' }
        parameters  => $vocabulary->vocabulary_lookup(
            words           => [ 'parameters' ],
            tree            => $vocabulary_subtree_key_foreign,
            fatal           => 1,
            resolve         => 1,
            resolve_deeper  => 1,
            macros          => $macros
        ),
        requested   => { element => $return_as }
    );

    if(@results) {
        foreach my $result (@results) {
            $logger->tracef(
                'Returning the %s element in the %s list of results',
                ref($result) ? $result : \$result, \@results
            );
        }
    } else {
        $logger->tracef(
            'Returning an empty list as the %s list of results',
            \@results
        );
    }
    return(@results);

}



=head2 C<find_doms()>

The method returns the list of DOMs of elements of type defined matching
XPath-condtions defined. You probably will never need to use this method, because
it only performs dirty work for C<get_elements()>.

Anyhow, it consumes the following parameters:

=head4 C<type>

MANDATORY. The type of elements that needs to be found, types are described in
the L<MonkeyMan::CloudStack::API::Element::TYPE> manual.

=head4 C<criterions>

Optional. 

=head4 C<xpaths>

=cut

method find_doms(
    MonkeyMan::CloudStack::Types::ElementType   :$type!,
    Maybe[HashRef]                              :$criterions,
    Maybe[ArrayRef[Str]]                        :$xpaths
) {

    my $logger = $self->_get_logger;

    # $criterions = { all => 1 }
    #     unless(defined($criterions));
    # ^^^ TODO: Make sure it's okay that it's been removed

    $logger->tracef("Looking for %s matching the %s set of criterias",
        $self->translate_type(type => $type, noun => 1, plural => 1),
        $criterions
    );

    my $vocabulary = $self->get_vocabulary($type);

    my $dom = $self->run_command(
        command => $vocabulary->compose_request(
            action      => 'list',
            parameters  => $criterions
        )->get_command
    );

    my @results = $vocabulary->interpret_response(
        dom         => $dom,
        requested   => [ { element => 'dom' } ]
    );

    if(defined($xpaths)) {
        foreach my $xpath (@{ $xpaths }) {
            my @results_filtered;
            foreach my $result (@results) {
                foreach my $result_filtered ($self->qxp(
                    query       => $xpath,
                    dom         => $result,
                    return_as   => 'dom'
                )) {
                    push(@results_filtered, $result_filtered);
                }
            }
            # Yes, it should happen BEFORE we proceed to the next XPath-query!
            @results = @results_filtered;
        }
    }

    foreach my $dom (@results) {
        $logger->tracef("Found the %s DOM", $dom);
    }

    return(@results);

}



method load_element_package(MonkeyMan::CloudStack::Types::ElementType $type!) {

    my $package_name = __PACKAGE__ . '::Element::' . $type;

    try {
        return(MonkeyMan::Plug::load_package($package_name));
    } catch($e) {
        (__PACKAGE__ . '::Exception::CanNotLoadPackage')->throwf(
            "Can't load the %s package for operating %s. %s",
            $package_name,
            $self->translate_type(type => $type, plural => 1),
            $e
        );
    }

}



method recognize_dom(
    XML::LibXML::Document   :$dom!,
    Maybe[Bool]             :$fatal = 1
) {

    my $logger = $self->_get_logger;

    my $dom_recognized;

    my @vocabularies = map { $self->get_vocabulary($_) } (
        keys(%{ $self->get_vocabulary_plug->get_actors })
    );

    foreach my $response_node (map { $_->nodeName } ($dom->findnodes('/*'))) {
        foreach my $vocabulary (@vocabularies) {
            my $entity_node = $vocabulary->vocabulary_lookup(
                fatal   => 1,
                words   => [ 'entity_node' ]
            );
            if($response_node eq $entity_node) {
                if(
                    defined($dom_recognized) &&
                    ($dom_recognized ne $vocabulary->get_type)
                 ) {
                    $logger->warnf(
                        "The %s DOM is recognized as %s, " .
                        "although it also could be recognized as %s",
                        $dom,
                        $self->translate_type(
                            type    => $vocabulary->get_type,
                            a       => 1
                        ),
                        $self->translate_type(
                            type    => $dom_recognized,
                            a       => 1
                        )
                    );
                }
                $dom_recognized = $vocabulary->get_type;
            }
        }
    }

    if($fatal && !defined($dom_recognized)) {
        (__PACKAGE__ . '::Exception::InvalidResponse')->throwf(
            "The %s DOM doesn't seem to be containing any elements",
            $dom
        );
    }

    $logger->tracef(
        "The %s DOM has been recognized as %s",
        $dom, $self->translate_type(type => $dom_recognized, a => 1)
    );

    return($dom_recognized);

}

method recognize_response (
    XML::LibXML::Document :$dom!,
    Maybe[Str]            :$vocabulary,
    Maybe[Bool]           :$fatal = 1
) {

    my $logger = $self->_get_logger;

    my @response_recognized;

    my @vocabularies = ($self->get_vocabulary($vocabulary))
        if(defined($vocabulary));

    unless(@vocabularies) {
        foreach my $vocabulary (keys(%{ $self->get_vocabulary_plug->get_actors })) {
            push(@vocabularies, $self->get_vocabulary($vocabulary));
        }
    }

    foreach my $response_node (map { $_->nodeName } ($dom->findnodes('/*'))) {
        next unless($response_node =~ /response$/);
        foreach my $vocabulary (@vocabularies) {
            foreach my $action (keys(%{ $vocabulary->vocabulary_lookup(
                fatal   => 1,
                words   => [ 'actions' ]
            ) })) {
                if($response_node eq $vocabulary->vocabulary_lookup(
                    fatal   => 1,
                    words   => [
                        'actions', $action, 'response', 'response_node'
                    ]
                )) {
                    if(
                        scalar(@response_recognized) && (
                            ($response_recognized[0] ne $vocabulary->get_type) ||
                            ($response_recognized[1] ne $action)
                        )
                    ) {
                        $logger->warnf(
                            "The %s DOM is recognized as a response to " .
                            "the %s:%s action, although it also could be " .
                            "recognized as a response to the %s:%s action",
                            $dom,
                            $self->translate_type(
                                 type => $vocabulary->get_type
                            ),
                            $action,
                            $self->translate_type(
                                type => $response_recognized[0]
                            ),
                            $response_recognized[1]
                        );
                    }
                    @response_recognized = ($vocabulary->get_type, $action);
                }
            }
        }
    }

    if($fatal && !scalar(@response_recognized)) {
        (__PACKAGE__ . '::Exception::InvalidResponse')->throwf(
            "The %s DOM doesn't seem to be containing a response",
            $dom
        );
    }

    $logger->tracef(
        "The %s DOM has been recognized as the %s:%s action's response",
        $dom,
        $self->translate_type(type => $response_recognized[0]),
        $response_recognized[1]
    );

    return(@response_recognized);

}



=head2 C<get_elements()>

This method finds infrastructure elements by the criterions defined.

    foreach my $vm ($api->get_elements(
        type        => 'VirtualMachine',
        criterions  => { host => 'hX.cX.pX.zX' },
        xpaths      => [ '/virtualmachine[host = "hX.cX.pX.zX"]' ]
    )) {
        ok($vm->get_id, $vm->get_dom->findvalue('/virtualmachine/id');
    }

    $vm_copy = $api->get_elements(
        doms        => $vm->get_dom
    );

=cut

method get_elements(
    Maybe[MonkeyMan::CloudStack::Types::ElementType]    :$type,
    Maybe[MonkeyMan::CloudStack::Types::ReturnAs]       :$return_as = 'element',
    Maybe[HashRef]                                      :$criterions,
    Maybe[ArrayRef[Str]]                                :$xpaths,
    Maybe[ArrayRef[XML::LibXML::Document]]              :$doms,
) {

    my $logger = $self->_get_logger;

    unless(defined($type)) {
        unless(defined($doms) && scalar(@{ $doms })) {
            (__PACKAGE__ . '::Exception::NotEnoughParametersDefined')->throw(
                "The element type isn't defined and no DOMs are given"
            );
        }
        foreach my $dom (@{ $doms }) {
            my $type_detected = $self->recognize_dom(dom => $dom, fatal => 1);
            if(defined($type) && ($type ne $type_detected)) {
                $logger->warnf(
                    "The %s set of DOMs contains a mix of elements " .
                    "(either %s and %s)", $doms, PL($type_detected), PL($type)
                );
            }
            $type = $type_detected;
        }
    }

    unless(defined($doms)) {
        foreach my $result ($self->find_doms(
            type        => $type,
            criterions  => $criterions,
            xpaths      => $xpaths
        )) {
            push(@{ $doms }, $result);
        }
    }

    my @results;
    my $class_name = $self->load_element_package($type);
    foreach my $dom (@{ $doms }) {
        no strict 'refs';
        my $element = $class_name->new(
            api => $self,
            dom => $dom
        );
        push(@results, $self->_return_element_as($element, $return_as));
    }

#    if(defined($xpaths)) {
#        my @results_updated;
#        @results = @results_updated;
#    }

    if(defined(wantarray) && ! wantarray) {
        if(@results > 1) {
            $logger->warnf(
                "The get_elements() method is supposed to return " .
                "not a list, but a scalar value to the context it has been " .
                "called from, altough %d elements have been found (%s). " .
                "Returning the first one (%s) only.",
                scalar(@results), \@results, $results[0]
            );
        }
        return($results[0]);
    } else {
        return(@results);
    }

}



=head2 C<qxp()>

This method queries the DOM (as L<XML::LibXML::Document>) provided 
with the XPath-query provided.

    $dom = $api->run_command(
        command     => 'listVirtualMachines',
        listAll     => 'true'
    );

It can give you values:

    foreach my $id ($api->qxp(
        dom         => $dom,
        query       => '/listvirtualmachinesresponse' .
                            '/virtualmachine' .
                            '[nic/ipaddress = "13.13.13.13"]' .
                            '/id',
        return_as   => 'value'
    ) {
        $log->tracef("Found %s", $id);
    }

It can give you elements:

    foreach my $vm ($api->qxp(
        dom         => $dom,
        query       => '/listvirtualmachinesresponse' .
                            '/virtualmachine' .
                            '[nic/ipaddress = "13.13.13.13"]'
        return_as   => 'element[VirtualMachine]'
    ) {
        $log->tracef("Found %s", $vm->get_id);
    }

See below the full list of possible values for the C<return_as> parameter.

=head4 C<dom>

=head4 C<query>

=head4 C<return_as>

This parameter defines what kind of results are expected.

=item C<value>

Returns results as regular scalars.

=item C<dom>

Returns results as new L<XML::LibXML::Document> DOMs.

=item C<element[TYPE]>

Returns results as C<MonkeyMan::CloudStack::API::Element::TYPE> objects.

=item C<id[TYPE]>

Returns results as IDs fetched from freshly-created
C<MonkeyMan::CloudStack::API::Element::TYPE> objects.

=back

=cut

method qxp(
    Str|ArrayRef[Str]                               :$query!,
    XML::LibXML::Document :$dom!, # DON'T ADD SPACES HERE!
    Maybe[MonkeyMan::CloudStack::Types::ReturnAs]   :$return_as
) {

    my $logger = $self->_get_logger;

    unless($dom->DOES('XML::LibXML::Document')) {
        $logger->warnf("%s isn't a XML::LibXML::Document object");
        return;
    }
    my @queries_to_proceed = ref($query) eq 'ARRAY' ?
        (@{ $query }) :
        (   $query  );
    $query = shift(@queries_to_proceed);

    $logger->tracef(
        'Querying the %s DOM with the "%s" XPath-query (expecting %s)',
        $dom, $query, A($return_as)
    );

    my @results;

    # TODO: It would be good if it was returning a single XML-DOM of results
    # *OR* a list of separate DOMs as an option

    foreach my $new_node (
        map { $_->cloneNode(1) } ( $dom->findnodes($query)->get_nodelist )
    ) {
        my $new_dom = XML::LibXML::Document->new();
           $new_dom->addChild($new_node);

        if(@queries_to_proceed) {
            foreach my $result ($self->qxp(
                query       => \@queries_to_proceed,
                dom         => $new_dom,
                return_as   => $return_as
            )) {
                push(@results, $result);
            }
        } else {
            my $result = $self->return_as($new_dom, $return_as);
            push(@results, $result);
        }
    }

    if(@results) {
        foreach my $result (@results) {
            $logger->tracef(
                'Returning the %s element in the %s list of results',
                ref($result) ? $result : \$result, \@results
            );
        }
    } else {
        $logger->tracef(
            'Returning an empty list as the %s list of results',
            \@results
        );
    }

    return(@results);

}

# TODO: It would be good if it was returning a single DOM of results *OR*
# a list of separate DOMs
method return_as(
    Defined                                 $source!,
    MonkeyMan::CloudStack::Types::ReturnAs  $return_as!
) {

    $self->_get_logger->tracef(
        "Returning %s as %s", $source, A($return_as)
    );

    if(ref($source) eq 'MonkeyMan::CloudStack::API::Element') {
        return($self->_return_element_as($source, $return_as));
    } elsif(ref($source) eq 'XML::LibXML::Document') {
        return($self->_return_dom_as($source, $return_as));
    } else {
        (__PACKAGE__ . '::Exception::InvalidSource')->throwf(
            "Can't return %s as %s", $source, A($return_as)
        );
    }
}

method _return_dom_as(
    XML::LibXML::Document                   $dom!,
    MonkeyMan::CloudStack::Types::ReturnAs  $return_as!
) {
    if     ($return_as eq 'element') {
        return($self->get_elements(doms => [ $dom ]));
    } elsif($return_as eq 'dom') {
        return($dom);
    } elsif($return_as eq 'id') {
        return($dom->findvalue('/*/id'));
    } elsif($return_as eq 'value') {
        return($dom->textContent);
    } else {
        (__PACKAGE__ . '::Exception::InvalidParametersValue')->throwf(
            "The %s DOM can't be return as %s.",
            $dom, A($return_as)
        );
    }
}

method _return_element_as(
    MonkeyMan::CloudStack::API::Roles::Element  $element!,
    MonkeyMan::CloudStack::Types::ReturnAs      $return_as!
) {
    if     ($return_as eq 'element') {
        return($element);
    } elsif($return_as eq 'dom') {
        return($element->get_dom);
    } elsif($return_as eq 'id') {
        return($element->get_id);
    } else {
        (__PACKAGE__ . '::Exception::InvalidParametersValue')->throwf(
            "The %s element can't be return as %s.",
            $element, A($return_as)
        );
    }
}



method translate_type(
    MonkeyMan::CloudStack::Types::ElementType   :$type!,
    Bool                                        :$a      = 0,
    Bool                                        :$noun   = 1,
    Bool                                        :$plural = 0
) {
    if($noun) {
        $type =~ s/(?:\b|(?<=([a-z])))([A-Z][a-z]+)/(defined($1) ? ' ' : '') . lc($2)/eg;
        $type = PL($type)
            if($plural);
        $type = A($type)
            if($a && !$plural);
    }
    return($type);
}



method BUILD(...) {

    # We need to initialize the plug of vocabularies, the vocabularies will be
    # initialized automatically, there's no "default" vocabulary, so one shall
    # always refer the concrete vocabulary
    MonkeyMan::Plug->plug(
        plugin_name         => 'vocabulary',
        actor_class         => 'MonkeyMan::CloudStack::API::Vocabulary',
        actor_parent        => $self,
        actor_parent_as     => 'api',
        actor_name_as       => 'type',
        actor_default       => undef,
        actor_handle        => 'vocabulary',
        actor_parameters    => { logger => $self->_get_logger },
        plug_handle         => 'vocabulary_plug'
    );

    foreach my $vocabulary (keys(%{
        list_modules(
            __PACKAGE__ . '::Element::', {
                list_modules => 1,
            }
        )
    })) {
        $vocabulary =~ s/^.+::(?!::)(.+)$/$1/g;
        $self->get_vocabulary($vocabulary);
    }

}



#__PACKAGE__->meta->make_immutable;

1;
