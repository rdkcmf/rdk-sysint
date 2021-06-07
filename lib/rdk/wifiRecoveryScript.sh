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


. /etc/device.properties
. /etc/include.properties
. $RDK_PATH/utils.sh

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

prevResetCount=0
logsFile=$LOG_PATH/xiConnectionStats.txt
wifiResetCounterFile="/tmp/.wifiResetCounter" 
ethernet_interface=`getMoCAInterface` #In Xi WiFi devices MoCA is mapped to Ethernet 

while :
do
    if [ -s "$wifiResetCounterFile" ]; then
        prevResetCount=`cat $wifiResetCounterFile`
    fi
    ethernet_state=`cat /sys/class/net/$ethernet_interface/operstate`
    if [ "$ethernet_state" == "up" ]; then
    	echo "`/bin/timestamp` Wi-Fi Reset Mode Ethernet!" >> $logsFile
        exit 0
    fi
    dir=`find /sys/kernel/debug/ieee80211  -type d -maxdepth 1 | sed '1d'`
    if [ -z "$dir" ]; then
        echo "`/bin/timestamp` phy directory not in /sys/kernel/debug/ieee80211" >> $logsFile
        ((resetCounter++))
    else
        if [ ! -f $dir/ath10k/fw_stats ]; then
            echo "`/bin/timestamp` fw_stats file not in /sys/kernel/debug/ieee80211/$dir/ath10k/" >> $logsFile
            ((resetCounter++))
        else
        	cat $dir/ath10k/fw_stats > /dev/null 2>&1
			if [[ $? -ne 0 ]]; then
				echo "`/bin/timestamp` Cant open file /sys/kernel/debug/ieee80211/$dir/ath10k/ status=$?" >> $logsFile
				((resetCounter++))
			else
				resetCounter=0
			fi
        fi
    fi
    if [ $resetCounter -eq 24 ]; then
        resetCounter=0
        echo "`/bin/timestamp` Start WiFi Reset. !!!!!!!!!!!!!!"  >> $logsFile
        t2CountNotify "WIFIV_ERR_Selfheal"
        if [ ! -f /usr/sbin/wifi_reset.sh ]; then
            echo "`/bin/timestamp` /usr/sbin/wifi_reset.sh script not there exiting!" >> $logsFile
            exit 0
        fi
        sh /usr/sbin/wifi_reset.sh >> $logsFile   2>&1
    	sleep 2
        systemctl restart wifi.service
        systemctl restart moca.service                    
        systemctl restart xcal-device                      
        systemctl restart xupnp                            
        systemctl restart netsrvmgr.service
        systemctl restart virtual-wifi-iface.service
        echo "`/bin/timestamp` WiFi Reset done as part of  Recovery. !!!!!!!!!!!!!!"  >> $logsFile
        sleep 300  #make sure that we dont go in a loop
        prevResetCount=`expr $prevResetCount + 1`
        echo $prevResetCount > $wifiResetCounterFile
        if [ "$prevResetCount" -eq 3 ]; then
            echo "`/bin/timestamp` Done Enough Wi-Fi reset on this boot ! Wi-Fi Reset Done = $prevResetCount" >> $logsFile
            t2CountNotify "WIFIV_ERR_MaxReset"
            exit 0
	    fi
    fi
    sleep 5
done

