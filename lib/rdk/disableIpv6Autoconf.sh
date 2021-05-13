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

if [ $LAN_INTERFACE ] && [ "$DEVICE_TYPE" = "mediaclient" ];then
  if [ -f /proc/sys/net/ipv6/conf/$LAN_INTERFACE/disable_ipv6 ];then
     echo 1 > /proc/sys/net/ipv6/conf/$LAN_INTERFACE/disable_ipv6
  fi
fi

if [ "$1" ];then
     interface=$1
     # Adding config for avoiding Voice Guidance issue                             
     if [ -f /proc/sys/net/ipv6/conf/$interface/accept_ra ];then
           sysctl -w "net.ipv6.conf.$interface.accept_ra=0"                          
     fi
     if [ -f /proc/sys/net/ipv6/conf/$interface/autoconf ];then
           sysctl -w "net.ipv6.conf.$interface.autoconf=0"           
     fi                 
     if [ -f /proc/sys/net/ipv6/conf/$interface/use_tempaddr ];then
           sysctl -w "net.ipv6.conf.$interface.use_tempaddr=0"             
     fi
     if [ -f /proc/sys/net/ipv6/conf/$interface/accept_ra_defrtr ];then
          sysctl -w "net.ipv6.conf.$interface.accept_ra_defrtr=0"
     fi

else
     echo "Usage: $0 <interface>"
     echo "Please call the script with an interface..!"
fi
