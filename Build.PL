#!/usr/bin/perl
# $Id: Build.PL,v 1.1 2004/01/08 01:41:03 nothingmuch Exp $

use strict;
use warnings;

use Module::Build;

our $VERSION = 0.01;

Module::Build->new(
	module_name => 'Pod::Wrap',
	license => 'perl',
	requires => {
		'perl'				=> '>= 5.6.0',
		'Text::Wrap'		=> 0,
		'Pod::Parser'		=> 0,
	},
	script_files => [ 'scripts/podwrap' ],
	create_makefile_pl => "traditional",
	sign => 1,
)->create_build_script;
