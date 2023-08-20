#!/usr/bin/perl

#
# Copyright (C) 2010 Robin Cornelius <robin.cornelius@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# User configuration section

my $nickname = 'CE-Relay-Tuchuk';
my $ircname = 'CE Relay - Tuchuk';

#@servers = (['irc.servercentral.net']);
my @servers = (['xxxchatters.com']);

my %channels = (
    '#The_Southern_Plains' => ,
    );

my $http_server_port=1110;

# end of user configuration section

use strict;
use warnings;

#use POE
use POE;
use POE::Component::Child;

# Pull in various IRC components
use POE::Component::IRC;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::NickReclaim;
use POE::Component::IRC::Plugin::AutoJoin;
use POE::Component::IRC::Plugin::Connector;
use POE::Component::IRC::Plugin::BotCommand;
use POE::Component::IRC::Plugin::CycleEmpty;

# POE::Component::Client::HTTP uses HTTP::Request and response objects.
use HTTP::Request::Common qw(GET POST);

# Include POE and the HTTP client component.
use POE::Component::Client::HTTP;

# Include POE HTTP Server component
use POE qw(Component::Server::TCP Filter::HTTPD);
use HTTP::Response;

# We want to encode and decode escaped URIs
use URI::Escape;

# This the the URI of the CAP for the prim's http server
my $LLURI;

# *************** IRC ****************************

my $irc = POE::Component::IRC::State->spawn(
    nick => $nickname,
    ircname => $ircname,
    Server => $servers[0]->[0],
) or die "Could not use name $!";

sub _start {

    my ($kernel, $heap) = @_[KERNEL, HEAP];    

     $irc->yield( register => 'all' );

     # Create and load our NickReclaim plugin, before we connect 
     $irc->plugin_add( 'NickReclaim' => POE::Component::IRC::Plugin::NickReclaim->new( poll => 60 ) );
 
     my $chans=\%channels;
     my $svrs=\@servers;
     
     $irc->plugin_add('AutoJoin', POE::Component::IRC::Plugin::AutoJoin->new( Channels => $chans));
     $irc->plugin_add('Connector',POE::Component::IRC::Plugin::Connector->new( servers => $svrs));
     $irc->plugin_add('CycleEmpty', POE::Component::IRC::Plugin::CycleEmpty->new());

     $irc->yield( connect => { } );
     return;
 }

# channel message
sub irc_public {

    my ($kernel,$sender)=@_[KERNEL,SENDER];

    my $hostmask=$_[ARG0];
    my $target=@$_[ARG1];
    my $msg=$_[ARG2];
    
    $hostmask =~ s/^(.*)!(.*)@(.*)$//;;
    my $nick = $1;
    my $hostuser = $2;
    my $hostname = $3;
   
    my $url=$LLURI."/?".uri_escape("<$nick> ".$msg);

    # Send the recieved message from IRC component to the http client component
    $kernel->post("ua" => "request", "got_response", GET $url);
    
}

# **************** HTTP CLIENT **********************

  POE::Component::Client::HTTP->spawn(
  Alias   => 'ua',
  MaxSize => 4096,    # Remove for unlimited page sizes.
  Timeout => 180,
);

sub got_response {
  my ($heap, $request_packet, $response_packet) = @_[HEAP, ARG0, ARG1];
  my $http_request    = $request_packet->[0];
  my $http_response   = $response_packet->[0];
  my $response_string = $http_response->as_string();

  # Client response, we could be good and check for errors here
}

# **************** HTTP SERVER **********************
# Spawn a web server on all interfaces.

 sub error_handler {
    my ($syscall_name, $error_number, $error_string) = @_[ARG0, ARG1, ARG2];

    print "MEH an error $error_string";
    exit(-1);
  }

POE::Component::Server::TCP->new(
  Alias        => "web_server",
  Port         => $http_server_port,
  ClientFilter => 'POE::Filter::HTTPD',
  Error        => \&error_handler,
 
  ClientInput => sub {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    if ($request->isa("HTTP::Response")) {
      $heap->{client}->put($request);
      $kernel->yield("shutdown");
      return;
    }

    my $msg=uri_unescape($request->uri());

    $msg =~ s/\///;

    if($msg =~ m/\?PNG=1/)

    {
       my $response = HTTP::Response->new(200);
       $response->push_header('Content-type', 'text');
       $response->content("PONG");
       $heap->{client}->put($response);
       $kernel->yield("shutdown");
       return;
    }


    if($msg =~ m/\?URI=/)
    {
	$msg =~ s/\?URI=//;	
	$LLURI=$msg;
    }

    if($msg =~ m/\?MSG=/)
    {
	$msg =~ s/\?MSG=//;
	# Send the recieved message from http server to the IRC component
	$irc->call(privmsg => ("#The_Southern_Plains",$msg));
   }
   	
    my $response = HTTP::Response->new(200);
    $response->push_header('Content-type', 'text');
    $response->content("OK");

    # Once the content has been built, send it back to the client
    # and schedule a shutdown.

    $heap->{client}->put($response);
    $kernel->yield("shutdown");
  }
);

# ******************** POE *************************************

# Create the POE session

POE::Session->create(
     package_states => [ main => [ qw(got_response _start irc_public) ]],
 );

# Start POE.  This will run the server until it exits

$poe_kernel->run();
