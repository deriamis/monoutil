#!/bin/bash
#
# Starts MonitorS on Ubuntu
#

RETVAL=0
LOCK="/var/lock/monitorS"
PROGRAM="MonitorS"
COMMAND="/usr/local/sbin/monitorS.pl"

start() {
	# Check if monitorS is already running
	lockfile -1 -r1 $LOCK >/dev/null 2>&1
	RETVAL=$?
	echo -n $"Starting $PROGRAM: "
	if [ $? -gt 0 ]; then
		echo "Failed...this program is already running"
		echo
		return $RETVAL
	fi
	# Creates RRDs files (if needed)
	$COMMAND create
	if [ $? -gt 0 ]; then
		echo " ... Failed"
		echo
		return $RETVAL
	fi
	$COMMAND init
	if [ $? -eq 0 ]; then
		echo " ... Ok"
		echo
	else
		echo " ... Failed"
		echo
		return $RETVAL
	fi
}

stop() {
	if [ -e $LOCK ] ; then
		rm -f $LOCK
		$COMMAND stop
		echo -n $"Stopping $PROGRAM: "
	else
		echo
		echo "WARNING: You has selected to stop MonitorS AGAIN!"
		echo "WARNING: This may destroy all your IP counters!."
		echo
		echo "If you only want to upgrade a new version, while mantaining MonitorS up"
		echo "and running, simply type 'stop' and then 'start' or 'restart'."
		echo
		echo -n "Do you still want to continue? (N/y): "
		read option
		if [ "$option" != "Y" ] && [ "$option" != "y" ] ; then
			return 1
		fi
	fi
	echo
}

status() {
        if [ -e $LOCK ] ; then
                echo $"$PROGRAM is running."
        else
                echo $"$PROGRAM is stopped."
        fi
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	status)
		status
		;;
	restart)
		stop
		sleep 1
		start
		;;
	*)
		echo $"Usage: $0 {start|stop|status|restart}"
		exit 1
esac

exit $RETVAL

