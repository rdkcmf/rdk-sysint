#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################


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





