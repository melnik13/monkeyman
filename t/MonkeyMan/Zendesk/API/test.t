#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use MonkeyMan;

my $monkeyman = MonkeyMan->new(
    app_code            => undef,
    app_name            => 'test.t',
    app_description     => 'MonkeyMan::Zendesk::API very basic testing script',
    app_version         => $MonkeyMan::VERSION
);

use Test::More;

my $logger          = $monkeyman->get_logger;
my $zendesk         = $monkeyman->get_zendesk;
my $api             = $zendesk->get_api;
my $configuration   = $api->get_configuration;

SKIP: {

    skip("Doesn't matter at the moment");

    if(my $data = $api->run_command(command => 'api/v2/tickets.json', method => 'GET')) {
        foreach my $ticket (@{ $data->{'tickets'} }) {
            ok($ticket->{'id'}, $ticket->{'id'} . ': ' . $ticket->{'status'});
        }
    }

    my $data = {
        ticket => {
            comment => {
                body    => 'Вот вам тестовая среда, не заёбывайте. IP-адрес - 13.13.13.13, имя - root, пароль - zaloopa, идите на хуй.',
                public  => 'true'
            }
        }
    };
    ok($api->run_command(
        command     => 'api/v2/tickets/39.json',
        method      => 'PUT',
        parameters  => $data
    ));

}

done_testing;
