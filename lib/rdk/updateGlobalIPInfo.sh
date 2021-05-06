#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2018 RDK Management, LLC. All rights reserved.
# ============================================================================

. /etc/device.properties

cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5

refresh_devicedetails()
{
    #Refresh device cache info
    if [ -f /lib/rdk/getDeviceDetails.sh ]; then
        sh /lib/rdk/getDeviceDetails.sh refresh $1
    else
        echo "DeviceDetails file not present"
    fi
}

check_valid_IPaddress()
{
    # Neglect IPV6 ULA address and autoconfigured IPV4 address
    if [ "x$mode" == "xipv6" ]; then
        if [[ $addr == fc* || $addr == fd* ]]; then
            exit
        fi
    elif [ "x$mode" == "xipv4" ]; then
        autoIPTrunc=`echo $addr | cut -d "." -f1-2 `
        if [ "$autoIPTrunc" == "169.254" ]; then
            exit
        fi
    fi
}


echo "updateGlobalIPInfo.sh Arguments: cmd:$1, mode:$2, ifc:$3, addr:$4, flags:$5"

if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then

    if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" || "$ifc" == "$ESTB_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Box/ESTB IP"
        echo "$addr" > /tmp/.$mode$ESTB_INTERFACE
        refresh_devicedetails "estb_ip"
    elif [[ "$ifc" == "$MOCA_INTERFACE" || "$ifc" == "$MOCA_INTERFACE:0" ]]; then
        echo "Updating MoCA IP"
        echo "$addr" > /tmp/.$mode$MOCA_INTERFACE
        refresh_devicedetails "moca_ip"
    elif [[ "$ifc" == "$WIFI_INTERFACE" || "$ifc" == "$WIFI_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Wi-Fi IP"
        echo "$addr" > /tmp/.$mode$WIFI_INTERFACE
        refresh_devicedetails "boxIP"
    fi
fi
