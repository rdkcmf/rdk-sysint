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
. /etc/env_setup.sh

. $RDK_PATH/utils.sh

XCAL_DEF_INTERFACE=`getMoCAInterface`
echo "Moca interface =  $XCAL_DEF_INTERFACE"

stbIp=""
mocaIpWait()
{
  while [ -z $stbIp ]
  do
     stbIp=`ifconfig $XCAL_DEF_INTERFACE | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
     sleep 1
     echo "MoCA ipaddress is not assigned, waiting to get the STB Ipaddress"
  done
  echo "Got MOCA Ip Address: $stbIp"
}

iarmBusInitializationWait()
{
  loop=1
  while [ $loop -eq 1 ]
  do
     if [ -f $RAMDISK_PATH/.IarmBusMngrFlag ]; then
          loop=0
          echo "IARM is up, ready to start start-upnp module"
          #rm -rf $RAMDISK_PATH/.IarmBusMngrFlag
     else
         sleep 1
         echo "Waiting for IARM manager binaries..(start-upnp)!"
     fi
done
}

killall xdiscovery
XDISC_OUTPUT_FILE=/opt/output.json
XDISC_LOG_FILE=/opt/logs/xdiscovery.log
xcalDiscoveryConfig="/etc/xupnp/xdiscovery.conf"
if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/xdiscovery.conf ]; then
     xcalDiscoveryConfig="/opt/xdiscovery.conf"
fi

mocaIpWait
# IARM BUS initialization wait
iarmBusInitializationWait
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib:$LD_LIBRARY_PATH
/usr/local/bin/xdiscovery $xcalDiscoveryConfig $XDISC_LOG_FILE &
echo "Starting Xcal Dynamic Discovery Service"

sleep 30
loop=0

while [ $loop -eq 0 ]
do
   output1=`ps | grep xdiscovery | grep -v grep`
   if [ "$output1" = "" ]; then
        echo "Re Starting XDiscovery "
	/usr/local/bin/xdiscovery $xcalDiscoveryConfig $XDISC_LOG_FILE &
   fi
   sleep 30
done
