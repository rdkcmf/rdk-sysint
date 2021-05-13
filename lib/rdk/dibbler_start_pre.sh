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

/bin/touch /etc/resolv.conf
#/sbin/ifconfig $DEFAULT_ESTB_IF $DEFAULT_ESTB_IP netmask 255.255.255.0 up
/sbin/ip addr add $DEFAULT_ESTB_IP 255.255.255.0 dev $DEFAULT_ESTB_IF    
/sbin/route add $ECM_ROUTE_ADDR $ESTB_INTERFACE

## Function: removeIfNotLink
removeIfNotLink()
{
   if [ ! -h $1 ] ; then
        echo "Removing $1"
        rm -rf $1
   fi
}

if [ -f /tmp/estb_ipv6 ];then
    echo "TLV_IP_MODE: IPv6 Mode..!"
    if [ ! -f /etc/os-release ];then
        removeIfNotLink /var/lib/dibbler                                                
        if [ ! -e /var/lib/dibbler ]; then                                              
            echo "Linking dibbler with /tmp/dibbler"                                
            ln -s /tmp/dibbler /var/lib/dibbler                                     
        fi
    else
        if [ ! -h /tmp/dibbler ];then
            ln -s /etc/dibbler /tmp/dibbler
        fi
        chmod 644 /tmp/dibbler/radvd.conf
        mkdir -p /var/log/dibbler
    fi

    if [ -f /lib/rdk/prepare_dhcpv6_config.sh ]; then
        /lib/rdk/prepare_dhcpv6_config.sh
    fi
    mkdir -p /opt/dibbler
    mkdir -p /tmp/dibbler

    if [ -f /opt/dibbler/client-duid ]; then
       cp /opt/dibbler/client-duid /tmp/dibbler/client-duid
    fi

else
    echo "Box is in IPv4 Mode: Quitting the dibbler execution..!"
fi

exit 0
