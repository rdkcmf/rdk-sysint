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

while [ ! -f /tmp/estb_ipv4 ]
do
 if [ -f /tmp/estb_ipv6 ];then
      exit 0
 fi
 sleep 1
done
if [ -f /tmp/estb_ipv4 ];then
    echo "TLV_IP_MODE: IPv4 Mode..!"
    /usr/bin/udhcpc_opt43 -b -i $ESTB_INTERFACE -V OpenCable2.1 -p /tmp/udhcpc_wan.pid -x 0x7d:0000170f00
    /sbin/ifconfig $DEFAULT_ESTB_IF 192.168.17.10 netmask 255.255.255.0 up
    /sbin/ip addr add 192.168.17.10 255.255.255.0 dev $DEFAULT_ESTB_IF
    /sbin/route add 192.168.17.0 $ESTB_INTERFACE
else
    echo "Box is in IPv6 Mode: Quitting the udhcpc execution..!"
fi

