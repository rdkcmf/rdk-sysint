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
if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . /lib/rdk/commonUtils.sh
fi

if [ -f /etc/mount-utils/getConfigFile.sh ];then
      mkdir -p /tmp/.dropbear
      . /etc/mount-utils/getConfigFile.sh
fi
DROPBEAR_PARAMS_1="/tmp/.dropbear/dropcfg1$$"
DROPBEAR_PARAMS_2="/tmp/.dropbear/dropcfg2$$"
getConfigFile $DROPBEAR_PARAMS_1
getConfigFile $DROPBEAR_PARAMS_2

WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
if [ -f /tmp/SSH.pid ]
then
   if [ -d /proc/`cat /tmp/SSH.pid` ]
   then
      echo "An instance of startSSH.sh is already running !!! Exiting !!!"
      exit 0
   fi
fi

echo $$ > /tmp/SSH.pid

ipAddress=""
checkForInterface()
{
   interface=$1
   if [ -f /tmp/estb_ipv6 ]; then
       ipAddress=`ip addr show dev $interface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'`
   else 
   	   ret=`ifconfig | grep $interface | grep -v $interface:0`
   	   if [ "$ret" ]; then
          ipAddress=`ifconfig $interface |  grep inet | grep -v inet6 | grep -v localhost | grep -v 127.0.0.1 |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
       fi
  fi
}

loop=1
address=""
# mediaclient code
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
      while [ $loop -eq 1 ]
      do
           checkForInterface "$MOCA_INTERFACE"
           if [ "$ipAddress" ]; then
                 loop=0
           fi
           if [ "$WIFI_INTERFACE" ] && [ ! "$ipAddress" ];then
                 checkForInterface "$WIFI_INTERFACE"
                 if [ "$ipAddress" ]; then
                      loop=0
                 fi
           fi

           if [ ! "$ipAddress" ];then
                 if [ -f /tmp/estb_ipv4 ];then
                       checkForInterface "$ETHERNET_INTERFACE:0"
                 else
                       checkForInterface "$ETHERNET_INTERFACE"
                 fi

                 if [ "$ipAddress" ]; then
                      loop=0
                 fi
           fi

           sleep 5
     done

     if [ -e /sbin/dropbear ] || [ -e /usr/sbin/dropbear ] ; then
          if [ -f /etc/os-release ];then
              if [ "$DEVICE_TYPE" = "mediaclient" ] && [ "x$stbInWild" != "xtrue" ] ; then
                  ## Enable SSH on both IPv4 and IPv6 address for root causing DELIA-18463 in field
                  ipAddress=""
                  /bin/systemctl set-environment DROPBEAR_PARAMS_1=$DROPBEAR_PARAMS_1
                  /bin/systemctl set-environment DROPBEAR_PARAMS_2=$DROPBEAR_PARAMS_2
              fi
              /bin/systemctl set-environment IP_ADDRESS=$ipAddress
          else
              dropbear -s -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 -p $ipAddress:22 &
          fi
     fi
     exit 0
fi

startDropbear()
{
     ipAddress=$1
     echo --------- $interface got an ip $ipAddress starting dropbear service ---------
     if [ -f /etc/os-release ];then
          /bin/systemctl set-environment IP_ADDRESS=$ipAddress
          /bin/systemctl set-environment DROPBEAR_PARAMS_1=$DROPBEAR_PARAMS_1
          /bin/systemctl set-environment DROPBEAR_PARAMS_2=$DROPBEAR_PARAMS_2
     else
          dropbear -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 -p $ipAddress:22 &
     fi
     echo "$ipAddress" > /tmp/.dropbearBoundIp
}

# non-mediaclient devices
while [ $loop -eq 1 ]
do
    estbIp=`getIPAddress`
    if [ "X$estbIp" == "X" ]; then
         sleep 15
    else
         if [ "$IPV6_ENABLED" = "true" ]; then
              if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                   startDropbear "$estbIp"
                   loop=0
              elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv6 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
         else
              if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
	 fi
    fi
done

exit 0
