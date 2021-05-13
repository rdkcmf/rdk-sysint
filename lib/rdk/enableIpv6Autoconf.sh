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


interface=$1

if [ -f  /lib/rdk/getRFC.sh ]; then
    . /lib/rdk/getRFC.sh SLAACSUPPORT
fi

echo "RFC_ENABLE_SLAACSUPPORT:$RFC_ENABLE_SLAACSUPPORT"

RFC_ENABLE_SLAACSUPPORT_L=`echo $RFC_ENABLE_SLAACSUPPORT | tr '[:upper:]' '[:lower:]'`
if [ "x$RFC_ENABLE_SLAACSUPPORT_L" != "xfalse" ]; then
   echo "SLAAC support is enabled WITHOUT RFC Check"
   sysctl -w "net.ipv6.conf.$interface.accept_ra=1"
   sysctl -w "net.ipv6.conf.$interface.autoconf=1"
   sysctl -w "net.ipv6.conf.$interface.accept_ra_defrtr=1"
   sysctl -w "net.ipv6.conf.$interface.use_tempaddr=2"
   sysctl -w "net.ipv6.conf.$interface.disable_ipv6=1"
   sysctl -w "net.ipv6.conf.$interface.disable_ipv6=0"
else
   echo "SLAAC support is Disabled via RFC"
fi
