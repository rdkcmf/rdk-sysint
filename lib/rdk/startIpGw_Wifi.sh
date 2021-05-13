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

. $RDK_PATH/utils.sh
interface=`getMoCAInterface`

logsFile=$LOG_PATH/ipSetupLogs.txt
#:>$logsFile

insmod /usr/local/lib/modules/mt7610u_sta_util.ko
insmod /usr/local/lib/modules/mt7610u_sta.ko
insmod /usr/local/lib/modules/mt7610u_sta_net.ko

sleep 5


ifconfig $interface up
sleep 10
iwpriv ra0 set WirelessMode=14 >> $logsFile
sleep 3
iwpriv ra0 set AuthMode=WPA2PSK  >> $logsFile 
sleep 1
iwpriv ra0 set EncrypType=AES   >> $logsFile 
sleep 1
iwpriv ra0 set WPAPSK="comcast123" >> $logsFile 
sleep 1
iwpriv ra0 set SSID="COMCAST-5" >> $logsFile
sleep 1
iwpriv ra0 set tpc=90 >> $logsFile 
sleep 2



while true; 
do
	echo "`/bin/timestamp` starting the ipsetup and gateway setup " 
	sh $RDK_PATH/ipSetup.sh
	sleep 1
        gatewayIP=`route -n | grep $interface | grep 'UG[ \t]' | awk '{print $2}'`
        if [ "$gatewayIP" = "" ]; then
                echo "`/bin/timestamp` No gateway IP going to ipsetup " 
        else
                dnsmasq=`cat /etc/resolv.conf`
		if [ "$dnsmasq" != "" ]; then
                	ping -c 1 $gatewayIP   > /dev/null 2>/dev/null
                	while [  $? -eq 0 ];
                	do
#                        	echo "`/bin/timestamp` Gateway is fine so going for a sleep" >> $logsFile
                        	sleep 2
                        	ping -c 1 $gatewayIP    > /dev/null 2>/dev/null
                	done;
		else
			echo "`/bin/timestamp` DNS masq is not set " >> $logsFile
		fi

        fi
done





