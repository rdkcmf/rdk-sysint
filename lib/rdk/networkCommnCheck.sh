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
. $RDK_PATH/utils.sh

LOG_FILE="$LOG_PATH/swupdate.log"
loop=1

echo "TIME: `/bin/timestamp` "
while [ -z $stbIp ]                           
do                                            
   stbIp=`getIPAddress`                         
   sleep 5               
   echo "MoCA ipaddress is not assigned, waiting to get the STB Ipaddress"
done 

ipv6_route_check()
{
   gatewayIPv6=""
   while [ ! "$gatewayIPv6" ]
   do
      gatewayIPv6=`ip -6 route show | grep default | grep -v unreachable | cut -d " " -f3`
   done
   /bin/ping6 -c 3 "$gatewayIPv6" > /dev/null
   while [ $? -ne 0 ]
   do
         echo "`/bin/timestamp` ping6 to $gatewayIPv6 care of $gwIf failed"
   done
}

if [ -f /tmp/wifi-on ]; then
    interface=`getWiFiInterface`
else
    interface=`getMoCAInterface`
fi

command=`which ntpq`
if [ "$command" ];then        
    ntpq -pc peers | grep remote
    result=$?
    while [ $result -ne 0 ]
    do
       sleep 10
       ntpq -pc peers | grep remote
       result=$?
       echo "Gateway is not yet ready..!"
    done
    echo "Gateway is ready now sinc ntp date & time is in sync"
else
    while [ $loop -eq 1 ]
    do
      if [ -f /tmp/estb_ipv4 ] ; then
       if [ -f /etc/resolv.conf ]; then
         dnsmasq=`cat /etc/resolv.conf`
         if [ "$" != "" ]; then
               gatewayIP=`route -n | grep $interface | grep 'UG[ \t]' | head -n1 | awk '{print $2}'`
	       gatewayIP=`echo $gatewayIP | head -n1 | awk '{print $1;}'`
               if [ "$gatewayIP" = "" ]; then
                   echo "No gateway IP to communicate now..!" 
                   sleep 5
               else
                   echo "IP=$gatewayIP..Now test it..! " 
                   ping -c 1 $gatewayIP 
                   while [  $? -ne 0 ];
                   do
                       echo "Gateway is not set..Wait & Ping gateway again" >> $LOG_FILE
                       sleep 10
                       ping -c 1 $gatewayIP 
                   done
                   loop=0
               fi
          else
               echo "DNS MASK is not set..Wait & Retry..!"
               sleep 5
          fi
      else
          echo "Missing /etc/resolv.conf file..Wait & Retry..!"
          sleep 5
      fi
     elif [ -f /tmp/estb_ipv6 ]; then
         ipv6_route_check
         loop=0
     else
         echo "Box is not configured in IPv4 or IPv6 mode yet..Wait & Retry..!"
         sleep 15
     fi
   done  
fi

sleep 15

echo "DATE: `date`"
