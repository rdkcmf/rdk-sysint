#!/bin/busybox sh
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

. /etc/env_setup.sh

. $RDK_PATH/soc_specific_fn.sh

# Initial sleep to get up the box
#sleep $UDHCPC_MONITOR_TIME

loop=0
while [ $loop -eq 0 ];
do
     if [ -f /tmp/estb_ipv6 ]; then
          echo "TLV_IP_MODE: IPv6 Mode..!"
          processName=dibbler-client
          loop=1
     elif [ -f /tmp/estb_ipv4 ]; then
          echo "TLV_IP_MODE: IPv4 Mode..!"
          processName=udhcpc
          loop=1
     else
          echo "Waiting for TLV flag (v4/v6)"
          sleep 1
     fi
done

echo -e "nameserver \t127.0.0.1" >> /tmp/resolv.conf
#echo -e "nameserver \t::1" >> /tmp/resolv.conf
# dnsmasq update
#echo -e "nameserver \t2001:558:feed::1" >> /tmp/resolv.dnsmasq
#echo -e "nameserver \t2001:558:feed::2" >> /tmp/resolv.dnsmasq

# Adding config for avoiding Voice Guidance issue
if [ -f /lib/rdk/disableIpv6Autoconf.sh ];then
     sh /lib/rdk/disableIpv6Autoconf.sh $MOCA_INTERFACE
fi

UDHCPMONLOG="$TEMP_LOG_PATH/udhcp_monitor.log"
#TLV_IP_MODE="Unspecified"
#restartUdhcp "$processName"

if [ ! -f /etc/os-release ];then
     if [ "$DEVICE_TYPE" = "hybrid" ] && [ "$BOX_TYPE" != "RNG150" ];then
             sh /lib/rdk/ipv4-client-upgrade.sh &
     fi
fi

# Repeat the udhcp monitor
while true
do
    result=0
    result=`pidof "$processName"`
    if [ ! "$result" ] ; then
        date >> $UDHCPMONLOG
        echo "udhcpc script is killed .. restarting in TLV_Mode : $TLV_IP_MODE" >> $UDHCPMONLOG
        restartUdhcp "$processName"
        sleep 2
    else
        sleep 10
    fi
done
