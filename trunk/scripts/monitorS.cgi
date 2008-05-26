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
my $rrd = "/var/lib/monitorS.rrd"; 				# path to where the RRD database is
my $config_file = "/etc/packet_engine.conf";	# path to config file
my $base_dir = "/var/www/monitorS";			# directory of website

my @services;
my $num_services=0;

# read config
open (CONFIG,"$config_file") || die "  Error opening log file $config_file.\n";
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

sub graph ($$) {	
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
	$DEF[0] = "DEF:icmp_in=$rrd:ICMP_IN:AVERAGE";
	$DEF[1] = "DEF:tcp_in=$rrd:TCP_IN:AVERAGE";
	$DEF[2] = "DEF:udp_in=$rrd:UDP_IN:AVERAGE";
	$DEF[3] = "DEF:esp_in=$rrd:ESP_IN:AVERAGE";
	$DEF[4] = "DEF:other_in=$rrd:OTHER_IN:AVERAGE";
	$DEF[5] = "DEF:icmp_out=$rrd:ICMP_OUT:AVERAGE";
	$DEF[6] = "DEF:tcp_out=$rrd:TCP_OUT:AVERAGE";
	$DEF[7] = "DEF:udp_out=$rrd:UDP_OUT:AVERAGE";
	$DEF[8] = "DEF:esp_out=$rrd:ESP_OUT:AVERAGE";
	$DEF[9] = "DEF:other_out=$rrd:OTHER_OUT:AVERAGE";
	RRDs::graph("$GRAPH",
		"--title=IP Protocols (in + out)",
		"-s -".$time,
		"-e -5min",
		"--imgformat=PNG",
		"--vertical-label=packets/300secs",
		"--width=450",
		"--height=150",
		"--upper-limit=100000",
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
		"COMMENT:\\n");
	my $err = RRDs::error;
	die("ERROR: while creating $GRAPH: $err\n") if $err;
}

sub graph_services ($$$) {	
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

	my ($service_name, $GRAPH, $in_out) = @_;
#	$time = $time - 300;
	my $time = 6900; # test voi 2 tieng
	my @DEF;
	$DEF[0] = "DEF:d_in$service_name=$rrd:$service_name"."_IN:AVERAGE";
	$DEF[1] = "DEF:d_out$service_name=$rrd:$service_name"."_OUT:AVERAGE";
	RRDs::graph("$GRAPH",
		"--title=Service $service_name $in_out",
		"-s -".$time,
		"-e -5min",
		"--imgformat=PNG",
		"--vertical-label=packets/300secs",
		"--width=450",
		"--height=150",
		"--upper-limit=100000",
		"--lower-limit=0",
		"--rigid",
		@VERSION12,
		@graph_colors,
		@DEF,
		"CDEF:cd_in$service_name=d_in$service_name,300,*",
		"CDEF:cd_out$service_name=d_out$service_name,300,*",
		"AREA:cd_in$service_name#4444EE:$service_name"." in",
		"LINE1:cd_out$service_name#EE4444:$service_name"." out",
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
<link rel="stylesheet" href="monitorS.css" type="text/css" />
</head>
<body>
HEADER

	print "<h1>IP protocols monitoring for $host</h1>\n";
	print "<ul id=\"protocols\">\n";
	for my $n (0..$#graphs) {
		print "  <li><a href=\"#G$n\">$graphs[$n]{title}</a>&nbsp;</li>\n";
	}
	print "</ul>\n";

	for my $n (0..$#graphs) {
		print "<h2 id=\"G$n\">$graphs[$n]{title}</h2>\n";
		print "<MAP NAME=map$n>";
		print "<AREA HREF=\"test\" ALT=\"test_alt\" SHAPE=RECT COORDS=\"5,5,95,195\">";
#		print "<AREA HREF=\"test\" ALT=\"test_alt\" COORDS=\"105,5,195,195\">";
#		print "<AREA HREF=\"test\" ALT=\"test_alt\" COORDS=\"205,5,295,195\">";
		print "</MAP>";
		print "<p><img src=\"$scriptname?${n}-p\" alt=\"monitorS\" usemap=\"#map$n\" width=\"450\" height=\"150\"/><br/>\n";
	}

	print "<hr />";
	print "<h1>TCP/UDP services monitoring for $host</h1>\n";
	print "<ul id=\"services\">\n";
	for my $n (0..$#services) {
		print "  <li><a href=\"#S$n\">$services[$n]</a>&nbsp;</li>\n";
	}
	print "</ul>\n";

	for my $n (0..$#services) {
		print "<h2 id=\"S$n\">$services[$n]</h2>\n";
		print "<p><img src=\"$scriptname?${n}-s\" alt=\"$services[$n]\"/><br/>\n";
	}

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
#	$uri =~ s/\/[^\/]+$//;
#	$uri =~ s/\///g;
#	$uri =~ s/(\~|\%7E)/tilde,/g;
#	mkdir $tmp_dir, 0777 unless -d $tmp_dir;
#	mkdir "$tmp_dir/$uri", 0777 unless -d "$tmp_dir/$uri";
	my $img = $ENV{QUERY_STRING};
	if(defined $img and $img =~ /\S/) {
		if($img =~ /^(\d+)-p$/) {
			my $file = "$base_dir\/imgs\/protocol_$1.png";
			graph($graphs[$1]{seconds}, $file);
			send_image($file);
		} elsif($img =~ /^(\d+)-s$/) {
			my $file = "$base_dir\/imgs\/service_$services[$1].png";
			graph_services($services[$1],$file, "in/out");
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
