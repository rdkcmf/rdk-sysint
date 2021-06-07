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
. /etc/env_setup.sh

processCheck()
{
   count=`pidof $1 | wc -w`
   if [ $count -eq 0 ]; then
        echo "1"
   else
        echo "0"
   fi
}


getMacAddress()
{
     ifconfig -a | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5
} 

syncLog()
{
    cWD=`pwd`
    syncPath=`find $TEMP_LOG_PATH -type l -exec ls -l {} \; | cut -d ">" -f2 | tr -d ' '`
    if [ "$syncPath" != "$LOG_PATH" ] && [ -d "$TEMP_LOG_PATH" ]; then
         cd "$TEMP_LOG_PATH"
         for file in `ls *.txt *.log`
         do
            cat $file >> $LOG_PATH/$file
            cat /dev/null > $file
         done
         cd $cWD
    else
         echo "Sync Not needed, Same log folder"
    fi
}

rebootFunc()
{
    sync
    if [ ! -f $PERSISTENT_PATH/.lightsleepKillSwitchEnable ]; then
        syncLog

        if [ -f $TEMP_LOG_PATH/.systime ]; then
	    cp $TEMP_LOG_PATH/.systime $PERSISTENT_PATH/
        fi  
    fi
    if [[ $1 == "" ]] && [[ $2 == "" ]]; then
        process=`cat /proc/$PPID/cmdline`
        reason="Rebooting by calling rebootFunc of utils.sh script..."
    else
        process=$1
        reason=$2
    fi
    sh /rebootNow.sh -s $process -o $reason
}


# Return system uptime in seconds
Uptime()
{
     cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}

