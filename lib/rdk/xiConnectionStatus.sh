#! /bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
. /etc/include.properties
. $RDK_PATH/utils.sh
. /etc/include.properties
. /etc/device.properties

#set -x
logsFile=$LOG_PATH/xiConnectionStats.txt
pingCount=20
current_cron_file="$PERSISTENT_PATH/cron_file.txt"
lastConnectionStatusFile="/tmp/.lastXiConnectionStatus.txt"
dnsFile="/etc/resolv.dnsmasq"
wifiStateFile="/tmp/wifi-on"
wifiReassociateFile="/tmp/wifiReassociate"
wifiResetCounterFile="/tmp/.wifiResetCounter"
packetsLostipv4=0
packetsLostipv6=0
lossThreshold=10
wifiDeviceConnected=0
ethernetDeviceConnected=0
lnfSSIDConnected=0
lnfPskSSID=A16746DF2466410CA2ED9FB2E32FE7D9
lnfEnterpriseSSID=D375C1D9F8B041E2A1995B784064977B
v4Route=1
#pingInterval=5
ethernet_interface=`getMoCAInterface` #In Xi WiFi devices MoCA is mapped to Ethernet 
ethernet_state=`cat /sys/class/net/$ethernet_interface/operstate`
checkWifiConnected()
{
    if [ -f $wifiStateFile ]; then
        strBuffer=`wpa_cli status`
         if [[ "$strBuffer" =~ "wpa_state=COMPLETED" ]];then
                if [[ "$strBuffer" =~ "$lnfPskSSID" ]] || [[ "$strBuffer" =~ "$lnfEnterpriseSSID" ]] ;then
                        lnfSSIDConnected=1
                        return 0
                else
                        return 1
            fi
        else
            return 0
        fi
    else
        return 0
    fi
}
checkWifiEAPOLIssue()
{
        if [ "$DEVICE_NAME" = "XI5" ]; then
                recover=`/usr/bin/wl recover`
	    # Check bit 0
	    	if [ "$recover" = "0" ]; then
	    		return
	    		
	        elif [ "$recover" = "1" ]
	        then
	                echo "`/bin/timestamp` Initiate FIFO ERROR recovery" >> $logsFile
	                # RESET RECOVERY Flag immediately
	                wl recover 0
#	                sh /rebootNow.sh -s EAPOL-FAILURE-FIFO
	                # Check bit 1
	        elif [ "$recover" = "2" ]
	        then
	                echo "`/bin/timestamp` Initiate AMPDU Timeout recovery" >> $logsFile
	                # RESET RECOVERY Flag immediately
	                wl recover 0
#	                sh /rebootNow.sh -s EAPOL-FAILURE-AMPDU
	        elif [ "$recover" = "3" ]
	        then
	                echo "`/bin/timestamp` Initiate FIFO-AMPDU Timeout recovery" >> $logsFile
	                # RESET RECOVERY Flag immediately
	                wl recover 0
#	                sh /rebootNow.sh -s EAPOL-FAILURE-FIFO-AMPDU
	        fi
	    fi
}
#chkWifiDevice=`echo $DEVICE_NAME | grep -o -E '[0-9]+'`
if [ "$DEVICE_NAME" = "XI6" ]; then
    if [ ! -f "$wifiResetCounterFile" ] && [ "$ethernet_state" != "up" ]; then
        touch $wifiResetCounterFile
        echo "`/bin/timestamp` Starting wifi self heal script to check for wifi driver issue. !!!!!!!!!!!!!!"  >> $logsFile
        /lib/rdk/wifiRecoveryScript.sh &
    fi
fi
if [ "$WIFI_SUPPORT" = "true" ];then

        if [ "$ethernet_state" != "up" ] ; then
                checkWifiConnected
                ret=$?
                if [ $ret -eq  0 ]; then
                        if [ "$lnfSSIDConnected" = "1" ]; then
                        	echo "`/bin/timestamp` TELEMETRY_WIFI_CONNECTED_LNF" >> $logsFile
                        else
                            echo "`/bin/timestamp` TELEMETRY_WIFI_NOT_CONNECTED" >> $logsFile
                        	checkWifiEAPOLIssue
                        fi
                        echo "`/bin/timestamp` ********** Complete ************" >> $logsFile
                        exit 0
                else
                        wifiDeviceConnected=1
                        echo "`/bin/timestamp` TELEMETRY_WIFI_CONNECTED" >> $logsFile
                fi
        else
                ethernetDeviceConnected=1
                echo "`/bin/timestamp` TELEMETRY_ETHERNET_CONNECTED" >> $logsFile
        fi
fi
if [ -s "$lastConnectionStatusFile" ]; then
prevStatus=`cat $lastConnectionStatusFile`
echo "`/bin/timestamp` prevStatus = $prevStatus" >> $logsFile
else
    prevStatus=1
fi
gwIpv4=`route -n | grep 'UG[ \t]'  | awk '{print $2}' | head -n1 | awk '{print $1;}'`
if [ "$gwIpv4" != "" ]; then
       gwResponse=$(ping -c $pingCount  $gwIpv4)
       ret=`echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1`
       packetsLostipv4=$ret
       gwResponseTime=`echo $gwResponse | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|'`
       echo "`/bin/timestamp` v4 gateway = $gwIpv4 " >> $logsFile
       if [ "$ret" = "100" ]; then
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv4" >> $logsFile
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv4" >> $logsFile
       else
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv4" >> $logsFile
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv4" >> $logsFile
           echo "1" > $lastConnectionStatusFile
       fi
else
    echo "`/bin/timestamp` TELEMETRY_GATEWAY_NO_ROUTE_V4" >> $logsFile
    v4Route=0
    packetsLostipv4=100
fi

gwIpv6=`/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}'`
if [ "$gwIpv6" != "" ] && [ "$gwIpv6" != "dev" ] ; then
       #get default interface name for ipv6 and pass it with ping6 command
       gwIp6_interface=`/sbin/ip -6 route | awk '/default/ { print $5 }' | head -n1 | awk '{print $1;}'`
       gwResponse=$(ping6 -I $gwIp6_interface -c $pingCount  $gwIpv6)
       ret=`echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1`
       packetsLostipv6=$ret
       gwResponseTime=`echo $gwResponse | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|'`
       echo "`/bin/timestamp` v6 gateway = $gwIpv6 " >> $logsFile
       if [ "$ret" = "100" ]; then
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv6" >> $logsFile
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv6" >> $logsFile
       else
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv6" >> $logsFile
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv6" >> $logsFile
           echo "1" > $lastConnectionStatusFile
       fi
else
    echo "`/bin/timestamp` TELEMETRY_GATEWAY_NO_ROUTE_V6" >> $logsFile
    if [ "$v4Route" = "0" ]; then
    	echo "`/bin/timestamp` ********** Complete ************" >> $logsFile
    	exit 0
    else
    	packetsLostipv6=100
    fi
fi
if [ "$DEVICE_NAME" = "XI5" ]; then
	wl chanim_stats >> $logsFile
fi
if [ -f "$dnsFile" ]; then
    if [ $(tr -d ' \r\n\t' < $dnsFile | wc -c ) -eq 0 ]; then
        echo "DNS File($dnsFile) is empty" >> $logsFile
    fi
else
    echo "DNS File is not there $dnsFile" >> $logsFile
fi

if [ "$prevStatus" -eq 1 ]; then
    if [ "$packetsLostipv4" -ge "$lossThreshold" ] || [ "$packetsLostipv6" -ge "$lossThreshold" ]; then
        echo "Packet loss more than $lossThreshold% observed. Logging network stats" >> $logsFile
        if [ "$packetsLostipv4" = "100" ] && [ "$packetsLostipv6" = "100" ]; then
            arp -a >> $logsFile
            ifconfig >> $logsFile
            route -n >> $logsFile
            ip -6 route show >> $logsFile
            iptables -S >> $logsFile
            ip6tables -S >> $logsFile
            echo "0" > $lastConnectionStatusFile
            echo "$(cat /etc/resolv.dnsmasq)" >> $logsFile
        fi
        if [ "$WIFI_SUPPORT" = "true" ] && [ "$ethernetDeviceConnected" != "1" ]; then
                       [ -f $wifiReassociateFile ] && rm $wifiReassociateFile
                count=0
                while [ "$count" -lt "2" ]
                do
                    if [ "$DEVICE_NAME" = "XI6" ]; then
                        dir=`find /sys/kernel/debug/ieee80211  -type d -maxdepth 1 | sed '1d'`
						if [  -f $dir/ath10k/fw_stats ]; then
							echo "===`/bin/timestamp`: Xi6 wifi fw_stats===" >> $logsFile
							cat $dir/ath10k/fw_stats >> $logsFile
						fi
                    elif [ "$DEVICE_NAME" = "XI5" ]; then
                        echo "===`/bin/timestamp`: Xi5 wifi fw_stats===" >> $logsFile
                            wl counters >> $logsFile
                    fi
                    iw dev $WIFI_INTERFACE link >> $logsFile
                    sleep 10
                    ((count++))
                done
                if [ "$DEVICE_NAME" = "XI5" ]; then
                        wl status >> $logsFile
                        wl reset_cnts
                fi
            fi
    fi
else
        if [ "$WIFI_SUPPORT" = "true" ] && [ "$wifiDeviceConnected" = "1" ] && [ "$packetsLostipv4" = "100" ] && [ "$packetsLostipv6" = "100" ]; then
                if [ ! -f $wifiReassociateFile ]; then
                        echo "`/bin/timestamp` Packet Loss WiFi Reassociating" >> $logsFile
                        wpa_cli reassociate
                        touch $wifiReassociateFile
                else
                        echo "`/bin/timestamp` Packet Loss already done WiFi reassociated"  >> $logsFile
                fi
        fi

fi
echo "`/bin/timestamp` ********** Complete ************" >> $logsFile
