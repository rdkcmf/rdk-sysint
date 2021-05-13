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

if [ "$LIGHTSLEEP_ENABLE" != "true" ] || [ -f /tmp/.lightsleep_on ] ; then exit; fi

LOG_FILE=$LOG_PATH/lightsleep.log

getHDState()
{
	hdparm -C /dev/sda | grep standby 
	if [ $? -ne 0 ]; then
		echo 'poweron'
	else
		echo 'standby'
	fi    
}

touch /tmp/.lightsleep_on
hdstate=`getHDState`
echo `/bin/timestamp` Disk power state is $hdstate >> $LOG_FILE

if [ -f /tmp/.power_on ];then
      echo "Box is in Power ON mode, journalctl will sync the logs..!" >> $LOG_FILE
      rm -rf /tmp/.lightsleep_on
      exit 0
else
    count=0
    echo "Starting the lightsleep monitoring..!" >> $LOG_FILE
    while [ true ]
    do
        sleep 60
        if [ -f /tmp/.power_on ];then
             echo "Box is in Power ON mode from STANDBY..! exiting" >> $LOG_FILE
             rm -rf /tmp/.lightsleep_on
             exit 0
        fi
        count=`expr $count + 1`
        if [ $count -eq 30 ];then
             echo "Intermediate logs sync from journalctl buffer..!" >> $LOG_FILE
             touch /tmp/.intermediate_sync
             count=0
             if [ "x$MODEL_NUM" == "xPX001AN" ];then
                 if [ -f /etc/os-release ];then
                      sh /lib/rdk/update_syslog_config.sh
                 fi
             fi
        fi
    done
fi
