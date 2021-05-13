#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2018 RDK Management, LLC. All rights reserved.
# ============================================================================

counter=1
while [ ! `pidof Receiver` ]
do
    sleep 2
    counter=`expr $counter + 1`
    if [ $counter -eq 30 ];then break; fi
done
echo "`date`: `basename $0`: Receiver Process Started..!"  
# Time for Receiver QT Initialization
sleep 10
# Triggering kernel events for USB Input devices
for x in `find /sys -iname uevent |  grep usb | grep input`
do
   echo $x
   echo add > $x
done
