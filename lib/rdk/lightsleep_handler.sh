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
    if [ "x$SYSLOG_NG_ENABLED" == "xtrue" ];then
	    echo "Triggering update_syslog_config.sh"
	    sh /lib/rdk/update_syslog_config.sh
    fi
    while [ true ]
    do
        sleep 60
        if [ -f /tmp/.power_on ];then
             echo "Box is in Power ON mode from STANDBY..! exiting" >> $LOG_FILE
             rm -rf /tmp/.lightsleep_on
    	     if [ "x$SYSLOG_NG_ENABLED" == "xtrue" ];then
	         echo "Triggering update_syslog_config.sh"
	         sh /lib/rdk/update_syslog_config.sh
     	     fi
             exit 0
        fi
        count=`expr $count + 1`
        if [ $count -eq 30 ];then
             echo "Intermediate logs sync from journalctl buffer..!" >> $LOG_FILE
             touch /tmp/.intermediate_sync
             count=0
             if [ "x$MODEL_NUM" == "xPX001AN" -o "x$SYSLOG_NG_ENABLED" == "xtrue" ];then
                 if [ -f /etc/os-release ];then
		      echo "Triggering update_syslog_config.sh"
                      sh /lib/rdk/update_syslog_config.sh
                 fi
             fi
        fi
    done
fi
