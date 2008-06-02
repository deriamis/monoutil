#!/usr/bin/perl -w

use RRDs;
use POSIX qw(uname);

my $VERSION = "1.0";
my $host = (POSIX::uname())[1];
my @graphs = (
	{ title => 'Lash Hour',	 seconds => 3600,	},
	{ title => 'Last Day',   seconds => 3600*24,    },
	{ title => 'Last Week',  seconds => 3600*24*7,	},
	{ title => 'Last Month', seconds => 3600*24*31, },
	{ title => 'Last Year',  seconds => 3600*24*365, },
);
my $scriptname = 'monitorS.cgi';				# name of script CGI
my $FILE_RRD = "/var/lib/monitorS.rrd"; 				# path to where the RRD database is
our $FILE_CONFIG_SERVICES="/etc/services.conf"; 			# config file
our $FILE_CONFIG_NETWORKS="/etc/networks.conf";			# config file
my $base_dir = "/var/www/monitorS";				# directory of website

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

sub graph_services ($$) {	
	my %BLACK = ("canvas" => "#000000",
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

	my ($time, $GRAPH) = @_;
	$time = $time - 300;
	my @DEF;
	my $i;
	for ($i=0; $i<$num_services; $i++) {
		$DEF[$i*2] = "DEF:$services[$i]_in=$FILE_RRD:$services[$i]_IN:AVERAGE";
		$DEF[$i*2+1] = "DEF:$services[$i]_out=$FILE_RRD:$services[$i]_OUT:AVERAGE";
	}
	my @CDEF;
	for ($i=0; $i<$num_services; $i++) {
		$CDEF[$i] = "CDEF:c_$services[$i]=$services[$i]_in,$services[$i]_out,+";
	}
	my @COLORDRAW;
	$COLORDRAW[0] = "44EE44";
	$COLORDRAW[1] = "4444EE";
	$COLORDRAW[2] = "EE4444";
	$COLORDRAW[3] = "444444";
	$COLORDRAW[4] = "EE44EE";
	
	my @AREA;
	for ($i=0; $i<$num_services; $i++) {
		$AREA[$i] = "AREA:c_$services[$i]#$COLORDRAW[$i]:$services[$i]";
	}
	
	RRDs::graph("$GRAPH",
		"--title=Services (in + out)",
		"-s -".$time,
		"-e -5min",
		"--imgformat=PNG",
		"--vertical-label=bytes/secs",
		"--width=450",
		"--height=150",
		"--upper-limit=200000",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@graph_colors,
		@DEF,
		@CDEF,
		@AREA,
		"COMMENT:\\n");
	my $err = RRDs::error;
	die("ERROR: while creating $GRAPH: $err\n") if $err;
}

sub graph_networks ($$) {	
	my %BLACK = ("canvas" => "#000000",
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

	my ($time, $GRAPH) = @_;
	$time = $time - 300;
	my @DEF;
	my $i;
	for ($i=0; $i<$num_networks; $i++) {
		$DEF[$i*2] = "DEF:$networks[$i]_in=$FILE_RRD:$networks[$i]_IN:AVERAGE";
		$DEF[$i*2+1] = "DEF:$networks[$i]_out=$FILE_RRD:$networks[$i]_OUT:AVERAGE";
	}
	my @CDEF;
	for ($i=0; $i<$num_networks; $i++) {
		$CDEF[$i] = "CDEF:c_$networks[$i]=$networks[$i]_in,$networks[$i]_out,+";
	}
	my @COLORDRAW;
	$COLORDRAW[0] = "44EE44";
	$COLORDRAW[1] = "4444EE";
	$COLORDRAW[2] = "EE4444";
	$COLORDRAW[3] = "444444";
	$COLORDRAW[4] = "EE44EE";
	
	my @AREA;
	for ($i=0; $i<$num_networks; $i++) {
		$AREA[$i] = "AREA:c_$networks[$i]#$COLORDRAW[$i]:$networks[$i]";
	}
	
	RRDs::graph("$GRAPH",
		"--title=Networks (in + out)",
		"-s -".$time,
		"-e -5min",
		"--imgformat=PNG",
		"--vertical-label=bytes/secs",
		"--width=450",
		"--height=150",
		"--upper-limit=200000",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@graph_colors,
		@DEF,
		@CDEF,
		@AREA,
		"COMMENT:\\n");
	my $err = RRDs::error;
	die("ERROR: while creating $GRAPH: $err\n") if $err;
}

sub print_html()
{
	print "Content-Type: text/html\n\n";
	print <<HEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>TPE NGO Quang Minh - $host</title>
<meta http-equiv="Refresh" content="300" />
<meta http-equiv="Pragma" content="no-cache" />
</head>
<body>
HEADER

	print "<h1>Statistics for $host</h1>\n";
	print "<ul id=\"services\">\n";
	for my $n (0..$#graphs) {
		print "  <li><a href=\"#S$n\">$graphs[$n]{title}</a>&nbsp;</li>\n";
	}
	print "</ul>\n";

	for my $n (0..$#graphs) {
		print "<h2 id=\"S$n\">$graphs[$n]{title}</h2>\n";
		# for services
		print "<MAP NAME=map_s$n>";
#		print "<AREA HREF=\"test\" ALT=\"test_alt\" SHAPE=RECT COORDS=\"5,5,95,195\">";
#		print "<AREA HREF=\"test\" ALT=\"test_alt\" COORDS=\"105,5,195,195\">";
		print "<AREA HREF=\"test\" ALT=\"test_alt\" COORDS=\"68,33,517,185\">";
		print "</MAP>";
		# for networks
		print "<MAP NAME=map_n$n>";
		print "<AREA HREF=\"test\" ALT=\"test_alt\" COORDS=\"68,33,517,185\">";
		print "</MAP>";
		print "<img border=0 src=\"$scriptname?${n}-s\" alt=\"monitorS\" usemap=\"#map_s$n\"/> ";
		print "<img border=0 src=\"$scriptname?${n}-n\" alt=\"monitorS\" usemap=\"#map_n$n\"/><br/>";
		print "\n";
	}

#	print "<hr />";
#	print "<h1>TCP/UDP services monitoring for $host</h1>\n";
#	print "<ul id=\"services\">\n";
#	for my $n (0..$#services) {
#		print "  <li><a href=\"#S$n\">$services[$n]</a>&nbsp;</li>\n";
#	}
#	print "</ul>\n";
#
#	for my $n (0..$#services) {
#		print "<h2 id=\"S$n\">$services[$n]</h2>\n";
#		print "<p><img src=\"$scriptname?${n}-s\" alt=\"$services[$n]\"/><br/>\n";
#	}
#
	print <<FOOTER;
<hr/>
<table><tr>
	<td>
		<a href="https://www.ifi.auf.org">IFI/AUF</a> MonitorS $VERSION by 
		<a href="mailto:nqminh\@ifi.edu.vn">NGO Quang Minh</a>
	</td>
	<td align="right">
		<a href="http://oss.oetiker.ch/rrdtool/"><img src="http://oss.oetiker.ch/rrdtool/.pics/rrdtool.gif" alt="RRDTool" width="120" height="34"/></a>
	</td>
</tr></table>
</body></html>
FOOTER
}

# send image created to server 
sub send_image($)
{
	my ($file)= @_;

	-r $file or do {
		print "Content-type: text/plain\n\nERROR: can't find $file\n";
		exit 1;
	};

	print "Content-type: image/png\n";
	print "Content-length: ".((stat($file))[7])."\n";
	print "\n";
	open(IMG, $file) or die;
	my $data;
	print $data while read(IMG, $data, 16384)>0;
}

sub main()
{
	my $uri = $ENV{REQUEST_URI} || '';
	my $img = $ENV{QUERY_STRING};
	if(defined $img and $img =~ /\S/) {
		if($img =~ /^(\d+)-s$/) {
			my $file = "$base_dir\/imgs\/services_$1.png";
			graph_services($graphs[$1]{seconds}, $file);
			send_image($file);
		} elsif($img =~ /^(\d+)-n$/) {
			my $file = "$base_dir\/imgs\/networks_$1.png";
			graph_networks($graphs[$1]{seconds}, $file);
			send_image($file);
		}
		else {
			die "ERROR: invalid argument\n";
		}
	}
	else {
		print_html();
	}
}

main;