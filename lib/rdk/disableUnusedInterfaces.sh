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
. /etc/device.properties

if [ $# -ne 1 ] || [ -z "$1" ];then
    exit 0
fi

iface=$1

if [ "$DEVICE_TYPE" = "hybrid" ];then

    if [ "$PODNET_INTERFACE" = "$iface" ]; then
        interface=`ls /sys/class/net | grep $PODNET_INTERFACE`
        if [ "$interface" != "" ]; then
            #Bringing down podnet0 interface
            ifconfig $PODNET_INTERFACE down
        fi
    fi
fi
