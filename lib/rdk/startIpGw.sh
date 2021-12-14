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
ret=`checkWiFiModule`
if [ $ret == 1 ]; then
	echo "`/bin/timestamp` WIFI is enabled" >> $logsFile
	interface=$wifi_interface
fi	

#:>$logsFile

#if [ -f $PERSISTENT_PATH/moca_interface ] ; then
#    interface=`cat $PERSISTENT_PATH/moca_interface`
#else
#    interface=eth1
#fi

while true; 
do
	echo "`/bin/timestamp` starting the ipsetup and gateway setup "   >> $logsFile
        [ ! -f /etc/os-release ]  && sh $RDK_PATH/ipSetup.sh
	sleep 15
	if [ ! -f /etc/os-release ]; then
		# We dont need this script in yocto since by the
		# time this script is done, moca ip is acquired.
		sleep 1
	fi
	process=`ps | grep gwConnNotify.sh  | grep -v grep `
	if [ "$process" != "" ]; then
		ps  | grep gwConnNotify.sh | grep -v grep | awk '{print $1}'| xargs kill -9
	fi
	if [ -f /tmp/gatewayConnected ] && [ -f /usr/local/bin/IARM_event_sender ]; then
		echo "`/bin/timestamp` sending gateway disconnected event" >> $logsFile
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
            gatewayIP=`route -n | grep $interface | grep 'UG[ \t]' | awk '{print $2}'`
            gatewayIP=`route -n | grep 'UG[ \t]' | grep $interface | awk '{print $2}' | grep 169.254`
            gatewayIP=`echo $gatewayIP | head -n1 | awk '{print $1;}'`
            if [ "$KICKSTART" = "yes" ]; then
                    gatewayIP=`route -n | grep 'UG[ \t]' | awk '{print $2}'`
                    touch /tmp/gatewayConnected
            fi
            if [ "$gatewayIP" = "" ]; then
                    echo "`/bin/timestamp` No gateway IP going to ipsetup "  >> $logsFile
            else
                    dnsmasq=`cat /etc/resolv.dnsmasq`
                    if [ "$dnsmasq" == "" ]; then
                            echo "`/bin/timestamp` DNS masq is not set Please check output.json for dns config ****  " >> $logsFile
                    fi
    #               sh /test.sh
                    ping -c 3 $gatewayIP   > /dev/null 2>/dev/null
                    while [  $? -eq 0 ];
                    do
                            if [ ! -f /tmp/gatewayConnected ]; then
                                    process=`ps | grep gwConnNotify  | grep -v grep `
                                    if [ "$process" = "" ]; then
                                            sh $RDK_PATH/gwConnNotify.sh &
                                            echo "`/bin/timestamp` Connected to Gateway  $gatewayIP  "  >> $logsFile
                                    fi
                            fi
                            sleep 15
                            ping -c 3 $gatewayIP    > /dev/null 2>/dev/null
                    done;

            fi
         elif [ -f /tmp/estb_ipv6 ]; then    
            gatewayIP=`ip -6 route | grep $interface | awk '/default/ { print $3 }'`
            if [ "$KICKSTART" = "yes" ]; then
                    gatewayIP=`ip -6 route | awk '/default/ { print $3 }'`
                    touch /tmp/gatewayConnected
            fi
            if [ "$gatewayIP" = "" ]; then
                    sleep 5
            else
                    dnsmasq=`cat /etc/resolv.dnsmasq`
                    if [ "$dnsmasq" == "" ]; then
                            echo "`/bin/timestamp` DNS masq is not set Please check output.json for dns config ****  " >> $logsFile
                    fi
    #               sh /test.sh
                    ping6 -c 3 $gatewayIP   > /dev/null 2>/dev/null
                    while [  $? -eq 0 ];
                    do
                            if [ ! -f /tmp/gatewayConnected ]; then
                                    process=`ps | grep gwConnNotify  | grep -v grep `
                                    if [ "$process" = "" ]; then
                                            sh $RDK_PATH/gwConnNotify.sh &
                                            echo "`/bin/timestamp` Connected to Gateway  $gatewayIP  "  >> $logsFile
                                    fi
                            fi
                            sleep 15
                            ping6 -c 3 $gatewayIP    > /dev/null 2>/dev/null
                    done;

            fi
         else
            echo "`/bin/timestamp` Box is not configured in IPv4 or IPv6 mode yet..Wait & Retry..!" >> $logsFile
         fi

#        if [ ! -f /tmp/rstXdiscovery ]; then
#	    process=`ps | grep rstXdiscovery  | grep -v grep `
#    	    if [ "$process" = "" ]; then
#            	sh $RDK_PATH/rstXdiscovery.sh &
#            fi
#        fi
done





