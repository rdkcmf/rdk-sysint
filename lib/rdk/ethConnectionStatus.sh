#! /bin/sh
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
. /etc/device.properties

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

#set -x
logsFile=$LOG_PATH/ConnectionStats.txt
pingCount=20
dnsFile="/etc/resolv.dnsmasq"
packetsLostipv4=0
packetsLostipv6=0
lossThreshold=10
v4Route=1
#pingInterval=5
gwIpv4=`/sbin/ip -4 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}'`
if [ "$gwIpv4" != "" ]; then
       gwResponse=$(ping -c $pingCount  $gwIpv4)
       ret=`echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1`
       packetsLostipv4=$ret
       gwResponseTime=`echo $gwResponse | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|'`
       echo "`/bin/timestamp` v4 gateway = $gwIpv4 " >> "$logsFile"
       if [ "$ret" = "100" ]; then
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv4" >> "$logsFile"
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv4" >> "$logsFile"
               t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
       else
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv4" >> "$logsFile"
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv4" >> "$logsFile"
       fi
else
    echo "`/bin/timestamp` TELEMETRY_GATEWAY_NO_ROUTE_V4" >> "$logsFile"
    t2CountNotify "WIFIV_INFO_NOV4ROUTE"
    v4Route=0
    packetsLostipv4=100
fi

gwIpv6=`/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}'`
if [ "$gwIpv6" != "" ] && [ "$gwIpv6" != "dev" ] ; then
       #get default interface name for ipv6 and pass it with ping6 command
       gwResponse=$(ping6 -c $pingCount  $gwIpv6)
       ret=`echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1`
       packetsLostipv6=$ret
       gwResponseTime=`echo $gwResponse | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|'`
       echo "`/bin/timestamp` v6 gateway = $gwIpv6 " >> "$logsFile"
       if [ "$ret" = "100" ]; then
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv6" >> "$logsFile"
               echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv6" >> "$logsFile"
               t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
       else
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv6" >> "$logsFile"
           echo "`/bin/timestamp` TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv6" >> "$logsFile"
       fi
else
    echo "`/bin/timestamp` TELEMETRY_GATEWAY_NO_ROUTE_V6" >> "$logsFile"
    t2CountNotify "WIFIV_INFO_NOV6ROUTE"
    if [ "$v4Route" = "0" ]; then
    	echo "`/bin/timestamp` ********** Complete ************" >> "$logsFile"
    	exit 0
    else
    	packetsLostipv6=100
    fi
fi
if [ -f "$dnsFile" ]; then
    if [ $(tr -d ' \r\n\t' < $dnsFile | wc -c ) -eq 0 ]; then
        echo "DNS File($dnsFile) is empty" >> "$logsFile"
        t2CountNotify "SYST_ERR_DNSFileEmpty"
    fi
else
    echo "DNS File is not there $dnsFile" >> "$logsFile"
fi
if [ "$packetsLostipv4" -ge "$lossThreshold" ] || [ "$packetsLostipv6" -ge "$lossThreshold" ]; then
    echo "Packet loss more than $lossThreshold% observed. Logging network stats" >> "$logsFile"
    if [ "$packetsLostipv4" = "100" ] && [ "$packetsLostipv6" = "100" ]; then
        arp -a >> "$logsFile"
        ifconfig >> "$logsFile"
        route -n >> "$logsFile"
        ip -6 route show >> "$logsFile"
        iptables -S >> "$logsFile"
        ip6tables -S >> "$logsFile"
    fi
fi
echo "`/bin/timestamp` ********** Complete ************" >> "$logsFile"