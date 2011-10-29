#!/usr/bin/perl

use strict;
use warnings;
use Storable;

open(FH, ">team_3x_hash") || die "Can't open team_3x_hash: $!\n";
close(FH);

my %table = (
             'request'  => {
                        'nobody' => 'nothing',
                       },
             'sent' => {
                        'nosite' => 'nothing)',
                        },
            );
foreach my $key (keys %{ $table{request} }) {
    delete $table{request}->{$key};
}
foreach my $key (keys %{ $table{sent} }) {
    delete $table{sent}->{$key};
}
store \%table, "team_3x_hash";
