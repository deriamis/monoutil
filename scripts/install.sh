#!/bin/sh
#
# Install shell-script for MonitorS
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
		echo "This install script has detected that this is a $OS operating system."
		SBIN="/usr/local/sbin"
		ETC="/usr/local/etc"
		INIT="/etc/init.d"
		LIB="/usr/local/lib"
		DOC="/usr/local/share/doc"
		HTDOCS="/var/www"
		CGIBIN="/usr/lib/cgi-bin"
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
echo "Last chance to stop the installation."
OK=0
while [ $OK -eq 0 ] ; do
	echo -n "Are you sure to install MonitorS on the paths shown? [y/n]: "
	read sure
	case $sure in
		[nN])
			echo
			echo "Aborting installation."
			exit 1
			;;

		[yY])
			echo
			echo "Starting installation."
			OK=1
			;;

		*)
			;;
	esac
done

echo "Copying config file to $ETC directory"
echo "services.conf & networks.conf"
cp *.conf $ETC
chmod 755 $ETC/services.conf
chmod 755 $ETC/networks.conf
echo

echo "Copying updater script, packet_egine to $SBIN directory"
echo "monitorS.pl"
cp monitorS.pl $SBIN
echo "packet_engine"
cp ../packet_engine $SBIN
echo

echo "Copying init script to $INIT directory"
echo "monitorS.sh"
cp monitorS.sh $INIT/monitorS.sh
echo

echo "Copying html files to $HTDOCS directory"
mkdir -p $HTDOCS/monitorS/imgs
chmod 777 $HTDOCS/monitorS/imgs
echo

echo "Copying cgi-bin files to $CGIBIN directory"
ls *.cgi
ln -s $CGIBIN $HTDOCS/monitorS/cgi-bin
cp *.cgi $CGIBIN
chmod 755 $CGIBIN/monitorS.cgi
chmod 755 $CGIBIN/machine.cgi
chmod 755 $CGIBIN/monitorS_in.cgi
chmod 755 $CGIBIN/monitorS_out.cgi
echo

echo "---------------------------------------------------------------------"
echo
echo "Installation succesfully finished."
echo
echo "You can start MonitorS executing the init script:"
echo
echo "$INIT/monitorS.sh [start|stop|status|restart]"
echo
echo "and finally go to http://localhost/monitorS/ to start to see results."
echo

exit 0

