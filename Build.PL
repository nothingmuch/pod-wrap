#!/usr/bin/perl
# $Id: Build.PL,v 1.3 2004/01/13 16:31:37 nothingmuch Exp $

use strict;
use warnings;

use Module::Build;

our $VERSION = 0.01;

Module::Build->new(
	module_name => 'Pod::Wrap',
	license => 'perl',
	requires => {
		# Pod::Wrap
		'perl'				=> '>= 5.6.0',
		'Text::Wrap'		=> 0,
		'Pod::Parser'		=> 0,
		
		# podwrap command
		'Getopt::Long'		=> 0,
		'Pod::Usage'		=> 0,
	},
	create_makefile_pl => "traditional",
	script_files => [ 'scripts/podwrap' ],
)->create_build_script;
