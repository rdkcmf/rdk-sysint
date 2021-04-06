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

# Include File check
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

LOG_INPUT=ipSetupLogs.txt
if [ ! "$LOG_PATH" ];then LOG_PATH=/opt/logs/; fi
LOG_FILE=$LOG_PATH/$LOG_INPUT

# Input Arguments - $1 event - $2 ipaddress type - $3 interface name - $4 ipaddress - $5 ipaddress scope  
cmd=$1
flags=$5
printf "$0: Input Parameters : $* \n" >> $LOG_FILE
if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then
    # Debug Logs regarding the Network Informations
    printf "$0: IP Informations\n `ifconfig` \n" >> $LOG_FILE
    wifiMac=`grep 'wifi_mac=' /tmp/.deviceDetails.cache | sed -e "s/wifi_mac=//g"`
    t2ValNotify "Xi_wifiMAC_split" "$wifiMac"
    printf "$0: Route Informations\n `route -n` \n" >> $LOG_FILE
    printf "$0: DNS Servers Informations" >> $LOG_FILE
    printf "$0: DNS Masq File: /etc/resolv.dnsmasq\n `cat /etc/resolv.dnsmasq`\n" >> $LOG_FILE
    printf "$0: DNS Resolve: /etc/resolv.conf\n `cat /etc/resolv.conf`\n" >> $LOG_FILE
fi
exit 0
