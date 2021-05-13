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

# exit if an instance is already running
if [ ! -f /tmp/.hdd-status.pid ];then
    echo $$ > /tmp/.hdd-status.pid
else
    pid=`cat /tmp/.hdd-status.pid`
    if [ -d /proc/$pid ];then
         exit 0
    fi
fi

pidCleanup()
{
  if [ -f /tmp/.hdd-status.pid ];then rm -rf /tmp/.hdd-status.pid ; fi
}

if [ -f /tmp/.standby ]; then
   # No logging or HDD access during standby mode
   pidCleanup
   exit 0
fi

. /etc/include.properties
. /etc/device.properties

HDD_LOG_FILE=$LOG_PATH/diskinfo.log

PATH="${PATH}:/bin:/usr/bin"

hddNode=`/bin/mount | grep 'rtdev' | head -n1 | sed -e "s|.*rtdev=||g" -e "s|,.*||g"`

if [ ! "$hddNode" ]; then
   echo "`/bin/timestamp` No HDD or SD card attached !!!" >> $HDD_LOG_FILE
   pidCleanup
   exit 0
fi

if [ ! -f $HDD_LOG_FILE ]; then
     echo "" > $HDD_LOG_FILE
fi

echo "===================== `/bin/timestamp` =========================" >> $HDD_LOG_FILE
/usr/sbin/smartctl -a "$hddNode" >> $HDD_LOG_FILE
echo "==============================================================" >> $HDD_LOG_FILE

pidCleanup
