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

x=1

while [ $x -ne 5 ]
do
   x=`expr $x + 1`
   if [ -f /tmp/clock-event ] || [ -f /run/systemd/timesync/synchronized ];then
        x=5        
   fi
   echo "NTP Time not set yet..!"
   sleep 60
done

echo "NTP Event set using the build time..!"
touch /tmp/clock-event
if [ -d /run/systemd/timesync ];then
    touch /run/systemd/timesync/synchronized
fi
exit 0
