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

if [ -f $PERSISTENT_PATH/.sleep ] ; then
   time=`echo $PERSISTENT_PATH/.sleep`
else
   time=$1
fi

VL_THREAD_LOG=vlthreadanalyzer_log.txt

if [ "$DEVICE_TYPE" = "hybrid" ]; then
     VL_THREAD_BIN="/usr/bin/rmfthreadanalyzer ./rmfStreamer"
else
     VL_THREAD_BIN=/mnt/nfs/bin/vlthreadanalyzer
fi
 
loop=1
while [ $loop -eq 1 ]
do
  if [ -f /tmp/.power_on ]; then
       $VL_THREAD_BIN 1 2000 >> $LOG_PATH/$VL_THREAD_LOG
       sleep $time
  else
       $VL_THREAD_BIN 1 2000 >> $TEMP_LOG_PATH/$VL_THREAD_LOG
       sleep 30
  fi
done

