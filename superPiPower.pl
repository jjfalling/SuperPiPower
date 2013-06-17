#!/usr/bin/env perl

#****************************************************************************
#*   Super Pi Power!                                                        *
#*   Turn outlets on and off from a webui running on the Pi!                *
#*                                                                          *
#*   Copyright (C) 2013 by Jeremy Falling except where noted.               *
#*                                                                          *
#*   This program is free software: you can redistribute it and/or modify   *
#*   it under the terms of the GNU General Public License as published by   *
#*   the Free Software Foundation, either version 3 of the License, or      *
#*   (at your option) any later version.                                    *
#*                                                                          *
#*   This program is distributed in the hope that it will be useful,        *
#*   but WITHOUT ANY WARRANTY; without even the implied warranty of         *
#*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          *
#*   GNU General Public License for more details.                           *
#*                                                                          *
#*   You should have received a copy of the GNU General Public License      *
#*   along with this program.  If not, see <http://www.gnu.org/licenses/>.  *
#****************************************************************************

use strict;
use warnings;
use Config::Simple;
use Data::Dumper;


#Define our config file
my $configFile = "superPiPower.cfg";

#define program info
my $progamName = "Super Pi Power!";
my $version = "2.0";


my ($on, $off, $reqPin, $curPin, $currentStatus, $junk, $url, $config, $key, $value, $last_key, $buffer, @pairs, $pair, $name, %FORM, $configError);


#Send some headers
print "Content-type:text/html\r\n\r\n";
print '<!DOCTYPE HTML SYSTEM>' . "\n";
print '<html>' . "\n";
print '<head>' . "\n";
print '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">' . "\n";
print '<title>Super Pi Power!</title>' . "\n";
print '</head>' . "\n";
print '<body>' . "\n";
print '<center>' . "\n";
print "<h1>$progamName</h1> <hr width=\"260px\">" . "\n";



#check if config file exists, and if not make one 
unless (-e $configFile) {
	$config = new Config::Simple(syntax=>'ini');
	print "Note: no config was found, a default was generated...<br>";
    &generateConfigFile;
}

$config = new Config::Simple(filename=>"$configFile");


#get options from config file
my @outlets = $config->param("superPiPower.outlets");
my @outletNames = $config->param("superPiPower.outletNames");
my $mode = $config->param("superPiPower.mode");
my $https = $config->param("superPiPower.https");


#get url
if ($https eq "true") {
	$url="https://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}";
}
else {
	$url="http://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}";
}

# Read in text from post
$ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;
if ($ENV{'REQUEST_METHOD'} eq "POST")
{
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
}
else {
	$buffer = $ENV{'QUERY_STRING'};
}

# Split information into name/value pairs
@pairs = split(/&/, $buffer);
foreach $pair (@pairs)
{
	($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%(..)/pack("C", hex($1))/eg;
	$FORM{$name} = $value;
}

#store the requested outlet and action
my $outlet = $FORM{outlet};
my $action = $FORM{action};


if ($action eq "settings") {

	print "<form name=\"powerAction\" action=\"$url\" method=\"POST\">" . "\n";
	print '<br>';
	print '<table border="0">';

	#text tables for outlets and names
	print "Outlet pins and names are 1:1. <br>Values are comma seperated<br></td></tr>\n";
	print "<tr><td>Outlet pins: </td><td><input type=\"text\" name=\"outlets\" value=\"";
	$last_key = @outlets;
	$key=0;
	foreach (@outlets){print "$_"; $key++; unless ($key == $last_key) {print ",";} }
	print "\"><br></td></tr>\n";
	print "<tr><td>Outlet names: </td><td><input type=\"text\" name=\"outletNames\" value=\"";
	$last_key = @outletNames;
	$key=0;
	foreach (@outletNames){print "$_"; $key++; unless ($key == $last_key) {print ",";} }
	print "\"><br></td></tr>\n";

	#print options for the mode
	print "<tr><td>Relay mode: </td><td><input type=\"radio\" name=\"mode\" value=\"0\"";  
	if ( $mode == 0) {print "checked";}
	print ">NO (0) <input type=\"radio\" name=\"mode\" value=\"1\"";  
	if ( $mode == 1) {print "checked";}
	print ">NC (1)</td></tr>" . "\n";

	#print options for https
	print "<tr><td>Use https:</td><td><input type=\"radio\" name=\"https\" value=\"true\"";  
	if ( $https eq "true") {print "checked";}
	print ">True &nbsp&nbsp&nbsp&nbsp<input type=\"radio\" name=\"https\" value=\"false\"";  
	if ( $https eq "false") {print "checked";}
	print ">False</td></tr>" . "\n";
	print "</table>";
	print '<br><button type="submit" name="action" value="configUpdate">Submit</button> '. "\n";
	print '</form>';

}

elsif ($action eq "configUpdate"){

	my @setOutlets = split(/\,/, $FORM{outlets});
	my @setOutletNames = split(/\,/, $FORM{outletNames});

	$config->param("superPiPower.outlets", "$FORM{outlets}");
	$config->param("superPiPower.outletNames", "$FORM{outletNames}");
	$config->param("superPiPower.mode", "$FORM{mode}");
	$config->param("superPiPower.https", "$FORM{https}");

	$config->write() or $configError = 1;
		if ($configError == 1){
			print "<br>ERROR: Could not update config file! Check your permissions!<br>";
			die;
		}
		else{
			print "<br>Config has been updated<br>";
			print "<form action=\"$url\"><input type=\"submit\" value=\"Return to main page\"></form>";
			
		}

	
}


#if not requesting a config update, 
else {
	#To prevent errors, make outlet=0 if not defined (since 0 is not a valid outlet)
	if (!defined $outlet) {$outlet = "0";}

	#get the number of outlets in the array
	my $numOfOutlets = $#outlets + 1;

	#if a post was made, get the gpio pin for the requested outlet
	if ($ENV{'REQUEST_METHOD'} eq "POST")
	{
		$reqPin = $outlet - 1;
		$curPin = $outlets[$reqPin];
	
		#Setup current pin. What we do here is see if folder for the pin exists. If it does not then the pin has not been set up.
		unless (-e "/sys/class/gpio/gpio$curPin") {
			system("sudo bash -c 'echo \"$curPin\" > /sys/class/gpio/export'");
			system("sudo bash -c 'echo \"out\" > /sys/class/gpio/gpio$curPin/direction'");
		} 
	
	}

	#Check to see what the mode is, and set on/off values accordingly
	if ($mode == 1){
		$on = 0;
		$off = 1;
	}

	else{
		$on = 1;
		$off = 0;
	}



	#Check if we are processing a post, if not then don't print action preformed or attempt to do anything
	if ($ENV{'REQUEST_METHOD'} eq "POST")
	{    
		print "Action preformed: Outlet: $outlet Action: $action <br>";
	
		#preform sanity check
		if ($outlet <= 0 or $outlet > $numOfOutlets )
		{
			print "ERROR: Outlet $outlet is not within valid range";
		}

		else
		{
			#check if status was requested, if so get the status of outlet
			if ($action eq "status")
			{ 
				$currentStatus = `cat /sys/class/gpio/gpio$curPin/value`;
				print "Current status of outlet $outlet: ";
				if ($currentStatus == $on) 
				{
				print "ON";
				}
				else
				{
				print "OFF";
				}
			}
			elsif ($action eq "on")
			{ 
				$currentStatus = `sudo bash -c 'echo "$on" > /sys/class/gpio/gpio$curPin/value'`;
			}
			elsif ($action eq "off")
			{ 
				$currentStatus = `sudo bash -c 'echo "$off" > /sys/class/gpio/gpio$curPin/value'`;
			}
			else
					{
							print 'ERROR: Invalid action requested<br>';
				print 'ERROR: Invalid action requested<br>';
					}
		}
	}
	print "<form name=\"powerAction\" action=\"$url\" method=\"POST\">" . "\n";
	print '<br><table border="0">';

	#Auto generate the outlet options
	for ($numOfOutlets)
	{
		my $i = 1;
		my $max = $numOfOutlets + 1;

		while ($i < $max)
		{
			my $currentName = $i - 1;
		
			print "<tr><td><input type=\"radio\" name=\"outlet\" value=\"$i\"";
			#If an action was requested for this outlet id, print checked.  
			if ( $i == $outlet) {print "checked";}
			print "></td><td>Outlet $i - $outletNames[$currentName]</td></tr>" . "\n";
			$i++;
		}

	}

	print '</table>';
	print '<button type="submit" name="action" value="on">On</button>'. "\n";
	print '<button type="submit" name="action" value="off">Off</button>'. "\n";
	print '<button type="submit" name="action" value="status">Status</button>' . "\n";
	print '</form>';

}



print "</center>\n";
print "<br><br><br>\n";
print "<i>Version: $version on: $ENV{'HTTP_HOST'} running: $ENV{SERVER_SOFTWARE}</i> <br>" . "\n";

print "<form name=\"settings\" action=\"$url\" method=\"POST\"><button type=\"submit\" name=\"action\" value=\"settings\">Settings</button></form>";
print "<form action=\"$url\"><input type=\"submit\" value=\"Reset Page\"></form>";
print "</body>\n";
print "</html>";



sub generateConfigFile{

	$config->param("superPiPower.outlets", "23,24");
	$config->param("superPiPower.outletNames", "tv,another device");
	$config->param("superPiPower.mode", 1);
	$config->param("superPiPower.https", "false");
	$config->write("$configFile") or $configError = 1;
	if ($configError == 1){
		print "<br>ERROR: Could not create config file. Check your permissions!<br>";
		die;
	}


}

