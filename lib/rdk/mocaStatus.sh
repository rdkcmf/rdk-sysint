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

MOCA_LOG_FILE=$LOG_PATH/mocaStatus.log
MOCA_STATUS_FILE=$PERSISTENT_PATH/mocalinkstatus

mocaNewStatus=`mocactl show --status | awk '{for (i=1;i<=NF;i++) if($i ~/linkStatus/) print $(i+2)}'`

MOCA_LOG_COUNTER=/tmp/mocaLogCount.txt

doMoCALogging()
{
	echo  "`/bin/timestamp`" `mocactl show --status`  >> $MOCA_LOG_FILE
        echo  "`/bin/timestamp`" `mocactl show --stats`  >> $MOCA_LOG_FILE
        echo  "`/bin/timestamp`" `mocactl showtbl --nodestatus`  >> $MOCA_LOG_FILE
        echo  "`/bin/timestamp`" `mocactl showtbl --nodestats`  >> $MOCA_LOG_FILE
}

if [ ! -f $MOCA_STATUS_FILE ]; then
	doMoCALogging
        echo $mocaNewStatus > $MOCA_STATUS_FILE
else
        mocaOldStatus=`cat $MOCA_STATUS_FILE`
        if [ "$mocaNewStatus" != "$mocaOldStatus" ]; then
	        echo "`/bin/timestamp` Moca link status changed from $mocaOldStatus to $mocaNewStatus " >> $MOCA_LOG_FILE
		doMoCALogging
                echo $mocaNewStatus > $MOCA_STATUS_FILE
                echo 0 > $MOCA_LOG_COUNTER
		exit 0
        fi
fi

if [ ! -f $MOCA_LOG_COUNTER ]; then
	echo 0 > $MOCA_LOG_COUNTER
else
	TIME_COUNTER=$[$(cat $MOCA_LOG_COUNTER) + 1]
	echo $TIME_COUNTER > $MOCA_LOG_COUNTER
	if [ "$TIME_COUNTER" = "15" ]; then
        	echo "********************************  15Min Moca Status Logging Start **********************"
		doMoCALogging
		echo 0 > $MOCA_LOG_COUNTER
        	echo "********************************  15Min Moca Status Logging Stop **********************"
	fi
fi





