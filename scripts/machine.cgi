#!/usr/bin/perl -w

use POSIX qw(uname);
my $VERSION = "1.0";
my $host = (POSIX::uname())[1];
our $FILE_LOG="/var/log/monitorS.log";		# log file of program
my $a=0;
my $b=0;
my $v=0;

# read logfile
my $line = "";
$n = 0;
open(FILE_LOG) or die("ERROR: Could not open log file.");
foreach $line (<FILE_LOG>) {
	my @temp = split(' ', $line);
	chomp(@temp);		
	if ($n < 3) {
		$n++;
	} else {
		$a = $temp[0];
		$b = $temp[1];
		$v = $temp[2];
	}
}
close(FILE_LOG);

sub print_html()
{
	print "Content-Type: text/html\n\n";
	print <<HEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>TPE NGO Quang Minh - $host</title>
<meta http-equiv="Pragma" content="no-cache" />
</head>
<body>
HEADER

	print "<h1>Machine's informations</h1>\n";
	print "Address : 192.168.$a.$b<br \>\n";
	print "Volume of packets : $v bytes";
	
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

print_html;