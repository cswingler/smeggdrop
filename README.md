Shittybot
=========
A fork of Sam Stephenson's excellent smeggdrop.
No longer requires eggdrop
This fork uses AnyEvent, POE is on the outs.


Requirements:
------------
- Perl
  - AnyEvent::IRC::Client
  - Tcl
  - Moose
  - Time::Out
  - Carp::Always
  - Data::Dump
  - Config::Any
  - Config::General
  - YAML::XS (preferable)
  - parent
  - Net::SCP::Expect
- Tcl 8.4
  - -dev package
  - tcllib
  - tclcurl
  - tclx
- Git

Quickstart:
----------
- Edit shittybot.yml
- Run './run-bot'
