#!/usr/bin/perl
# $Id: deparse_cmp.t,v 1.2 2004/01/13 16:31:23 nothingmuch Exp $

use strict;
use warnings;

use Test::More;
eval { require 5.005 and require IO::Scalar } or plan skip_all => 'Need IO::Scalar or open FH, \$scalar';
eval { require IPC::Open3 } or plan skip_all => "Need pipes for B::Deparse. I don't know of another way yet.";
eval { require B::Deparse } or plan skip_all => "B::Deparse is a prerequisite of the test suite.";
eval { require IO::Select } or plan skip_all => "IO::Selct is needed to get deparse output.";

if ($ENV{TEST_MANY_MODULES}){
	# lots of dependancies # thanks to the wonderful perl monks
	eval { require CPAN };
	eval { require CPANPLUS };
	eval { require LWP::Simple };
	eval { require Crypt::OpenPGP };
	eval { require WWW::Mechanize::Shell };
	eval { require Class::DBI };
	eval { require Net::LDAP };
	eval { require Net::SSH::Perl };
	eval { require Petal };	
	
	# quite big
	eval { require CGI };
	eval { require Mail::SpamAssassin };
	eval { require Mail::Box };
	eval { require Mail::Box::Manager };
	
	# lots of pod
	eval { require diagnostics };
	
	# core modules are likely to be there
	eval { require Scalar::Util };
	eval { require File::Temp };
	eval { require IO::Handle };
	eval { require Memoize };
	eval { require Test };
	eval { require Test::Simple };
	
	# interesting as a test suite.
	eval  { require Pod::Stripper };
}

my $diff = eval { require Text::Diff }; # more to test, and nicer output with large string comparisons

use Pod::Wrap;

$|=1;

$SIG{CHLD} = 'IGNORE'; #sub { wait until wait + 1 }; # damn lazy. Looks good with keyword highlighting.
$SIG{PIPE} = 'IGNORE'; # __END__s will cause perl to stop reading.

my @modules = values %INC;
plan tests => @modules + 1;

ok(Pod::Wrap->new(), "Create wrapper obj");

$Text::Wrap::columns = 90; # Opcode && Net::LDAP::Constant have __DATA__ section. It shouldn't be wrapped because B::Deparse keeps it (as it should).

foreach $_ (@modules){
	testFile($_); # test a filename
};

exit;

sub testFile {
	my $file = shift;
	
	my ($wrapped, $orig);
	
	
	SKIP:{
		eval { # for timer controls and open errors
			local $SIG{ALRM} = sub { die "Timed out" };
			alarm 15; # anything more is pretty excessive
			
			my $f = '';
			my $fh;
			if ($] >= 5.008){ open $fh, "+>", \$f or die $! } else { $fh = new IO::Scalar \$f };
			open IN, "<", $file or die $!;
			Pod::Wrap->new->parse_from_filehandle(\*IN,$fh);
			close IN or die $!;
			close $fh;
			if ($] >= 5.008){ open $fh, "<", \$f or die $! } else { $fh = new IO::Scalar \$f };
			#seek $fh, 0, SEEK_SET or die $!; # io scalar & <5.005_57 != Good Thing
			$wrapped = deparse($fh);
			close $fh or die $!;
			
			
			
			open IN, "<", $file or die $!;
			$f = '';
			my $r; 1 while($r =sysread IN, $f, 4096, length($f) and defined $r || die $! and $r);
			if ($] >= 5.008){ open $fh, "<", \$f or die $! } else { $fh = new IO::Scalar \$f };
			$orig = deparse($fh);
			close $fh or die $!;
			
			alarm 0;
		};
		
		if ($@){
			my $msg = $@;
			$msg =~ s/\n//sg;
			skip ("Couldn't deparse $file ($msg)",1);
		}
		
		local $TODO = "Decide if we want to do this one." if $file =~ /Stripper\.pm$/;
		
		if ($diff){ # if we have Text::Diff we make a nicer output on error
			if ($wrapped eq $orig){
				pass($file);
			} else {
				fail($file);
				my $diff = Text::Diff::diff(\$wrapped, \$orig);#, { STYLE => "Table" });
				foreach my $line (split($/, $diff)){
					diag($line);
				}
			}
		} else { is ($wrapped, $orig, $file) }
	}
}

sub deparse {
	my $fh = shift;
	my $output = '';
	
	eval { # for cleanup after errors
		local $ENV{PERL_HASH_SEED} = 0; # GRRR!!!! otherwise deparse output will not be consistent
		IPC::Open3::open3(\*WRITE, \*READ, \*ERR, $^X, "-MO=Deparse") or die $!; # should be fatal (if it fails, or just because it's plain wrong).
		
		# out various handles
		my $w = IO::Select->new(\*WRITE);
		my $r = IO::Select->new(\*READ, \*ERR);
		
		my $buf = '';
		
		# write, reading if needed
		my $p = 1;
		eval { # for sigpipes when we print __END__s.
			local $SIG{PIPE} = sub { close WRITE; $p = undef; die "Broken pipe" }; # end the write instead of trying over and over again
			WRITE: while(my @h = map { @$_ } IO::Select->select($r,$w)){
				foreach my $h (@h){
					if ($h == \*READ){
						defined(sysread READ, $output, 512, length($output)) or die $!;
					} elsif ($h == \*ERR){
						defined(sysread ERR, $buf, 512) or die $!;
					} elsif ($h == \*WRITE and not $w->has_exception(0)){
						if (read $fh, $buf, 512){
							defined(syswrite WRITE, $buf) or die $!;
						} else {
							defined(close WRITE) or die $!;
							last WRITE;
						}
					}
				}
			}
		}; if ($p and $@ and $@ =~ /(.*?) at $0 line \d+\./){ die $1 };
			
		# just read
		READ: { while(my @h = map { @$_ } IO::Select->select($r, undef, undef, 10)){ foreach my $h (@h){
			if ($h == \*READ){
				my $ret = sysread READ, $output, 512, length($output);
				if (defined $ret){ $ret or last READ } else { die $! };
			} elsif ($h == \*ERR) {
				defined(sysread ERR, $buf, 512) or die $!;
			} else {
				die "WTF?!\n";
			}
		}} die "$!" };
	
	};
	
	close WRITE if fileno(WRITE);
	close READ;
	close ERR;
	
	if ($@ and $@ =~ /(.*?) at $0 line \d+\./){ die $1 };
	
	return $output;
}
