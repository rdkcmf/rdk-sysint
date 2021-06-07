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
