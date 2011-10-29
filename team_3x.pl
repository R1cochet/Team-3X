#!/usr/bin/perl

use strict;
use warnings;
use Irssi;
use Storable;
use vars qw($VERSION %IRSSI);

$VERSION = '1.01';
%IRSSI = (
    authors     => 'R1cochet',
    contact	    => '#',
    name	    => '#3x working request grabber',
    description	=> 'saves working requests to a file',
    modules     => 'use Storable',
    license	    => 'GNU General Public License v3.0',
    changed     => 'Tue Oct 25 17:02:12 PDT 2011',
);

sub message_public {                                         # parse the message
    my ($server, $msg, $nick, $nick_addr, $target) = @_;
    if ($target  =~ m/#(?:3x|testbed)/) { 
        if ( $msg =~ /sent\sto/i ) {                                # match sent to
            my $sent_to_msg = Irssi::strip_codes($msg);

            my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
            my %table = %{retrieve($filename)};                     # open the hash

            my @sent_to_msg = split(" ",$sent_to_msg);
            my $sent_to_site = &site_name($sent_to_msg[0]);
            my $sent_to_nick = $sent_to_msg[3];

            if ($table{request}->{$sent_to_nick}) {                # check you have a request made by nick
                my $request = $table{request}->{$sent_to_nick};
#                $server->print($target, "adding request to working", MSGLEVEL_NOTICES);
                $table{sent}->{$sent_to_site} = $request;
#                $server->print($target, "deleting request from requests", MSGLEVEL_NOTICES);
                delete $table{request}->{$sent_to_nick};
            }
            store \%table, $filename;
        }

        if ( $msg =~ /^!request /i ) {                        # stop if text does not start with "!request"
            my $request_made_msg = Irssi::strip_codes($msg);              # strip color codes from text

            my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
            my %table = %{retrieve($filename)};                     # open the hash

            $request_made_msg =~ s/!request //;
            my @request_made_msg = split(" ",$request_made_msg);
            my $request_made_site = &site_name($request_made_msg[0]);

            unless ($table{sent}->{$request_made_site}) {
                    $table{request}->{$nick} = $request_made_msg;
                    my $added = $table{request}->{$nick};
#                    $server->print($target, "adding request for: $request_made_site", MSGLEVEL_NOTICES);
            }
            store \%table, $filename;
        }
    }
}

sub cmd_request {  # make a request in #3x
    my ($data, $server, $witem, $target) = @_;
    my $site = shift;

    if (!$site) {
        Irssi::active_win()->print("You must enter a site name");
        return;
    }

    my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
    my %table = %{retrieve($filename)};

    if (!$server || !$server->{connected}) {
        Irssi::print("Not connected to server");
        return;
    }
    if ($witem && ($witem->{name} =~ /#3x/i)) {
        if ($table{sent}->{$site}) {
            my $requested_site = "!request " . $table{sent}->{$site};
            $witem->command("SAY $requested_site");
        }
        else {
            Irssi::active_win()->print("$site is not in database");
        }
    }
    else {
        Irssi::active_win()->print("Must be in #3x to run this command");
    }
}

sub cmd_show {      # print all working requests to active window
    my ($server, $witem) = @_;
    my $site = shift;

    my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
    my %table = %{retrieve($filename)};

    if (!$site) {
        Irssi::active_win()->print('Must enter "all" or a site name');
    }
    elsif ($site =~ /^all$/i) {
        foreach my $key (sort keys %{ $table{sent} }) {
            Irssi::active_win()->print($key);       # print to active window
        }
    }
    elsif ($table{sent}->{$site}) {
        Irssi::active_win()->print("$site: $table{sent}->{$site}");
    }
    else {
        Irssi::active_win()->print("$site is not in database");
    }
}

sub cmd_add {
    my $addition = shift;
    my @addition = split(/ /,$addition,3);
    my $site_name = $addition[0];


    if(!$addition[2]) {
        Irssi::active_win()->print("Incorrect syntax");
        Irssi::active_win()->print("Proper syntax: sitename site_url (form_type)");
    }
    else {
        my $site_url = join(" ",$addition[1],$addition[2]);
        my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
        my %table = %{retrieve($filename)};
        $table{sent}->{$site_name} = $site_url;
        Irssi::active_win()->print("$site_name has been added");
        store \%table, $filename;
    }
}

sub cmd_delete {
    my $site = shift;

    if (!$site) {
        Irssi::active_win()->print("You must enter a site name");
        return;
    }

    my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
    my %table = %{retrieve($filename)};

    if ($table{sent}->{$site}) {
        delete $table{sent}->{$site};
        Irssi::active_win()->print("$site has been removed");
        store \%table, $filename;
    }
    else {
        Irssi::active_win()->print("$site is not in database");
    }
}

sub cmd_backup {      # save all requests to a txt file
    my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
    my %table = %{retrieve($filename)};

    my $save_file = Irssi::get_irssi_dir() . "/scripts/saved_requests.txt";
    open(FH, ">$save_file");
    
    foreach my $key (sort keys %{ $table{sent} }) {
        my $line = sprintf ("%-20s !request %s\n", $key, $table{sent}->{$key});
        print FH "$line";
    }
    close(FH);
}

sub cmd_quit {
    my $filename = Irssi::get_irssi_dir() . "/scripts/team_3x_hash";
    my %table = %{retrieve($filename)};

    foreach my $key (keys %{ $table{request} }) {
        delete $table{request}->{$key};
    }   
    store \%table, $filename;
}

sub site_name($)
{
	my $string = shift;
    if ($string =~ /aziani/) {
        $string =~ s/http:\/\/members\.|members\.com.*//gi;
    }
    elsif ($string =~ /www\.ftvmembers\.com/) {
        $string = "ftvmembers";
    }
    elsif ($string =~ /sso\.kink/) {
        $string =~ s/.*www\.|\.com.*//gi;
    }
    elsif ($string =~ /southern-charms/) {
        my $base_site = my $base_name = $string;
        $base_site =~ s/.*www\.|\.com.*//g;
        $base_name =~ s/.*com\/|\/private.*//g;
        $string = "$base_site-$base_name";
    }
    elsif ($string =~ /nubilescc/) {
        $string = "nubiles";
    }
    elsif ($string =~ /http:\/\/\w+\.exclusive\.premiumpass.*/) {
        my $base_site = my $base_name = $string;
        $base_site =~ s/.*exclusive\.|\.com.*//g;
        $base_name =~ s/http:\/\/|\.exclusive.*//g;
        $string = "$base_site-$base_name";
    }
    else {
    	$string =~ s/http:\/\/video\.|https:\/\/|http:\/\/|www\.|www2\.|tour2\.|members3\.|members2\.|members\.|member\.|new\.|login\.|exclusive\.|n2\.|\.st-secure|auth\.|vb2\.|\.branddanger|\.com.*|\.net.*|\.co\.uk.*|\.tv.*|\.biz.*|\.org.*|\/xxx\/.*//gi;
    }
	return $string;
}

Irssi::signal_add('message public', 'message_public');
Irssi::command_bind('request', 'cmd_request');
Irssi::command_bind('show', 'cmd_show');
Irssi::command_bind('add', 'cmd_add');
Irssi::command_bind('delete', 'cmd_delete');
Irssi::command_bind('backup', 'cmd_backup');
Irssi::command_bind('quit', 'cmd_quit');
