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
set -x
. /etc/include.properties
. $RDK_PATH/utils.sh
. /etc/device.properties
. /etc/env_setup.sh
logsFile=$LOG_PATH/ipSetupLogs.txt
wifi_interface=`getWiFiInterface`
interface=`getMoCAInterface`
ret=`checkWiFiModule`
if [ $ret == 1 ]; then
        echo "`/bin/timestamp` WIFI is enabled" >> $logsFile
        interface=$wifi_interface
fi
    
START=1
while [ $START -lt 420 ]; do
    gatewayIP=`route -n | grep 'UG[ \t]' | grep $interface | awk '{print $2}' | grep 169.254`
    gatewayIP=`echo $gatewayIP | head -n1 | awk '{print $1;}'`
    if [ "$gatewayIP" != "" ]; then
        echo "`/bin/timestamp` got the route exiting the rstXdiscovery   "  >> $logsFile
        exit 0
    fi
    gatewayIPv6=`ip -6 route | grep $interface | awk '/default/ { print $3 }'`
    if [ "$gatewayIPv6" != "" ]; then
        echo "`/bin/timestamp` got the ipv6 route exiting the rstXdiscovery   "  >> $logsFile
        exit 0
    fi
    sleep 10
    START=$((START + 10)) 
    echo "`/bin/timestamp`  checking for the route waited for  $START seconds  "  >> $logsFile
done
    touch /tmp/rstXdiscovery
    echo "`/bin/timestamp`  Killing the xdiscovery  "  >> $logsFile
    killall xdiscovery

