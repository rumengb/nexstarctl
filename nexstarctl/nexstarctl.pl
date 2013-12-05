#!/usr/bin/perl
use strict;
use NexStarCtl;
use Date::Parse;
use Time::Local;
use POSIX qw( strftime );
use Getopt::Std;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

my $port;
my $verbose;

sub print_help() {
	print "Usage: $0 info [telescope]\n".
	      "       $0 settime \"DATE TIME\" TZ ISDST [telescope]\n".
	      "       $0 settime [telescope]\n".
	      "       $0 gettime [telescope]\n".
	      "       $0 setlocation LON LAT [telescope]\n".
	      "       $0 getlocation [telescope]\n".
	      "       $0 settrack [north|south|azalt|off] [telescope]\n".
	      "       $0 gettrack [telescope]\n".
	      "       $0 goto RA DE [telescope]\n".
	      "       $0 gotoaz AZ ALT [telescope]\n".
	      "       $0 getrade [telescope]\n".
	      "       $0 getazalt [teelescope]\n".
	      "       $0 abort [telescope]\n".
	      "       $0 status [telescope]\n".
	      "options:\n".
	      "       -v verbose output\n".
	      "       -h print this help\n".
	      "[telescope]:\n".
	      "       Specify the telescope port. Defaults depend on the operating system:\n".
	      "          Linux: /dev/ttyUSB0\n".
	      "          MacOSX: /dev/cu.usbserial\n".
	      "          Solaris: /dev/ttya\n"
}


sub get_time {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "Wrong parameters.\n";
		return undef;
	}

	#get time here
	print time()."\n";
}


sub set_time {
	my @params = @_;
	my $date;
	my $tz;
	my $time;
	my $isdst;

	if($#params == 2) {
		$date = $params[0];
		$tz = round($params[1]);
		$isdst = $params[2];

	} elsif ($#params == 3) {
		$date = $params[0];
		$tz = round($params[1]);
		$isdst = $params[2];
		$port = $params[2];

	} elsif ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
		$time=time();
	    $isdst = (localtime($time))[-1];
		$tz = int((timegm(localtime($time)) - $time) / 3600);
		$tz = $tz-1 if ($isdst);

	} else {
		print RED "Wrong parameters.\n";
		return undef;
	}

	if (($tz < -12) or ($tz > 12)) {
		print RED "Wrong time zone.\n";
		return undef;
	}

	# if $date is defined => the date is given by user
	if (defined $date) {
		print "USER: ";
		$time = str2time($date);
		if (!defined $time) {
			print RED "Wrong date format.\n";
			return undef;
		}
	}

	print "Setting time: ". strftime("%F %T", localtime($time)).", TZ = $tz, isDST = $isdst\n";
	# set the telescope time here

	return 1;
}


sub main() {
	my %options = ();

	my $command = shift @ARGV;

	if ($^O eq 'linux') {
		$port = "/dev/ttyUSB0";
	} elsif ($^O eq 'darwin') {
		$port = "/dev/cu.usbserial";
	} elsif ($^O eq 'solaris') {
		$port = "/dev/ttya";
	}

	if (getopts("vh", \%options) == undef) {
		exit 1;
	}

	if (defined($options{h}) or (!defined($command))) {
		print_help();
		exit 1;
	}

	if(defined($options{v})) {
		$verbose = 1;
	}

	if ($command eq "info") {
		print "info issued: $port\n";

	} elsif ($command eq "gettime") {
		if (! get_time(@ARGV)) {
			print RED "Get time error.\n";
			exit 1;
		}
		exit 0;

	} elsif ($command eq "settime") {
		if (! set_time(@ARGV)) {
			print RED "Set time error.\n";
			exit 1;
		} else {
			print GREEN "Time Set Successfully.\n";
			exit 0;
		}

	} elsif ($command eq "getlocation") {
		print "getlocation issued: $port\n";

	} elsif ($command eq "setlocation") {
		print "setlocation issued: $port\n";

	} elsif ($command eq "settrack") {
		print "settrack issued: $port\n";

	} elsif ($command eq "gettrack") {
		print "gettrack issued: $port\n";

	} elsif ($command eq "goto") {
		print "goto issued: $port\n";

	} elsif ($command eq "gotoaz") {
		print "gotoaz issued: $port\n";

	} elsif ($command eq "getrade") {
		print "getrade issued: $port\n";

	} elsif ($command eq "getazalt") {
		print "getazalt issued: $port\n";

	} elsif ($command eq "abort") {
		print "abort issued: $port\n";

	} elsif ($command eq "status") {
		print "status issued: $port\n";

	} elsif ($command eq "-h") {
		print_help();
		exit 0;

	} else {
		print RED "What?\n";
	}
}

main;