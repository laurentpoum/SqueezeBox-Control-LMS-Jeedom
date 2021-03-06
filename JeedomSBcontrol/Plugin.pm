package Plugins::JeedomSBcontrol::Plugin;

# HelloWorld tutorial plugin by Mitch Gerdisch
# Meant to be a way of figuring out and understanding how plugins need to be written for SC7.
# There are 4 basic components that need to be written for SC7 plugins:
#	Plugin.pm - This is the main processing bit of the plugin and not much different than pre-SC7 plugin code.
#				But, there are differences.
#	Settings.pm - This file contains perl code for processing the web page used to set the settings for the plugin.
#	strings.txt - Where all the strings are stored - including their various lanuage equivalents.
#	basic.html - This is a file under HTML/<language abbrev.>/plugins/<plugin name>/settings/. It contains 
#				 HTML-like stuff for displaying the plugin's web user interface.

# This code is derived from code with the following copyright message:
#
# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# required bit
use strict;

# required bit
use base qw(Slim::Plugin::Base);

# Plugin specific bit - put name of plugin where HelloWorld is.
# This points to the Settings.pm file that you also need to create/update for the plugin.
use Plugins::JeedomSbcontrol::Settings;
use Slim::Music::Info;

use Slim::Utils::Misc;
use Slim::Utils::Network;
use Slim::Player::Player;
use Slim::Player::Client;
use Slim::Player::Sync;
# Might be required. At least it's not bad to include it.
use Scalar::Util qw(blessed);

# Might be required. Not sure, but again it doesn't hurt.
use Slim::Control::Request;

# MUST HAVE: This log bit is new and allows one to use nicer logging facilities than were available pre-SC7
use Slim::Utils::Log;

# MUST HAVE: magical preferences getting stuff
use Slim::Utils::Prefs;

# MUST HAVE: provides the strings functionality that uses the strings.txt file to present the correct language
use Slim::Utils::Strings qw(string);

my $jeedomip;
my $jeedomkey;
my $jeedomcomplement;
# So, get the data related to this plugin.
# The call to preferences() will be "plugin.<plugin name in lowercase>
# Something that might be interesting, there's actually a prefs file for each plugin.
# On Windows its stored in documents and settings/all users/application data/squeezecenter/prefs.
# You can look at it (it's a text file) and see what is being currently stored.
# However, there seems to be a lag between doing a set and it actually showing up in the file, fyi.
my $prefs = preferences('plugin.jeedomsbcontrol');

# Any global variables? Go ahead and declare and/or set them here
our @browseMenuChoices;

# used for logging
# To debug, run squeezecenter.exe from the command prompt as follows:
# squeezecenter.exe --debug plugin.<plugin name>=<logging level in caps>
# Log levels are DEBUG, INFO, WARN, ERROR, FATAL where a level will include messages for all levels to the right.
# So, squeezecenter.exe --debug plugin.helloworld=INFO,persist will show all messages fro INFO, WARN, ERROR, and FATAL.
# The "persist" bit of text allows the system to remember that logging level between invocations of squeezecenter.
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.jeedomsbcontrol',
	'defaultLevel' => 'INFO',
#	'defaultLevel' => 'DEBUG',
	'description'  => getDisplayName(),
});

# This is an old friend from pre-SC7 days
# It returns the name to display on the squeezebox
sub getDisplayName {
	return 'PLUGIN_JEEDOMSBCONTROL';
}

# I have my own debug routine so that I can add the *** stuff easily.
sub myDebug {
	my $msg = shift;
	my $lvl = shift;
	
	if ($lvl eq "")
	{
		$lvl = "debug";
	}

	
	$log->$lvl("*** JeedomSbcontrol *** $msg");
}

# Another old friend from pre-SC7 days.
# This is called when SC loads the plugin.
# So use it to initialize variables and the like.
sub initPlugin {

	$jeedomip =	$prefs->get('ip');
	$jeedomkey  =	$prefs->get('key');
	$jeedomcomplement  =	$prefs->get('complement');
    
	my $class = shift;
	
	myDebug("Initializing");
		
	$class->SUPER::initPlugin();

	Plugins::JeedomSBcontrol::Settings->new;
	
	Slim::Control::Request::subscribe( \&commandCallbackVolume, [['mixer']]);
    
    Slim::Control::Request::subscribe( \&commandCallbackNewsong, [['playlist'], ['newsong']]);
    
    Slim::Control::Request::subscribe( \&commandCallback, [['play', 'playlist', 'pause']]);

}

sub shutdownPlugin {

	Slim::Control::Request::unsubscribe(\&commandCallbackVolume);
    
    Slim::Control::Request::unsubscribe(\&commandCallbackNewsong);
    
    Slim::Control::Request::unsubscribe(\&commandCallback);

}



sub commandCallbackVolume {
	my $request = shift;

	my $client = $request->client();
	if( !defined( $client)) {
		return;
	}
		
	my $iPower = $client->power();

	if( $request->isCommand([['mixer'], ['volume']])  ) {
		if($iPower ==  1) {
			
			my $iVolume = $client->volume();			
			my $mac = ref($client) ? $client->macaddress() : $client;
			my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
			\&exampleErrorCallback, 
			{
                client => $client, 
            });

        $http->get("http://$jeedomip$jeedomcomplement/core/api/jeeApi.php?api=$jeedomkey&type=squeezeboxcontrol&adress=$mac&logicalId=volume&value=$iVolume");
		}
	}	
}

sub commandCallbackNewsong {
	my $request = shift;

	my $client = $request->client();
	if( !defined( $client)) {
		return;
	}
		
   

	if( $request->isCommand([['playlist'], ['newsong']]) ) {
		
    
	my $sTitle = $client->playingSong();
	
	my $sName =  'No Track';	
	my $artist   = '';
	my $album    = '';
	my $tracknum = '';
	my $duration =  0;
	my $played =  0;
	
	eval {$sName =  $sTitle->track()->title  || '';	}; warn $@ if $@;
	eval { $artist   = $sTitle->track()->artistName || '';}; warn $@ if $@;
	eval { $album    = $sTitle->track()->album->name || '';}; warn $@ if $@;
	eval { $tracknum = $sTitle->track()->tracknum || '';}; warn $@ if $@;
	eval { $duration = $sTitle->track()->secs;}; warn $@ if $@;

        
my $mac = ref($client) ? $client->macaddress() : $client;
my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
	\&exampleErrorCallback, 
	{
                        client => $client, 
                        
                });

        $http->get("http://$jeedomip$jeedomcomplement/core/api/jeeApi.php?api=$jeedomkey&type=squeezeboxcontrol&adress=$mac&logicalId=infos&titre=$sName&artis=$artist&album=$album");
	}	
}

sub commandCallback {
	my $request = shift;

	my $client = $request->client();

	# Do nothing if client is not defined
	if( !defined( $client)) {
		return;
	}

	my $iPaused = $client->isPaused();
	my $iStopped = $client->isStopped();

	if ($request->isCommand([['pause'] ]) 
		|| $request->isCommand([['playlist'], ['pause']])){
		
		if($iPaused ne  1) {
			my $mac = ref($client) ? $client->macaddress() : $client;
			my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
			\&exampleErrorCallback, 
			{
              client => $client,        
                });

        $http->get('http://$jeedomip$jeedomcomplement/core/api/jeeApi.php?api=$jeedomkey&type=squeezeboxcontrol&adress=$mac&value={"statut":"Lecture"}');
		}
		else {
						my $mac = ref($client) ? $client->macaddress() : $client;
my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
	\&exampleErrorCallback, 
	{
                        client => $client, 
                        
                });

        $http->get("http://$jeedomipaddress/core/api/jeeApi.php?api=$jeedomapi&type=squeezebox&adress=$mac&logicalId=statut&value=Pause");
		}				
	}	
	 elsif( $request->isCommand([['play']])
		|| $request->isCommand([['playlist'], ['newsong']]) 
		|| $request->isCommand([['playlist'], ['play']])
		|| $request->isCommand([['playlist'], ['resume']])){
			
					my $mac = ref($client) ? $client->macaddress() : $client;
my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
	\&exampleErrorCallback, 
	{
                        client => $client, 
                        
                });

        $http->get("http://$jeedomipaddress/core/api/jeeApi.php?api=$jeedomapi&type=squeezebox&adress=$mac&logicalId=statut&value=Lecture");
	}	 
	 elsif( $request->isCommand([['playlist'], ['stop']]) 
	 	 || $request->isCommand([['playlist'], ['clear']]) ) {				 
		if ($iStopped == 1){			
				&handlePlayStop($client);
		}
	}
		
}

sub handlePlayStop {
	my $client = shift;

	
	
	my $iPower = $client->power();
	
	
					my $mac = ref($client) ? $client->macaddress() : $client;

	if ($iPower == 1){
my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
	\&exampleErrorCallback, 
	{
                        client => $client, 
                        
                });

        $http->get("http://$jeedomipaddress/core/api/jeeApi.php?api=$jeedomapi&type=squeezebox&adress=$mac&logicalId=statut&value=Stop"); 		
	}
	else{
my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
	\&exampleErrorCallback, 
	{
                        client => $client, 
                        
                });

        $http->get("http://$jeedomipaddress/core/api/jeeApi.php?api=$jeedomapi&type=squeezebox&adress=$mac&logicalId=statut&value=Off");
	}


}# Always end with a 1 to make Perl happy

sub exampleCallback {

}

sub exampleErrorCallback {



}
1;
