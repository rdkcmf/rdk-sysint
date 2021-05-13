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

if [ -f /etc/os-release ]; then
    exit 0
fi

if [ "$LIGHTSLEEP_ENABLE" != "true" ] ; then exit; fi

#. $RDK_PATH/stackUtils.sh

LOGFILE=$LOG_PATH/lightsleep.log
# pipe or not flag
flag=$1

/QueryPowerState -c &> /tmp/output.txt                                                       
cat /tmp/output.txt | grep "STANDBY" >> $LOGFILE                                             
if [ $? -eq 0 ]; then 
    LOG_PATH=$TEMP_LOG_PATH
else
    LOG_PATH=$LOG_PATH
fi

processCheck()
{
   pipeName=$1
   fileName=$2
   
   ps | grep cat | grep -v grep | grep pipe_receiver | awk '{print $1}'| xrags kill -9 &>/dev/null
   echo "Calling $1 pipe" >> $LOG_PATH/lightsleep.log
   cat $TEMP_LOG_PATH/$pipeName >> $LOG_PATH/$fileName &
}

processCheck "pipe_receiver" receiver.log
