#!/bin/sh
#
# Un-Install shell-script for MonitorS
#

show_paths() {
	echo
	echo "The following is a list of the default paths where to install the MonitorS"
	echo "components:"
	echo
	echo "	1 - $SBIN"
	echo "	2 - $ETC"
	echo "	3 - $INIT"
	echo "	4 - $LIB"
	echo "	5 - $DOC"
	echo "	6 - $HTDOCS"
	echo "	7 - $CGIBIN"
	echo
	echo -n "	Please type ENTER if all it's correct: "
	read path
}

OS=`uname -s`

echo
echo "Welcome to MonitorS installation process."
echo

case $OS in
	Linux)
		echo "This un-install script has detected that this is a $OS operating system."
		SBIN="/usr/local/sbin"
		ETC="/usr/local/etc"
		INIT="/etc/init.d"
		LIB="/usr/local/lib"
		DOC="/usr/share/doc"
		HTDOCS="/var/www"
		CGIBIN="/usr/local/lib/cgi-bin"
		PORTS="${OS}-Debian"
		show_paths
		;;
	*)
		echo
		echo "Sorry. Your operating system \"$OS\" is not supported right now."
		echo "Please contact to nqminh <nqminh@ifi.edu.vn> if you are interested"
		echo "to start the portability process together."
		echo
		exit 1
		;;
esac

echo
echo "Last chance to stop the un-installation."
OK=0
while [ $OK -eq 0 ] ; do
	echo -n "Are you sure to un-install MonitorS on the paths shown? [y/n]: "
	read sure
	case $sure in
		[nN])
			echo
			echo "Aborting un-installation."
			exit 1
			;;

		[yY])
			echo
			echo "Starting un-installation."
			OK=1
			;;

		*)
			;;
	esac
done

echo "Removing config file in $ETC directory"
echo "services.conf & networks.conf"
rm $ETC/networks.conf
rm $ETC/services.conf
echo

echo "Removing updater script in $SBIN directory"
echo "monitorS.pl"
rm $SBIN/monitorS.pl
echo

echo "Removing init script in $INIT directory"
echo "monitorS.sh"
rm $INIT/monitorS.sh
echo

echo "Removing html files in $HTDOCS directory"
rm -R $HTDOCS/monitorS
echo

echo "Removing cgi-bin files in $CGIBIN directory"
echo "monitorS.cgi"
rm $CGIBIN/monitorS.cgi
echo

echo "Removing RRD files in /var/lib directory"
echo "monitorS.rrd"
OK=0
while [ $OK -eq 0 ] ; do
	echo -n "Are you sure to remove? [y/n]: "
	read sure
	case $sure in
		[nN])
			echo
			OK=1
			;;

		[yY])
			echo
			rm /var/lib/monitorS.rrd
			echo
			OK=1
			;;

		*)
			;;
	esac
done

echo "---------------------------------------------------------------------"
echo
echo "Installation succesfully finished."
echo
exit 0

