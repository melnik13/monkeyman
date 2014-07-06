#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);

use lib("$Bin/../lib");

use MonkeyMan;
use MonkeyMan::Constants;
use MonkeyMan::Show;
use MonkeyMan::CloudStack::API;
use MonkeyMan::CloudStack::Elements::Domain;

use Getopt::Long;
use Config::General qw(ParseConfig);
use Text::Glob qw(match_glob); $Text::Glob::strict_wildcard_slash = 0;
use File::Basename;



my %opts;

my $res = GetOptions(
    'h|help'        => \$opts{'help'},
      'version'     => \$opts{'version'},
    'c|config'      => \$opts{'config'},
    'v|verbose+'    => \$opts{'verbose'},
    'q|quiet'       => \$opts{'quiet'},
    's|schedule=s'  => \$opts{'schedule'}
);
unless($res) {
    die("Can't GetOptions()");
}

if($opts{'help'})       { MonkeyMan::Show::help('makesnapshots');   exit; };
if($opts{'version'})    { MonkeyMan::Show::version;                 exit; };
unless(defined($opts{'schedule'})) {
    die("The schedule hasn't been defined, see --help for more information");
}

my $mm = eval { MonkeyMan->new(
    config_file => $opts{'config'},
    verbosity   => $opts{'quiet'} ? 0 : ($opts{'verbose'} ? $opts{'verbose'} : 0) + 4
); };
die("Can't MonkeyMan->new(): $@") if($@);

my $log = eval { Log::Log4perl::get_logger("MonkeyMan") };
die("The logger hasn't been initialized: $@") if($@);

my $api = $mm->cloudstack_api;
$log->logdie($mm->error_message) unless(defined($api));



my %queue;
my %schedule;                       # the key is the variable's name
my %conf_timeperiods;               # the key is its name
my %conf_storagepools;              # the key is its name
my %conf_hosts;                     # the key is its name
my %conf_domains;                   # the key is its full path
my %conf_volumes;                   # the key is its id

# Defining the objects' tree (we need to update it on every pass)

my $objects = {
    domain          => {
        objects_by_name         => {},
        objects_by_id           => {},
        downlinks        => {
            volume          => {
                objects_by_name         => {},
                objects_by_id           => {},
                downlinks        => {
                    snapshot        => {
                        objects_by_name         => {},
                        objects_by_id           => {}
                    },
                    storagepool     => {
                        objects_by_name         => {},
                        objects_by_id           => {}
                    },
                    virtualmachine  => {
                        objects_by_name         => {},
                        objects_by_id           => {},
                        downlinks        => {
                            host            => {
                                objects_by_name         => {},
                                objects_by_id           => {}
                            }
                        }
                    }
                }
            }
        }
    }
};
my $volumes_by_id = $objects->{'domain'}->{'downlinks'}->{'volume'}->{'objects_by_id'};



THE_LOOP: while (1) {

    # --------------------------------------------------------------------
    # Load everything If the schedule hasn't been loaded or has been reset

    # I'm reloading the schedule every time I get SIGHUP
 
    unless(%schedule) {

        %schedule = eval {
            ParseConfig(
                -ConfigFile         => $opts{'schedule'},
                -UseApacheInclude   => 1
            );
        };
        if($@) {
            $log->logdie("Can't Config::General->ParseConfig(): $@");
        }

        $log->debug("The schedule has been loaded");

        # We shall forget all configuration elements as we obviously need
        # to reload them all

        undef(%conf_timeperiods);
        undef(%conf_storagepools);
        undef(%conf_hosts);
        undef(%conf_domains);
        %queue = (
            volumes => {}
        )

    }

    # Dealing with all configuration sections (reloading them if needed)

    foreach my $section (
        { hash => \%conf_timeperiods,   type => 'timeperiod' },
        { hash => \%conf_storagepools,  type => 'storagepool' },
        { hash => \%conf_hosts,         type => 'host' },
        { hash => \%conf_domains,       type => 'domain' }
    ) {
        unless(defined(%{ $section->{'hash'}})) {
            $log->trace("Some $section->{'type'}s definitely need to be defined");
            my $elements_loaded = eval {
                load_elements(
                    \%schedule,
                    $section->{'type'},
                    $section->{'hash'}
                );
            };
            if($@) { $log->die("Can't load_element(): $@"); };
            $log->trace("$elements_loaded $section->{'type'}s have been loaded");
        }
    }


    # -------------------------------------------
    # Loading information about objects if needed

    # It shall be able to reload the information without reloading the queue,
    # by the timer or by SIGUSR1!

    foreach my $domain_path (grep(!/\*/, keys(%conf_domains))) {

        # Reload the information about the domain only if it's needed

        unless(defined($objects->{'domain'}->{'objects_by_name'}->{$domain_path})) {

            $log->debug("Loading the information about the $domain_path domain");

            my $domain = eval { MonkeyMan::CloudStack::Elements::Domain->new(
                mm          => $mm,
                load_dom    => {
                    conditions  => {
                        path        => $domain_path
                    }
                }
            )};
            if($@) { $log->warn("Can't MonkeyMan::CloudStack::Elements::Domain->new(): $@"); next; }

            my $domain_id = $domain->get_parameter('id');
            if($domain->has_error) { $log->warn($domain->error_message); next; }
            unless(defined($domain_id)) { $log->warn("Can't get the id parameter of the domain"); next; }

            $objects->{'domain'}->{'objects_by_name'}->{$domain_path} = $objects->{'domain'}->{'objects_by_id'}->{$domain_id} = $domain;

            $log->info("The $domain_id ($domain_path) domain has been refreshed");

        }

        # Do we need to scan for any downlinks?

        my @downlinks_types_to_scan = keys(%{$objects->{'domain'}->{'downlinks'}});

        foreach (@downlinks_types_to_scan) {

            # Loading downlinks

            my $results = find_related_and_refresh_if_needed(
                $objects->{'domain'}->{'objects_by_name'}->{$domain_path},
                $_,
                $objects->{'domain'}->{'downlinks'}->{$_}
            );
            unless(defined($results)) {
                $log->warn("No ${_}s refreshed due to an error occuried");
                next;
            }
            $log->debug("$results ${_}(s) found");

        }

    }



    # -------------------------------
    # Adding new volumes to the queue

    foreach (keys(%{ $volumes_by_id })) {

        my $volume = $volumes_by_id->{$_};

        my $volume_domain = $volume->get_parameter('domainid');
        if($volume->has_error) {
            $log->warn($volume->error_message);
            next;
        } elsif(!defined($volume_domain)) {
            $log->warn("The volume $volume doesn't have the domainid parameter");
            next;
        } else {
            $volume_domain = $objects->{'domain'}->{'objects_by_id'}->{$volume_domain};
            unless(ref($volume_domain) eq 'MonkeyMan::CloudStack::Elements::' . ${&MMElementsModule}{'domain'}) {
                $log->warn("The $volume_domain domain looks unhealthy");
                next;
            }
        }


        my $volume_storagepool = $volume->get_parameter('storage');
        if($volume->has_error) {
            $log->warn($volume->error_message);
            next;
        } elsif(!defined($volume_storagepool)) {
            $log->warn("The volume $volume doesn't have the storagepool parameter");
            next;
        } else {
            $volume_storagepool = $objects->{'domain'}->{'downlinks'}->{'volume'}->{'downlinks'}->{'storagepool'}->{'objects_by_name'}->{$volume_storagepool};
            unless(ref($volume_storagepool) eq 'MonkeyMan::CloudStack::Elements::' . ${&MMElementsModule}{'storagepool'}) {
                $log->warn("The $volume_storagepool storagepool looks unhealthy");
                next;
            }
        }

        my $volume_virtualmachine = $volume->get_parameter('virtualmachine');
        if($volume->has_error) {
            $log->warn($volume->error_message);
            next;
        } elsif(!defined($volume_virtualmachine)) {
            $log->trace("The volume $volume doesn't have the virtualmachine parameter");
        } else {
            $volume_virtualmachine = $objects->{'domain'}->{'downlinks'}->{'volume'}->{'downlinks'}->{'virtualmachine'}->{'objects_by_id'}->{$volume_virtualmachine};
            unless(ref($volume_virtualmachine) eq 'MonkeyMan::CloudStack::Elements::' . ${&MMElementsModule}{'virtualmachine'}) {
                $log->warn("The $volume_virtualmachine virtualmachine looks unhealthy");
                next;
            }
        }

        my $virtualmachine_host;
        if(defined($volume_virtualmachine)) {
            $virtualmachine_host = $volume_virtualmachine->get_parameter('host');
            if($volume_virtualmachine->has_error) {
                $log->warn($volume_virtualmachine->error_message);
                next;
            } elsif(!defined($virtualmachine_host)) {
                $log->trace("The volume_virtualmachine $volume_virtualmachine doesn't have the host parameter");
            } else {
                $virtualmachine_host = $objects->{'domain'}->{'downlinks'}->{'volume'}->{'downlinks'}->{'virtualmachine'}->{'downlinks'}->{'host'}->{'objects_by_id'}->{$virtualmachine_host};
                unless(ref($virtualmachine_host) eq 'MonkeyMan::CloudStack::Elements::' . ${&MMElementsModule}{'host'}) {
                    $log->warn("The $virtualmachine_host host looks unhealthy");
                    next;
                }
            }
        }

        unless(defined($queue{'volumes'}->{$_})) {
            $queue{'volumes'}->{$_} = {
                object  => $volume,
                queued  => time,
                done    => undef,
                related => {
                    domain          => $volume_domain,
                    storagepool     => $volume_storagepool,
                    virtualmachine  => $volume_virtualmachine,
                    host            => $virtualmachine_host
                }
            };
            $log->debug("Added the $_ volume to the queue");
        }

    }




    # ----------------------------------------------------------
    # Asking MM whats up, updating information about queued jobs



    # -------------------------------
    # Starting new snapshot processes




    # -------------------------------------------
    # Gathering and storing some usage statistics

    # Counting stats

    # Saving the queue and objects, MonkeyMan should be able to do that:
    #   $dump_id = $mm->dump_state();
    #   $restore = $mm->restore_state($dump_id);



    sleep 10; # shall be configured and/or calculated /!\
}



exit;



sub load_elements {
    
    my($schedule, $elements_type, $elements_set) = @_;

    unless(
        ref($schedule) eq 'HASH' &&
        defined($elements_type) &&
        ref($elements_set) eq 'HASH'
    ) {
        $log->logdie("Required parameters haven't been defined");
    }

    # Loading templates

    foreach my $template_name (grep( /\*/, keys(%{ $schedule{$elements_type} }))) {
        $elements_set->{$template_name} = $schedule->{$elements_type}->{$template_name};
        $log->trace("The $template_name ${elements_type}'s template has been loaded");
    }

    # Loading elements

    my $elements_loaded = 0;

    foreach my $element_name (grep(!/\*/, keys(%{ $schedule{$elements_type} }))) {

        $log->trace("Configuring the $element_name $elements_type");

        # Getting the configuration of the new element from the schedule
        $elements_set->{$element_name} = $schedule->{$elements_type}->{$element_name};

        # Configuring the new element, adding configuration templates
 
        my %element_configured;
        my $layers_loaded = eval {
            configure_element(
                $elements_set,
                $element_name,
               \%element_configured
            );
        };
        $log->logdie("Can't configure_element(): $@") if($@);
        $elements_set->{$element_name} = \%element_configured;
        $elements_loaded++;

        $log->debug("The $element_name $elements_type with $layers_loaded configuration layers has been loaded");
        foreach my $parameter (keys(%{ $elements_set->{$element_name} })) {
            $log->debug(
                "The $element_name $elements_type has $parameter = " .
                $elements_set->{$element_name}->{$parameter}
            );
        }

    }

    return($elements_loaded);

};



sub configure_element {

    my($elements_set, $element_name, $element_configured) = @_;

    unless(
        ref($elements_set) eq 'HASH' &&
        defined($element_name) &&
        ref($element_configured) eq 'HASH'
    ) {
        $log->logdie("Required parameters haven't been defined");
    }

    # Will try to compare every pattern to the given name,
    # will return the exact number of patterns matched,
    # so, yes, 0 means nothing has matched.

    my $matched_patterns = 0;

    foreach my $pattern (sort(keys(%{ $elements_set }))) {
        if(match_glob($pattern, $element_name)) {
            $log->trace("The $pattern pattern matched the $element_name element");
            foreach (keys(%{ $elements_set->{$pattern} })) {
                $element_configured->{$_} = $elements_set->{$pattern}->{$_};
                $log->trace("The $element_name element has $_ = $element_configured->{$_}");
            }
            $matched_patterns++;
        }
    }

    return($matched_patterns);


}


sub find_related_and_refresh_if_needed {

    my $uplink              = shift;
    my $downlinks_type      = shift;
    my $downlinks_objects   = shift;

    my $uplink_id   = $uplink->get_parameter('id');
    if($uplink->has_error) {
        $log->warn($uplink->error_message);
        return;
    }
    my $uplink_name = $uplink->get_parameter('name');
    if($uplink->has_error) {
        $log->warn($uplink->error_message);
        return;
    }
    my $uplink_type = $uplink->element_type;
    if($uplink->has_error) {
        $log->warn($uplink->error_message);
        return;
    }

    $log->debug(
        "Looking for ${downlinks_type}s related to the $uplink_id" .
        (defined($uplink_name) ? " ($uplink_name) " : " ") .
        $uplink_type
    );

    # Looking for related downlinks

    my $downlinks = $uplink->find_related_to_me($downlinks_type);
    unless(defined($downlinks)) {
        $log->warn($uplink->error_message);
        return;
    }
    unless(scalar(@{ $downlinks })) {
        $log->debug("The $uplink_id $uplink_type doesn't have any related ${downlinks_type}s");
    }

    my $found = 0;

    foreach my $downlink_dom (@{ $downlinks }) {

        $found++;

        my $downlink_id = eval { $downlink_dom->findvalue("/$downlinks_type/id") };
        if($@) { $log->warn("Can't $downlink_dom->findvalue(): $@"); next; }

        # Indeed, only if we need it

        unless(defined($downlinks_objects->{'objects_by_id'}->{$downlink_id})) {

            $log->trace("Loading the information about the $downlink_id $downlinks_type");

            my $module_name = ${&MMElementsModule}{$downlinks_type};
            unless(defined($module_name)) {
                $log->warn("I'm not able to look for related ${downlinks_type}s yet");
                return;
            }

            my $downlink = eval {
                require("MonkeyMan/CloudStack/Elements/$module_name.pm");
                return("MonkeyMan::CloudStack::Elements::$module_name"->new(
                    mm          => $mm,
                    load_dom    => {
                         dom        => $downlink_dom
                    }
                ));
            };
            if($@) { $log->warn("Can't MonkeyMan::CloudStack::Elements::$module_name->new(): $@"); next; }

            $downlink_id = $downlink->get_parameter('id');
            if($downlink->has_error) {
                $log->warn($downlink->error_message);
                next;
            }
            unless(defined($downlink_id)) {
                $log->warn("Can't get the ID of the $downlinks_type");
                next;
            }

            my $downlink_name = $downlink->get_parameter('name');
            if($downlink->has_error) {
                $log->warn($downlink->error_message);
                next;
            }
            unless(defined($downlink_name)) {
                $log->warn("Can't get the name of the $downlinks_type");
                next;
            }

            # Storing information about the downlink

            $downlinks_objects->{'objects_by_id'}->{$downlink_id} = $downlinks_objects->{'objects_by_name'}->{$downlink_name} = $downlink;

            $log->info("The $downlink_id ($downlink_name) $downlinks_type has been refreshed");

        }

        # Do we need to scan for any downlinks?

        my @downlinks_types_to_scan = keys(%{$downlinks_objects->{'downlinks'}});
        unless(@downlinks_types_to_scan) {
            $log->debug("No more downlinks to scan");
            next;
        }

        foreach (@downlinks_types_to_scan) {

            # Loading downlinks

            my $results = find_related_and_refresh_if_needed(
                $downlinks_objects->{'objects_by_id'}->{$downlink_id},
                $_,
                $downlinks_objects->{'downlinks'}->{$_}
            );
            unless(defined($results)) {
                $log->warn("No ${_}s refreshed due to an error occuried");
                next;
            }
            $log->debug("$results ${_}(s) found");
        }

    }

    return($found);

}
