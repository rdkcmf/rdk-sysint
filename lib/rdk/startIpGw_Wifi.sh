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





