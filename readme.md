###Super Pi Power!

This is a perl cgi that is meant to run on the Raspberry Pi and turns gpio pins on and off to control relays attached to outlets. 
It modifies the gpio linux device instead of using the bcm2835 perl library and is developed under nginx with perl-fcgi.
The interface is a very basic html web page that should work with any device with a modern web browser. 

Requires Config::Simple.

I use sudo and the following sudoers entry to allow the webserver to modify the gpio pins:

     www-data        ALL=(ALL) NOPASSWD:/bin/bash -c echo * > /sys/class/gpio/*

On fist run it will generate a config file so the webserver will need to write to the same directory as cgi.

There are only four options that need to be set by the user in the webui.
* $mode which sets the type or configuration of your relay (NO or NC)
* $https which changes the links to use https instead of http. DO NOT set this unless you are behind a https server or the links will break! You can reset this in the config file by setting https=false
* @outlets is a comma separated list of pins connected to outlets. The first pin is outlet 1, etc. 
* @outletNames is a comma separated list of names for each outlet or name. They are 1:1 to the pins. 


See http://youtu.be/PVTMCSnzGkk for a demo of it in action. 
