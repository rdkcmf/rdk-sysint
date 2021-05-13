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
#
. /etc/include.properties
. /etc/device.properties


if [ -f /tmp/estb_ipv6 ];then
    echo "TLV_IP_MODE: IPv6 Mode..!"
    while [ ! -f /tmp/dibbler/client-duid ]
    do
        echo "Waiting for client duid generation"
        sleep 2
    done

    if [ -f /tmp/dibbler/client-duid ]; then
       cp /tmp/dibbler/client-duid /opt/dibbler/client-duid
    fi

    if [ ! -f /etc/os-release ];then
         if [ "$DEVICE_TYPE" = "hybrid" ] && [ "$BOX_TYPE" != "RNG150" ];then
             sh /lib/rdk/ipv4-client-upgrade.sh &
         fi
    fi

else
    echo "Box is in IPv4 Mode: Quitting the dibbler execution..!"
fi

exit 0
