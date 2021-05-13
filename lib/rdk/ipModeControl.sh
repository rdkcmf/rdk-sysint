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

loop=1
while [ $loop -eq 1 ]
do
    if [ -f $RAMDISK_PATH/ip_mode_control_shutdown_ipv4 ]; then
         loop=0
         echo "Shutting down the V4 UDHCPC service"
         sh /mnt/nfs/bin/scripts/stop_dhcp_v4.sh $DEFAULT_ESTB_INTERFACE
         ps | grep "udhcpc.*$DEFAULT_ESTB_INTERFACE" | grep -v grep| sed 's/\(^ *\)\([0-9]*\)\(.*\)/\2/g' | xargs kill -9 
         ps | grep udhcpcMon.sh | grep -v grep| awk '{print $1}' | xargs kill -9 
    else
         sleep 3
    fi
done
exit 0
