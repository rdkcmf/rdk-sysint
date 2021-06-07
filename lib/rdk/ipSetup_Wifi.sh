#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################


. /etc/include.properties

logsFile=$LOG_PATH/ipSetupLogs.txt
fileName=`basename $0`

if [ -f $PERSISTENT_PATH/moca_interface ] ; then
    interface=`cat $PERSISTENT_PATH/moca_interface`
    echo "`/bin/timestamp` $fileName:$LINENO :   interface = $interface  override in /opt  " >> $logsFile
else
    interface=ra0
    echo "`/bin/timestamp` $fileName:$LINENO :   interface = $interface  default " >> $logsFile
fi

getIP()
{
	echo `ifconfig $interface | grep inet | tr -s " " | cut -d ":" -f2 | cut -d " " -f1 `
}

ifaceUP()
{
	#interface=$1
	echo "`/bin/timestamp` $fileName:$LINENO : ifaceUP : interface = $interface  " >> $logsFile
	inter=`/sbin/ifconfig | grep $interface | awk '{print $1}'`
	if [ -z $inter ]; then
		ifconfig $interface 0.0.0.0 up
		echo "`/bin/timestamp` $fileName:$LINENO : ifaceUP : bringing $interface UP " >> $logsFile
	else
		echo "`/bin/timestamp`  ifaceUP : $interface is already up " >> $logsFile
	fi
}


getDHCPIp()
{
	#interface=$1
	echo "`/bin/timestamp` $fileName:$LINENO : getDHCPIp : interface = $interface  " >> $logsFile
	udhcpc -i $interface -p /tmp/udhcpc.$interface.pid >& /dev/null &
	sleep 20
	dhcpIP=`getIP`
	ipTrunc=`echo $dhcpIP | cut -d "." -f1-2 `
        if [ "$ipTrunc" = "169.254" ]; then
                echo "`/bin/timestamp` $fileName:$LINENO : getDHCPIp : dhcp didnt return an ip,the interface has the previous auto ip so emptying the ip string  " >> $logsFile
                dhcpIP=""
        fi
	echo "`/bin/timestamp` $fileName:$LINENO : getDHCPIp : dhcpIP = $dhcpIP  " >> $logsFile
	echo $dhcpIP
}



stopDHCP()
{
	echo "`/bin/timestamp` $fileName:$LINENO : stopDHCP : interface = $interface  " >> $logsFile
	#interface=$1
#	pidfile=/tmp/udhcpc.$interface.pid
#	if [ -e $pidfile ]; then
#		kill `cat $pidfile` 2> /dev/null
#		rm -f $pidfile
#	fi
#	ifconfig $interface:0 0.0.0.0 2> /dev/null
	pid=`ps -fe | grep 'udhcp' | grep eth1 | grep -v grep | awk '{print $2}'`
	kill -9 $pid 2> /dev/null
}


getAutoIp()
{
	#interface=$1
	echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : interface = $interface  " >> $logsFile
	autoIP=`getIP`
	autoIPTrunc=`echo $autoIP | cut -d "." -f1-2 `
	if [ "$autoIPTrunc" = "169.254" ]; then
		echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : Already having auto-ip so no zcip required  " >> $logsFile
	else
		busybox zcip $interface /etc/zcip.script
		sleep 20
		autoIP=`getIP`
		echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : autoIP = $autoIP  " >> $logsFile
		echo $autoIP
	fi
}

stopAutoIp()
{
	echo "`/bin/timestamp` $fileName:$LINENO : stopAutoIp : interface = $interface  " >> $logsFile
	#killall zcip 2> /dev/null
	pid=`ps -fe | grep 'zcip' | grep -v grep | awk '{print $2}'`
	kill -9 $pid 2> /dev/null
	# interface still will hold the ip but just to save 20 sec next time when getAutoIP is called we are not bringing down the interface
}

startUPNP()
{
	echo "`/bin/timestamp` $fileName:$LINENO : startUPNP : interface = $interface  " >> $logsFile	
	sh $RDK_PATH/start_b_upnp.sh
	sleep 10
}

checkUPNP()
{
	echo "`/bin/timestamp` $fileName:$LINENO : checkUPNP : interface = $interface  " >> $logsFile
	if [ -f  $PERSISTENT_PATH/output.json ]; then
		echo "`/bin/timestamp` $fileName:$LINENO : checkUPNP : UPNP Device success  " >> $logsFile
		echo 1
	else
		echo "`/bin/timestamp` $fileName:$LINENO : checkUPNP : UPNP Device fail  " >> $logsFile
		echo 0
	fi
}

setAutoIPMode()
{
	echo "`/bin/timestamp` $fileName:$LINENO : setAutoIPMode  " >> $logsFile
	getAutoIp
	startUPNP
	sleep 5
}

setDHCPIPMode()
{
	echo "`/bin/timestamp` $fileName:$LINENO : setDHCPIPMode  " >> $logsFile
	dhcpIP=`getDHCPIp`
	if [ $dhcpIP != "" ]; then
		startUPNP
		sleep 5
		echo 1
	else
		echo 0
	fi
}
#############################################################################################

############################################################################################

ifaceUP
		echo "`/bin/timestamp` $fileName:$LINENO : get  Auto IP " >> $logsFile
		while (true);
		do
			setAutoIPMode
			echo "`/bin/timestamp` $fileName:$LINENO : Finding UPNP Device with Auto IP " >> $logsFile
			if [ `checkUPNP` -eq  1  ]; then
				echo "`/bin/timestamp` $fileName:$LINENO : UPNP Device found with Auto IP " >> $logsFile
				stopAutoIp
				sh $RDK_PATH/gwSetup.sh
				touch $PERSISTENT_PATH/ipMode.config
				echo "AUTO" > $PERSISTENT_PATH/ipMode.config
				sleep 5
				exit 0
			fi
			stopAutoIp
			sleep 5
		done


	

