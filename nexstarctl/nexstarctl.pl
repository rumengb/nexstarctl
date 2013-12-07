#!/usr/bin/perl
use strict;
use NexStarCtl;
use Date::Parse;
use Time::Local;
use POSIX qw( strftime );
use Getopt::Std;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

my $VERSION = "0.1";

my $port;
my $verbose;

sub print_help() {
	print "\n".
	      "Celestron Nexstar telescope control tool v.$VERSION. Its primary purpose is to illustrate\n".
	      "how NexStarCtl module can be used, but it is a useful tool for telescope automation.\n",
	      "This is a GPL software, created by Rumen G. Bogdanovski.\n".
	      "\n".
	      "Usage: $0 info [telescope]\n".
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
	      "       The telescope port could be specified with this parameter or TELESCOPE_PORT environment can be set.\n".
	      "       Defaults depend on the operating system:\n".
	      "          Linux: /dev/ttyUSB0\n".
	      "          MacOSX: /dev/cu.usbserial\n".
	      "          Solaris: /dev/ttya\n"
}


sub check_align($) {
	my ($dev) = @_;
	my $align = tc_check_align($dev);
	if (!defined $align) {
		print RED "Error reading from telescope.\n";
		return undef;
	} elsif ($align == 0) {
		print RED "The telescope is NOT aligned. Please complete the alignment routine.\n";
		return undef;
	}
	$verbose && print GREEN "The telescope is aligned.\n";
}


sub init_telescope {
	my ($tport, $nocheck) = @_;
	my $dev = open_telescope_port($tport);
	if (!defined($dev)) {
		print RED "Can\'t open telescope at $tport: $!\n";
		return undef;
	}

	$verbose && print GREEN "The telescope port $tport is open.\n";

	if ($nocheck) {
		return $dev;
	}

	if (tc_goto_in_progress($dev)) {
		print RED "GOTO in progress, try again.\n";
		close_telescope_port($dev);
		return undef;
	}

	return $dev;
}

sub info {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "info: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	print "Driver: NexStarCtl v.$NexStarCtl::VERSION\n";

	my $echo = tc_echo($dev,"X");
	if ($echo ne "X") {
		print RED "No telescope mount found on port $port\n";
		close_telescope_port($dev);
		return undef;
	}
	print "Mount port: $port\n";

	my $model = tc_get_model($dev);
	if (!defined $model) {
		print RED "info: Error getting model. $!\n";
		close_telescope_port($dev);
		return undef;
	}
	my $model_name = get_model_name($model);
	print "Mount model: $model_name ($model)\n";

	my $version = tc_get_version($dev);
	if (!defined $version) {
		print RED "info: Errror getting version. $!\n";
		close_telescope_port($dev);
		return undef;
	}
	print "HC version: $version\n";

	close_telescope_port($dev);
	return 1;
}

sub status {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "status: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	my $status = tc_goto_in_progress($dev);
	if (!defined $status) {
		print RED "status: Errror getting goto status. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	my $tracking = tc_get_tracking_mode($dev);
	if (!defined $tracking) {
		print RED "status: Errror geting tracking mode. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	if (($status == 0) && ($tracking == TC_TRACK_OFF)) {
		print "Telescope is not tracking.\n";
	} elsif (($status == 0) && ($tracking != TC_TRACK_OFF)) {
		print "Telescope is tracking.\n";
	} else {
		print "GOTO is in progress.\n";
	}

	close_telescope_port($dev);
	return 1;
}

sub gettime {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "gettime: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	my ($date, $time, $tz, $isdst) = tc_get_time_str($dev);
	if (! defined $date) {
		print RED "gettime: Failed. $!\n";
		close_telescope_port($dev);
		return undef;
	}
	print "$date $time, TZ = $tz, DST = $isdst\n";

	close_telescope_port($dev);
	return 1;
}

sub settime {
	my @params = @_;
	my $date;
	my $tz;
	my $time;
	my $isdst;

	if ($#params == 2) {
		$date = $params[0];
		$tz = round($params[1]);
		$isdst = $params[2];

	} elsif ($#params == 3) {
		$date = $params[0];
		$tz = round($params[1]);
		$isdst = $params[2];
		$port = $params[3];

	} elsif ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
		$time=time();
	    $isdst = (localtime($time))[-1];
		$tz = int((timegm(localtime($time)) - $time) / 3600);
		$tz = $tz-1 if ($isdst);

	} else {
		print RED "settime: Wrong parameters.\n";
		return undef;
	}

	if (($tz < -12) or ($tz > 12)) {
		print RED "settime: Wrong time zone.\n";
		return undef;
	}

	# if $date is defined => the date is given by user
	if (defined $date) {
		$time = str2time($date);
		if (!defined $time) {
			print RED "settime: Wrong date format.\n";
			return undef;
		}
	}

	my $dev = init_telescope($port);
	return undef if (! defined $dev);

	my ($s, $m, $h, $day, $mon, $year) = localtime($time);
	my $time_str = sprintf("%2d:%02d:%02d", $h, $m, $s);
	my $date_str = sprintf("%02d-%02d-%04d", $day, $mon + 1, $year + 1900);
	$verbose && print "settime: $date_str $time_str, TZ = $tz, DST = $isdst\n";

	if (! tc_set_time($dev, $time, $tz, $isdst)) {
		print RED "settime: Failed. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	close_telescope_port($dev);
	return 1;
}

sub getlocation {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "getlocation: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	my ($lon,$lat) = tc_get_location_str($dev);
	if (! defined $lon) {
		print RED "getlocation: Failed. $!\n";
		close_telescope_port($dev);
		return undef;
	}
	print "$lon, $lat\n";

	close_telescope_port($dev);
	return 1;
}

sub setlocation {
	my @params = @_;
	my $lon;
	my $lat;

	if ($#params == 1) {
		$lon = $params[0];
		$lat = $params[1];

	} elsif ($#params == 2) {
		$lon = $params[0];
		$lat = $params[1];
		$port = $params[3];

	} else {
		print RED "settime: Wrong parameters.\n";
		return undef;
	}

	my $lond = dms2d($lon);
	if ((!defined $lond) or ($lond > 180) or ($lond < -180)) {
		print RED "setlocation: Wrong longitude.\n";
		return undef;
	}

	my $latd = dms2d($lat);
	if ((!defined $latd) or ($latd > 180) or ($latd < -180)) {
		print RED "setlocation: Wrong latitude.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	$verbose && print "setlocation: Lon = $lond, Lat = $latd\n";

	if (! tc_set_location($dev, $lond, $latd)) {
		print RED "setlocation: Failed. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	close_telescope_port($dev);
	return 1;
}

sub gettrack {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "gettrack: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	my $tracking = tc_get_tracking_mode($dev);
	if (!defined $tracking) {
		print RED "status: Errror geting tracking mode. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	if ($tracking == TC_TRACK_OFF) {
		print "Tracking: OFF\n";
	} elsif ($tracking == TC_TRACK_EQ_SOUTH) {
		print "Tracking: Equatorial South\n";
	} elsif ($tracking == TC_TRACK_EQ_NORTH) {
		print "Tracking: Equatorial North\n";
	} elsif ($tracking == TC_TRACK_ALT_AZ) {
		print "Tracking: Aaltazimuthal\n";
	} else {
		print "Tracking: Unknown\n";
	}

	close_telescope_port($dev);
	return 1;
}

sub abort {
	my @params = @_;
	if ($#params <= 0) {
		if (defined $params[0]) {
			$port = $params[0];
		}
	} else {
		print RED "gettrack: Wrong parameters.\n";
		return undef;
	}

	my $dev = init_telescope($port, 1);
	return undef if (! defined $dev);

	my $reult = tc_goto_cancel($dev);
	if (!defined $reult) {
		print RED "abort: Failed. $!\n";
		close_telescope_port($dev);
		return undef;
	}

	close_telescope_port($dev);
	return 1;
}


sub main() {
	my %options = ();

	my $command = shift @ARGV;

	if (defined $ENV{TELESCOPE_PORT}) {
		$port = $ENV{TELESCOPE_PORT};
	} else {
		if ($^O eq 'linux') {
			$port = "/dev/ttyUSB0";
		} elsif ($^O eq 'darwin') {
			$port = "/dev/cu.usbserial";
		} elsif ($^O eq 'solaris') {
			$port = "/dev/ttya";
		}
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
		if (! info(@ARGV)) {
			$verbose && print RED "Get info returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Get info succeeded.\n";
		exit 0;

	} elsif ($command eq "gettime") {
		if (! gettime(@ARGV)) {
			$verbose && print RED "Get time returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Get time succeeded.\n";
		exit 0;

	} elsif ($command eq "settime") {
		if (! settime(@ARGV)) {
			$verbose && print RED "Set time returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Set time succeeded.\n";
		exit 0;

	} elsif ($command eq "getlocation") {
		if (! getlocation(@ARGV)) {
			$verbose && print RED "Get location returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Get location succeeded.\n";
		exit 0;

	} elsif ($command eq "setlocation") {
		if (! setlocation(@ARGV)) {
			$verbose && print RED "Set location returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Set location succeeded.\n";
		exit 0;

	} elsif ($command eq "settrack") {
		print "settrack issued: $port\n";

	} elsif ($command eq "gettrack") {
		if (! gettrack(@ARGV)) {
			$verbose && print RED "Get track returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Get track succeeded.\n";
		exit 0;

	} elsif ($command eq "goto") {
		print "goto issued: $port\n";

	} elsif ($command eq "gotoaz") {
		print "gotoaz issued: $port\n";

	} elsif ($command eq "getrade") {
		print "getrade issued: $port\n";

	} elsif ($command eq "getazalt") {
		print "getazalt issued: $port\n";

	} elsif ($command eq "abort") {
		if (! abort(@ARGV)) {
			$verbose && print RED "abort returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "abort succeeded.\n";
		exit 0;

	} elsif ($command eq "status") {
		if (! status(@ARGV)) {
			$verbose && print RED "Status returned error.\n";
			exit 1;
		}
		$verbose && print GREEN "Status succeeded.\n";
		exit 0;

	} elsif ($command eq "-h") {
		print_help();
		exit 0;

	} else {
		print RED "There is no such command \"$command\".\n";
	}
}

main;
