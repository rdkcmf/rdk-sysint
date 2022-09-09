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
. /etc/device.properties
. /etc/env_setup.sh

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
logsFile=$LOG_PATH/ipSetupLogs.txt
wifi_interface=`getWiFiInterface`
interface=`getMoCAInterface`

ipGWLog() {
    echo "`date -u +%d.%m.%Y_%H:%M:%S`: $0: $*" >> $logsFile
}

ret=`checkWiFiModule`
if [ $ret == 1 ]; then
    ipGWLog "WIFI is enabled"
    interface=$wifi_interface
fi

CheckIPConnection()
{
    dnsmasq=`cat /etc/resolv.dnsmasq`
    PING_BIN="$1"
    if [ "$dnsmasq" == "" ]; then
        ipGWLog "DNS masq is not set Please check output.json for dns config ****  "
    fi
    $PING_BIN -c 3 $gatewayIP   > /dev/null 2>/dev/null
    while [  $? -eq 0 ];
    do
        if [ ! -f /tmp/gatewayConnected ]; then
            process=`ps | grep gwConnNotify  | grep -v grep `
            if [ "$process" = "" ]; then
                sh $RDK_PATH/gwConnNotify.sh &
                ipGWLog "Connected to Gateway  $gatewayIP"
            fi
        fi
        sleep 15
        $PING_BIN -c 3 $gatewayIP  > /dev/null 2>/dev/null
    done;
}

while true;
do
    ipGWLog "Starting the ipsetup and gateway setup "
    [ ! -f /etc/os-release ]  && sh $RDK_PATH/ipSetup.sh
        sleep 15
        if [ ! -f /etc/os-release ]; then
            # We dont need this script in yocto since by the time this script is done, moca ip is acquired.
            sleep 1
        fi
        process=`ps | grep gwConnNotify.sh  | grep -v grep `
        if [ "$process" != "" ]; then
            ps  | grep gwConnNotify.sh | grep -v grep | awk '{print $1}'| xargs kill -9
        fi
        if [ -f /tmp/gatewayConnected ] && [ -f /usr/local/bin/IARM_event_sender ]; then
            ipGWLog "sending gateway disconnected event"
            if [ ! -f /etc/os-release ]; then
                /usr/local/bin/IARM_event_sender GatewayConnEvent 0
                /usr/local/bin/IARM_event_sender MocaStatusEvent 1
            else
                /usr/bin/IARM_event_sender GatewayConnEvent 0
                /usr/bin/IARM_event_sender MocaStatusEvent 1
            fi
            rm /tmp/gatewayConnected
        fi
        if [ -f /tmp/estb_ipv4 ]; then
            gatewayIP=`route -n | grep 'UG[ \t]'`
            gatewayIP=`echo $gatewayIP | head -n1 | grep $interface | awk '{print $2}' | grep 169.254`
            PING="/bin/ping"
            if [ "$gatewayIP" = "" ]; then
                ipGWLog "No gateway IP going to ipsetup "
            else
                CheckIPConnection $PING
            fi
        elif [ -f /tmp/estb_ipv6 ]; then
            gatewayIP=`ip -6 route > /tmp/tmpIPv6RouteData`
            gatewayIP=`cat /tmp/tmpIPv6RouteData | grep $interface | awk '/default/ { print $3 }'`
            PING="/bin/ping6"
            if [ "$gatewayIP" = "" ]; then
                sleep 5
            else
                CheckIPConnection $PING
            fi
         else
            ipGWLog "Box is not configured in IPv4 or IPv6 mode yet..Wait & Retry..!"
         fi
done
