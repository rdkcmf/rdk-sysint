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

