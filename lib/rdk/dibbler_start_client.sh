#!/bin/sh
#
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2014 RDK Management, LLC. All rights reserved.
# ============================================================================
#
. /etc/include.properties
. /etc/device.properties
. /lib/rdk/utils.sh
if [ -f  /lib/rdk/getRFC.sh ]; then
    . /lib/rdk/getRFC.sh SLAACSUPPORT
fi
echo "RFC_ENABLE_SLAACSUPPORT:$RFC_ENABLE_SLAACSUPPORT"
RFC_ENABLE_SLAACSUPPORT_L=`echo $RFC_ENABLE_SLAACSUPPORT | tr '[:upper:]' '[:lower:]'`
if [ "x$RFC_ENABLE_SLAACSUPPORT_L" != "xfalse" ]; then
    echo "SLAAC support is enabled WITHOUT RFC Check"
    exit 0
else
    PREFERED_GATEWAY=$(cat /opt/prefered-gateway)
    echo "PREFERED_GATEWAY:$PREFERED_GATEWAY"
    if [ "${PREFERED_GATEWAY:0:2}" != "XB" ]; then
        echo "Prefered gateway is not XB"
        exit 0
    fi
    DHCPv6ClientEnabled=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DHCPv6Client.Enable 2>&1 > /dev/null)
    echo "DHCPv6ClientEnabled:$DHCPv6ClientEnabled"
    if [ "$DHCPv6ClientEnabled" != "true" ]; then
        echo "DHCPv6 client is disabled via RFC"
        exit 0
    fi
fi
## Function: removeIfNotLink
DHCP_CONFIG_FILE_TMP="/etc/dibbler/client_back.conf"
DHCP_CONFIG_FILE_RUNTIME="/etc/dibbler/client.conf"
cat $DHCP_CONFIG_FILE_TMP > $DHCP_CONFIG_FILE_RUNTIME
ifce=$ESTB_INTERFACE
if [ -f /tmp/wifi-on ]; then
ifce=$WIFI_INTERFACE
fi
echo "2" > /proc/sys/net/ipv6/conf/$ifce/accept_ra
echo "1" > /proc/sys/net/ipv6/conf/$ifce/accept_ra_defrtr

sysctl -w "net.ipv6.conf.$ifce.accept_ra=2"
sysctl -w "net.ipv6.conf.$ifce.accept_ra_defrtr=1"
sysctl -w "net.ipv6.conf.$ifce.disable_ipv6=1"
sysctl -w "net.ipv6.conf.$ifce.disable_ipv6=0"

sleep 2
sed -i "s/RDK-ESTB-IF/${ifce}/g"  $DHCP_CONFIG_FILE_RUNTIME
/usr/sbin/dibbler-client start
exit $?
