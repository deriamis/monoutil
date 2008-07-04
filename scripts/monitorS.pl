#!/usr/bin/perl
#

use strict;
use warnings;
use Time::Local;
use File::Copy;
use IO::Socket;
use RRDs;

# General
our $MONITORS_VER="1.0";					# version
our $IDATE="01 Mars 2008";					# initial date
our	$FILE_RRD="/usr/local/lib/monitorS.rrd";		# directory of files RRD
our $FILE_LOG="/var/log/monitorS.log";		# log file of program
our $FILE_CONFIG_SERVICES="/usr/local/etc/services.conf"; 	# config file
our $FILE_CONFIG_NETWORKS="/usr/local/etc/networks.conf";
my $TIME_SLEEP = 300;						# 5 minutes

my @services;
my @networks;
my $num_services=0;
my $num_networks=0;


# read config file
# services.conf
my $line="";
open (CONFIG,"$FILE_CONFIG_SERVICES") || die "  Error opening log file $FILE_CONFIG_SERVICES.\n";
foreach $line (<CONFIG>) {
	if (index($line, "!") == 0) {		
		my @temp = split(' ', $line);
		chomp(@temp);
		$services[$num_services] = $temp[1];
		$num_services++;
	}
}
close (CONFIG);

# networks.conf
open (CONFIG,"$FILE_CONFIG_NETWORKS") || die "  Error opening log file $FILE_CONFIG_NETWORKS.\n";
foreach $line (<CONFIG>) {
	if (index($line, "!") == 0) {		
		my @temp = split(' ', $line);
		chomp(@temp);
		$networks[$num_networks] = $temp[1];
		$num_networks++;
	}
}
close (CONFIG);

# main process
if(($#ARGV+1) != 1) {
	syntax();
	exit(1);
}

if($ARGV[0] eq "init") {
	init();
}
elsif($ARGV[0] eq "stop") {
	stop();
}
elsif($ARGV[0] eq "create") {
	create();
}
elsif($ARGV[0] eq "update") {
	update();
} 
elsif($ARGV[0] eq "update_test") {
	my $n;
	for($n=0; $n < 120; $n++) {	# 10hours
		update();
	}
} 
elsif($ARGV[0] eq "graph") {
	graph();
}
else {
	syntax();
	exit(1);
}
exit(0);

sub syntax {
	print "MonitorS v" . $MONITORS_VER . "\n";
	print "Copyright © NGO Quang Minh <nqminh\@ifi.edu.vn>\n";
	print "\n";
	print "Usage: monitorS.pl [init|stop|create|update|graph]\n";
	print "\n";
}

# =========================================================
# 			INIT OPTION
# =========================================================

sub init {
	my $n;
	my $O_CRON = "/etc/cron.d/monitorS.sh";
	my $crontabuser = "root";

	open(OCRON, "> $O_CRON");
	print OCRON <<EOF;

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0,5,10,15,20,25,30,35,40,45,50,55 * * * * $crontabuser /usr/local/sbin/monitorS.pl update >/dev/null 2>&1

EOF
#	close(OCRON);
}

# =========================================================
# 			STOP OPTION
# =========================================================

sub stop {
	# We need to remove the crontab file to stop MonitorS.
	unlink("/etc/cron.d/monitorS.sh");
}

# ==================================================
# 			CREATE OPTION
# ==================================================

sub create {
# RRA: average data of 300*288 secs = 1 day
# RRA: average data of 300*6*336 secs = 1 week
# RRA: average data of 300*12*744 secs = 1 month
# RRA: average data of 300*288*365 secs = 1 year
# RRA: max data of 300*288 secs = 1 day
# RRA: max data of 300*6*336 secs = 1 week
# RRA: max data of 300*12*744 secs = 1 month
# RRA: max data of 300*288*365 secs = 1 year
# RRA: last data of 300*288 secs = 1 day
# RRA: last data of 300*6*336 secs = 1 week
# RRA: last data of 300*12*744 secs = 1 month
# RRA: last data of 300*288*365 secs = 1 year
	my @ds_services_in;
	my @ds_services_out;
	my @ds_networks_in;
	my @ds_networks_out;
	
	my $n = 0;
	for($n=0; $n<$num_services; $n++) {
		$ds_services_in[$n] = "DS:$services[$n]_IN:COUNTER:600:0:U";
		$ds_services_out[$n] = "DS:$services[$n]_OUT:COUNTER:600:0:U";
	}
	for($n=0; $n<$num_networks; $n++) {
		$ds_networks_in[$n] = "DS:$networks[$n]_IN:COUNTER:600:0:U";
		$ds_networks_out[$n] = "DS:$networks[$n]_OUT:COUNTER:600:0:U";
	}
	
	if(!(-e $FILE_RRD)) {
		RRDs::create($FILE_RRD,
			"--start=now", 
			@ds_services_in,
			@ds_services_out,
			@ds_networks_in,
			@ds_networks_out,
			"RRA:AVERAGE:0.5:1:288",
			"RRA:AVERAGE:0.5:6:336",
			"RRA:AVERAGE:0.5:12:744",
			"RRA:AVERAGE:0.5:288:365",
			"RRA:MAX:0.5:1:288",
			"RRA:MAX:0.5:6:336",
			"RRA:MAX:0.5:12:744",
			"RRA:MAX:0.5:288:365",
			"RRA:LAST:0.5:1:288",
			"RRA:LAST:0.5:6:336",
			"RRA:LAST:0.5:12:744",
			"RRA:LAST:0.5:288:365");
		my $err = RRDs::error;
		die("ERROR: while creating $FILE_RRD: $err\n") if $err;
	}
}

# ==================================================
# 			UPDATE OPTION
# ==================================================

sub update {
	sleep($TIME_SLEEP);

	my $rrdata = "N";
	my @services_data;
	my @networks_data;

	my $n = 0;
	for($n=0; $n<2*$num_services; $n++) {
		$services_data[$n] = 0;
	}
	for($n=0; $n<2*$num_networks; $n++) {
		$networks_data[$n] = 0;
	}

	my $line = "";
	$n = 0;
	open(FILE_LOG) or die("ERROR: Could not open log file.");
	foreach $line (<FILE_LOG>) {
		my @temp = split(' ', $line);
		chomp(@temp);	
		if ($n<$num_services+$num_networks) {		
			if ($n<$num_services) {
				if (@temp) {
					$services_data[$n*2] = $temp[1];
					$services_data[$n*2+1] = $temp[2];
					$n++;
				}
			} else {
				if (@temp) {
					$networks_data[($n-$num_services)*2] = $temp[1];
					$networks_data[($n-$num_services)*2+1] = $temp[2];
					$n++;
				}
			}  
		}
	}
	close(FILE_LOG);

	# add1 for error read log file
	if ($n == 0) {
		print "re-read\n";
		sleep(1);
		$TIME_SLEEP = 299;
		open(FILE_LOG) or die("ERROR: Could not open log file.");
		foreach $line (<FILE_LOG>) {
			my @temp = split(' ', $line);
			chomp(@temp);
			if ($n<$num_services+$num_networks) {			
				if ($n<$num_services) {
					if (@temp) {
						$services_data[$n*2] = $temp[1];
						$services_data[$n*2+1] = $temp[2];
						$n++;
					}
				} else {
					if (@temp) {
						$networks_data[$n*2] = $temp[1];
						$networks_data[$n*2+1] = $temp[2];
						$n++;
					}
				}  
			}
		}
		close(FILE_LOG);
	} else { $TIME_SLEEP = 300; }
	# end add1
	
	# in services
	for ($n=0; $n<$num_services; $n++) {
		my $temp = $services_data[$n*2];
		$rrdata .= ":$temp";
	}
	# out services
	for ($n=0; $n<$num_services; $n++) {
		my $temp = $services_data[$n*2+1];
		$rrdata .= ":$temp";
	}
	# in networks
	for ($n=0; $n<$num_networks; $n++) {
		my $temp = $networks_data[$n*2];
		$rrdata .= ":$temp";
	}
	# out networks
	for ($n=0; $n<$num_networks; $n++) {
		my $temp = $networks_data[$n*2+1];
		$rrdata .= ":$temp";	
	}
	
	print $rrdata ."\n";
	RRDs::update($FILE_RRD, $rrdata);
	my $err = RRDs::error;
	die("ERROR: while updating $FILE_RRD: $err\n") if $err;
}

# ==================================================
# 			GRAPH OPTION
# ==================================================

sub graph {	
	our %BLACK = ("canvas" => "#000000",
		"back" => "#101010",
		"font" => "#C0C0C0",
		"mgrid" => "#80C080",
		"grid" => "#808020",
		"frame" => "#808080",
		"arrow" => "#FFFFFF",
		"shadea" => "#404040",
		"shadeb" => "#404040" );

	my @VERSION12;
	if($RRDs::VERSION > 1.2) {
		$VERSION12[0] = "--font=LEGEND:7:";
		$VERSION12[1] = "--font=TITLE:9:";
		$VERSION12[2] = "--slope-mode";
	} else {
		undef(@VERSION12);
	}

	my @graph_colors;
	$graph_colors[0] = "--color=CANVAS" . $BLACK{canvas};
	$graph_colors[1] = "--color=BACK" . $BLACK{back};
	$graph_colors[2] = "--color=FONT" . $BLACK{font};
	$graph_colors[3] = "--color=MGRID" . $BLACK{mgrid};
	$graph_colors[4] = "--color=GRID" . $BLACK{grid};
	$graph_colors[5] = "--color=FRAME" . $BLACK{frame};
	$graph_colors[6] = "--color=ARROW" . $BLACK{arrow};
	$graph_colors[7] = "--color=SHADEA" . $BLACK{shadea};
	$graph_colors[8] = "--color=SHADEB" . $BLACK{shadeb};

	my $GRAPH = "/var/www/monitorS/imgs/demo.png";
	my @DEF;
	my $i;
	for ($i=0; $i<$num_services; $i++) {
		$DEF[$i*2] = "DEF:".$services[$i]."_in=$FILE_RRD:".$services[$i]."_IN:AVERAGE";
		$DEF[$i*2+1] = "DEF:".$services[$i]."_out=$FILE_RRD:".$services[$i]."_OUT:AVERAGE";
	}
	my @CDEF;
	for ($i=0; $i<$num_services; $i++) {
		$CDEF[$i] = "CDEF:c_".$services[$i]."=".$services[$i]."_in,".$services[$i]."_out,+";
	}
	my @COLORDRAW;
	$COLORDRAW[0] = "#44EE44";
	$COLORDRAW[1] = "#4444EE";
	$COLORDRAW[2] = "#EE4444";
	$COLORDRAW[3] = "#444444";
	$COLORDRAW[4] = "#EE44EE";
	
	my @AREA;
	for ($i=0; $i<$num_services; $i++) {
		$AREA[$i] = "AREA:c_".$services[$i].$COLORDRAW[$i].":".$services[$i];
	}	
#	print @DEF;
#	print @CDEF;
#	print @AREA;
#	print "\n";
	
	RRDs::graph("$GRAPH",
		"--title=Networks (in + out)",
		"-s -2h5min",
		"-e -5min",
		"--imgformat=PNG",
		"--vertical-label=bytes/secs",
		"--width=450",
		"--height=150",
		"--upper-limit=500000",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@graph_colors,
		@DEF,
		@CDEF,
		@AREA,
#		"LINE1:tcp#00EE00",
#		"LINE1:B_out#0000EE",
#		"COMMENT:\\n",
#		"COMMENT:\\n",
#		"GPRINT:K_in:LAST:KB/s Input       Current\\: %5.0lf",
#		"GPRINT:K_in:AVERAGE:    Average\\: %5.0lf",
#		"GPRINT:K_in:MIN:    Min\\: %5.0lf",
#		"GPRINT:K_in:MAX:    Max\\: %5.0lf\\n",
#		"GPRINT:K_out:LAST:KB/s Output      Current\\: %5.0lf",
#		"GPRINT:K_out:AVERAGE:    Average\\: %5.0lf",
#		"GPRINT:K_out:MIN:    Min\\: %5.0lf",
#		"GPRINT:K_out:MAX:    Max\\: %5.0lf\\n",
		"COMMENT:\\n");
	my $err = RRDs::error;
	die("ERROR: while creating $GRAPH: $err\n") if $err;
}

