#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
#

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh

logsFile=$LOG_PATH/ipSetupLogs.txt
upnpLogsFile=$LOG_PATH/xdiscovery.log
fileName=`basename $0`

interface=`getMoCAInterface`
wifi_interface=`getWiFiInterface`

getIP()
{
	echo `ifconfig $interface | grep inet | tr -s " " | cut -d ":" -f2 | cut -d " " -f1 `
}

ifaceUP()
{
	#interface=$1
	echo "`/bin/timestamp` $fileName:$LINENO : ifaceUP : interface = $interface  " >> $logsFile
	inter=`/sbin/ifconfig | grep $interface | awk '{print $1}'`
	if [ -z "$inter" ]; then
		ifconfig $interface 0.0.0.0 up
		echo "`/bin/timestamp` $fileName:$LINENO : ifaceUP : bringing $interface UP " >> $logsFile
	else
		echo "`/bin/timestamp`  ifaceUP : $interface is already up " >> $logsFile
	fi
}

getAutoIp()
{
	#interface=$1
	if [ "$1" != "" ]; then
		interface=$1
	fi
	echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : interface = $interface  " >> $logsFile
	if [ ! -f /etc/os-release ]; then
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
			/etc/init.d/dropbear-service stop
			/etc/init.d/dropbear-service start
		fi
	else
		autoIP=`getIP`
		autoIPTrunc=`echo $autoIP | cut -d "." -f1-2 `
		if [ "$autoIPTrunc" != "169.254" ]; then
			echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : Waiting for moca IP " >> $logsFile
		else
			echo "`/bin/timestamp` $fileName:$LINENO : getAutoIp : autoIP = $autoIP  " >> $logsFile
		fi
	fi
}

stopAutoIp()
{
	if [ "$1" != "" ]; then
              interface=$1
        fi
	echo "`/bin/timestamp` $fileName:$LINENO : stopAutoIp : interface = $interface  " >> $logsFile
	if [ ! -f /etc/os-release ]; then
		#killall zcip 2> /dev/null
		pid=`ps -fe | grep 'zcip' | grep -v grep | awk '{print $2}'`
		kill -9 $pid 2> /dev/null
		# interface still will hold the ip but just to save 20 sec next time when getAutoIP is called we are not bringing down the interface
	fi
}

startUPNP()
{
    if [ ! -f /tmp/upnp_started ]; then
        echo "`/bin/timestamp` $fileName:$LINENO : startUPNP : interface = $interface  " >> $logsFile
        if [ ! -f /etc/os-release ]; then
		funcUPNP
	fi
    fi
}

funcUPNP()
{
	touch /tmp/upnp_started
	rm $PERSISTENT_PATH/output.json
	sh $RDK_PATH/processPID.sh $RDK_PATH/start_upnp.sh | xargs kill -9	
	sh $RDK_PATH/start_upnp.sh $upnpLogsFile &
	sleep 5
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
	getAutoIp $1
	sleep 5
}

#############################################################################################

############################################################################################

ifaceUP

# In yocto we dont want all of these unneccesary steps as we already
# have systemd unit files doing the same job more efficiently.
if [ ! -f /etc/os-release ]; then
	if [ ! -f $PERSISTENT_PATH/no-upnp ] && [ "$KICKSTART" != "yes" ]; then
		ret=`checkWiFiModule`
		if [ $ret == 0 ]; then
			if [ -f /tmp/wifi-on ]; then
				echo "`/bin/timestamp` $fileName:$LINENO : Box is switching from WIFI to MoCA " >> $logsFile
				stopAutoIp
				setAutoIPMode
				funcUPNP
				touch /tmp/moca-on
				rm /tmp/wifi-on
			elif [ ! -f /tmp/moca-on ]; then
				touch /tmp/moca-on
				stopAutoIp
				setAutoIPMode
				startUPNP	
			else
				sleep 4	
			fi
		else
			if [ -f /tmp/moca-on ]; then
				stopAutoIp
				setAutoIPMode  $wifi_interface
				echo "`/bin/timestamp` $fileName:$LINENO : Box is switching from MoCA to WiFi " >> $logsFile
				funcUPNP
				rm /tmp/moca-on
			elif [ ! -f /tmp/wifi-on ]; then
				touch /tmp/wifi-on
				stopAutoIp
				setAutoIPMode $wifi_interface
				startUPNP
			else
				sleep 4	
			fi
		fi	
	else
		echo "`/bin/timestamp` $fileName:$LINENO : override no-upnp in opt so going for DHCP IP " >> $logsFile
		#getDHCPIp
		dhcpProcess=`ps -ef | grep udhcpc.$interface.pid | grep -v grep`
	        if [ "$dhcpProcess" = "" ]; then
        	        ifconfig $interface down
	                ifconfig $interface up
                	udhcpc -i $interface -p /tmp/udhcpc.$interface.pid >& /dev/null &
        	        sleep 25
	                /etc/init.d/dropbear-service stop
                	/etc/init.d/dropbear-service start
        	fi  
	fi
else
	stopAutoIp
	setAutoIPMode
	startUPNP	
fi	
