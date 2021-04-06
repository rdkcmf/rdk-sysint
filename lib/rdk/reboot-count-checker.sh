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

if [ -f /etc/include.properties ];then
	. /etc/include.properties
else
	echo "Missing Generic Property file.."
fi

if [ -f /etc/device.properties ];then
	. /etc/device.properties
else
	echo "Missing Device Property file.."
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

service=$1
extn="_restart_count"

rebootCounterCheck()
{
   process=$1
   logFile=$2
   if [ ! -f /opt/.$process$extn ];then
        count=1
	echo 1 > /opt/.$process$extn 
   else
        count=`cat /opt/.$process$extn`
        count=`expr $count + 1`
        echo $count > /opt/.$process$extn
   fi
   if [ $count -gt 10 ];then
        echo "`/bin/timestamp`-----Box has rebooted 10 times.. no more reboot----" >> $logFile
        t2CountNotify "SYST_ERR_MaxReboots"
   else
        count=1
        if [ -f /opt/.upload_on_startup ];then
              count=20
        fi
        while [ $count -lt 20 ]
        do
            count=`expr $count + 1`
            sleep 2
            if [ ! -d /tmp/.uploadCoredumps.lock.d ] && [ ! -d /tmp/.uploadMinidumps.lock.d ];then
                 count=20
            fi
        done
        /bin/systemctl start dump-log.service
        # adding a sleep to ensure the log sync
        sleep 5
        x=0
        while [ ! -f /tmp/coredump_mutex_release ]
        do
             x=`expr $x + 1`
             sleep 1
             if [ $x -eq 10 ];then break; fi
        done
        #update dependency failure
        systemctl -l status -n 25 $1  | grep -i "Dependency failed"
        if [ 0 -eq $? ];then
            /rebootNow.sh  -s $3 -o "due to service dependency failure"
        else
            # -c to indicate crash
            /rebootNow.sh -c $3
        fi
   fi
}

if [ "$service" ];then
      case $service in
	"rmfstreamer")
                touch /opt/.upload_on_startup
                if [ "$DEVICE_TYPE" != "mediaclient" ];then
		     rebootCounterCheck rmfstreamer $LOG_PATH/ocapri_log.txt "rmfStreamer"
                else
		     echo "Restart of service needed here..!" >> $LOG_PATH/rmfstr_log.txt
                fi
		;;
	"runpod")
                touch /opt/.upload_on_startup
		rebootCounterCheck runpod $LOG_PATH/ocapri_log.txt "runPod"
		;;
	"iarmbusd")
		rebootCounterCheck iarmbusd $LOG_PATH/uimgr_log.txt "IARMDaemonMain"
		;;
	"dsmgr")
		rebootCounterCheck dsmgr $LOG_PATH/uimgr_log.txt "dsMgrMain"
		;;
	*)
		echo "Unknown Argument: $service" >> /opt/logs/rebootInfo.log
		echo "Unknown Service not in the reboot list" >> /opt/logs/rebootInfo.log
		;;
	esac
else
	echo "Unknown Argument: $0 $service"
	exit 0
fi
