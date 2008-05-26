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
our	$FILE_RRD="/var/lib/monitorS.rrd";		# directory of files RRD
our $FILE_LOG="/var/log/monitorS.log";		# log file of program
our $FILE_CONFIG="/etc/packet_engine.conf"; # config file
my @services;
my $num_services=0;
my $TIME_SLEEP = 300;						# 5 minutes

# read config
open (CONFIG,"$FILE_CONFIG") || die "  Error opening log file $FILE_CONFIG.\n";
while(<CONFIG>) {
	if (! /#/ && /,/) {
		my $port = 0;
		my $sname = "";
		($port, $sname) = split(',');
		chomp($sname, $port);
		$services[$num_services] = $sname;
		$num_services++;
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
	my $O_INDEX = "/var/www/monitorS/index.html.tmp";
	my $crontabuser = "root";

	open(OCRON, "> $O_CRON");
	print OCRON <<EOF;

#!/bin/sh
#
PATH=/sbin:/bin:/usr/sbin:/usr/bin

* * * * * $crontabuser /usr/bin/monitorS.pl update >/dev/null 2>&1

EOF
	close(OCRON);

	open(OHTML, "> $O_INDEX");
	print OHTML <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
	<head>
		<title>TPE - IFI</title>
 	</head>
 	<body bgcolor="#000000" text="#FFFFFF">
  	<center><font face="Verdana, Tahoma, sans-serif">
		<h1 align="center">MonitorS v$MONITORS_VER</h1>
		<font color=888888>started on $IDATE<hr><br></font>
    	<p><!MARK 1></p>
		<p><!MARK 2></p>
  	</font></center>
 	</body>
</html>
EOF
	close(OHTML);
	my $I_INDEX="/var/www/monitorS/index.html.tmp";
	$O_INDEX="/var/www/monitorS/index.html";

	open(IHTML, "< $I_INDEX");
	open(OHTML, "> $O_INDEX");
	while(<IHTML>) {
		if(/<!MARK 1/) {
			print OHTML "<img src=\"./imgs/test.png\" />";
			next;
		}
		if(/<!MARK 2/) {
			print OHTML "<img src=\"./imgs/test.png\" />";
			next;
		}
		print OHTML $_;
	}
	close(IHTML);
	close(OHTML);
	unlink($I_INDEX);
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
	my $n = 0;
	for($n=0; $n<$num_services; $n++) {
		$ds_services_in[$n] = "DS:$services[$n]_IN:COUNTER:600:0:U";
		$ds_services_out[$n] = "DS:$services[$n]_OUT:COUNTER:600:0:U";
	}
	if(!(-e $FILE_RRD)) {
		RRDs::create($FILE_RRD,
			"--start=now", 
			"DS:ICMP_IN:COUNTER:600:0:U",
			"DS:ICMP_OUT:COUNTER:600:0:U",
			"DS:TCP_IN:COUNTER:600:0:U",
			"DS:TCP_OUT:COUNTER:600:0:U",
			"DS:UDP_IN:COUNTER:600:0:U",
			"DS:UDP_OUT:COUNTER:600:0:U",
			"DS:ESP_IN:COUNTER:600:0:U",
			"DS:ESP_OUT:COUNTER:600:0:U",
			"DS:OTHER_IN:COUNTER:600:0:U",
			"DS:OTHER_OUT:COUNTER:600:0:U",
			@ds_services_in,
			@ds_services_out,
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

	my $s_icmp = "";
	my $icmp_in = 0;
	my $icmp_out = 0;
	my $s_tcp = "";
	my $tcp_in = 0;
	my $tcp_out = 0;
	my $s_udp = "";
	my $udp_in = 0;
	my $udp_out = 0;
	my $s_esp = "";
	my $esp_in = 0;
	my $esp_out = 0;
	my $s_other = "";
	my $other_in = 0;
	my $other_out = 0;
	my $rrdata = "N";
	my @services_data;

	my $n = 0;
	for($n=0; $n<3*$num_services; $n++) {
		$services_data[$n] = " ";
	}

	my $line = "";
	open(FILE_LOG) or die("ERROR: Could not open log file.");
	foreach $line (<FILE_LOG>) {
		($s_icmp, $icmp_in, $icmp_out, $s_tcp, $tcp_in, $tcp_out, $s_udp, $udp_in, $udp_out, $s_esp, $esp_in, $esp_out, $s_other, $other_in, $other_out, @services_data) = split(' ', $line);
	}
	close(FILE_LOG);
	chomp($s_icmp, $icmp_in, $icmp_out, $s_tcp, $tcp_in, $tcp_out, $s_udp, $udp_in, $udp_out, $s_esp, $esp_in, $esp_out, $s_other, $other_in, $other_out, @services_data);

	# add1 for error read log file
	if (!length($s_icmp) eq "icmp") {
		print "re-read\n";
		sleep(1);
		$TIME_SLEEP = 299;
		open(FILE_LOG) or die("ERROR: Could not open log file.");
		foreach $line (<FILE_LOG>) {
			($s_icmp, $icmp_in, $icmp_out, $s_tcp, $tcp_in, $tcp_out, $s_udp, $udp_in, $udp_out, $s_esp, $esp_in, $esp_out, $s_other, $other_in, $other_out, @services_data) = split(' ', $line);
		}
		close(FILE_LOG);
		chomp($s_icmp, $icmp_in, $icmp_out, $s_tcp, $tcp_in, $tcp_out, $s_udp, $udp_in, $udp_out, $s_esp, $esp_in, $esp_out, $s_other, $other_in, $other_out, @services_data);
	} else { $TIME_SLEEP = 300; }
	# end add1

	$rrdata .= ":$icmp_in:$icmp_out:$tcp_in:$tcp_out:$udp_in:$udp_out:$esp_in:$esp_out:$other_in:$other_out";
	
	my $temp = 0;
	for ($n=0; $n<$num_services; $n++) {
		$temp = $services_data[3*$n+1];
		$rrdata .= ":$temp";
	}
	for ($n=0; $n<$num_services; $n++) {
		$temp = $services_data[3*$n+2];
		$rrdata .= ":$temp";
	}
#	print $rrdata ."\n";
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
	$DEF[0] = "DEF:icmp_in=$FILE_RRD:ICMP_IN:AVERAGE";
	$DEF[1] = "DEF:tcp_in=$FILE_RRD:TCP_IN:AVERAGE";
	$DEF[2] = "DEF:udp_in=$FILE_RRD:UDP_IN:AVERAGE";
	$DEF[3] = "DEF:esp_in=$FILE_RRD:ESP_IN:AVERAGE";
	$DEF[4] = "DEF:other_in=$FILE_RRD:OTHER_IN:AVERAGE";
	$DEF[5] = "DEF:icmp_out=$FILE_RRD:ICMP_OUT:AVERAGE";
	$DEF[6] = "DEF:tcp_out=$FILE_RRD:TCP_OUT:AVERAGE";
	$DEF[7] = "DEF:udp_out=$FILE_RRD:UDP_OUT:AVERAGE";
	$DEF[8] = "DEF:esp_out=$FILE_RRD:ESP_OUT:AVERAGE";
	$DEF[9] = "DEF:other_out=$FILE_RRD:OTHER_OUT:AVERAGE";
	RRDs::graph("$GRAPH",
		"--title=IP Protocols (in + out)",
		"-s -2h5min",
		"-e -5min",
#		"--start=1199493660",
#		"--end=1199497260",
#		"--start=-1month",
#		"--step=60",
		"--imgformat=PNG",
		"--vertical-label=packets/300secs",
		"--width=450",
		"--height=150",
		"--upper-limit=10000",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@graph_colors,
		@DEF,
		"CDEF:k_icmp=icmp_in,icmp_out,+,300,*",
		"CDEF:k_tcp=tcp_in,tcp_out,+,300,*",
		"CDEF:k_udp=udp_in,udp_out,+,300,*",
		"CDEF:k_esp=esp_in,esp_out,+,300,*",
		"CDEF:k_other=other_in,other_out,+,300,*",
		"AREA:k_icmp#44EE44:ICMP",
		"AREA:k_tcp#4444EE:TCP",
		"AREA:k_udp#EE4444:UDP",
		"AREA:k_esp#444444:ESP",
		"AREA:k_other#EE44EE:Other",
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

