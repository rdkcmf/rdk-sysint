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

export PATH=$PATH:/usr/sbin:/sbin
CRON_SPOOL=/var/spool/cron
# kill any existing crond services
killall crond > /dev/null

#Add Bind Logs to crontab for pacex1
if [ "x$BIND_ENABLED" = "xtrue" ];then
   if [ -f $RDK_PATH/add_bindlogs.sh ]; then
        output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "add_bindlogs.sh"`
        if [ "$output" == "0" ]; then
              sh /lib/rdk/cronjobs_update.sh "add" "add_bindlogs.sh" "* * * * * nice -n 19 sh $RDK_PATH/add_bindlogs.sh"
        fi
   fi
fi
# Regr the log rotate to crontab
if [ -f $RDK_PATH/logRotateDaemon.sh ]; then
     output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "logRotateDaemon.sh"`
     if [ "$output" == "0" ]; then
           sh /lib/rdk/cronjobs_update.sh "add" "logRotateDaemon.sh" "* * * * * nice -n 19 sh $RDK_PATH/logRotateDaemon.sh"
     fi
fi

if [ "$UI_MONITOR_ENABLE" = "true" ]; then
     # Regr the UI Mngr rotate to crontab
     if [ -f $RDK_PATH/uiMngrMonitor.sh ]; then
           output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "uiMngrMonitor.sh"`
           if [ "$output" == "0" ]; then
               sh /lib/rdk/cronjobs_update.sh "add" "uiMngrMonitor.sh" "* * * * * $RDK_PATH/uiMngrMonitor.sh"
           fi
     fi
fi

#if [ -f $RDK_PATH/diskMon.sh ]; then
#      output=`cat /tmp/cron_list | grep diskMon.sh`
#      if [ ! "$output" ]; then
#           echo "0 * * * * sh $RDK_PATH/diskMon.sh" >> /tmp/cron_list
#      fi
#fi

if [ -f $RDK_PATH/disk_threshold_check.sh ]; then
      output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "disk_threshold_check.sh"`
      if [ "$output" == "0" ]; then
           if [ "$HDD_ENABLED" = "false" ]; then
                sh /lib/rdk/cronjobs_update.sh "add" "disk_threshold_check.sh" "*/15 * * * * nice -n 19 sh $RDK_PATH/disk_threshold_check.sh 1"
           else
                sh /lib/rdk/cronjobs_update.sh "add" "disk_threshold_check.sh" "*/20 * * * * nice -n 19 sh $RDK_PATH/disk_threshold_check.sh 1"
           fi
      fi
fi

if [ -f $RDK_PATH/mocaStatusLogger.sh ]; then     
       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "mocaStatusLogger.sh"`
       if [ "$output" == "0" ]; then
             sh /lib/rdk/cronjobs_update.sh "add" "mocaStatusLogger.sh" "0 * * * * nice -n 19 sh $RDK_PATH/mocaStatusLogger.sh"
       fi
fi

if [ -f $RDK_PATH/upstreamNwStatusLogger.sh ]; then     
       if [ -f /opt/upstreamStats.txt ]; then
             rm /opt/upstreamStats.txt
       fi

       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "upstreamNwStatusLogger.sh"`
       if [ "$output" == "0" ]; then
             sh /lib/rdk/cronjobs_update.sh "add" "upstreamNwStatusLogger.sh" "*/2 * * * * nice -n 19 sh $RDK_PATH/upstreamNwStatusLogger.sh"
       fi
fi

if [ -f $RDK_PATH/decoderStatusLogger.sh ]; then
       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "decoderStatusLogger.sh"`
       if [ "$output" == "0" ]; then
             sh /lib/rdk/cronjobs_update.sh "add" "decoderStatusLogger.sh" "*/10 * * * * nice -n 19 sh $RDK_PATH/decoderStatusLogger.sh"
       fi
fi

if [ -f $RDK_PATH/dmesg-logs-timestamp.sh ] && [ -f $RDK_PATH/dmesg_logs.sh ]; then
       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "dmesg-logs-timestamp.sh"`
       if [ "$output" == "0" ]; then
            sh /lib/rdk/cronjobs_update.sh "add" "dmesg-logs-timestamp.sh" "*/5 * * * * nice -n 19 sh $RDK_PATH/dmesg-logs-timestamp.sh" 
       fi
fi


if [ -f $RDK_PATH/hddStatusLogger.sh ]; then     
    if [ "x$DEVICE_NAME" != "xRNG150" ] && [ ! -f /etc/os-release ]; then
       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "hddStatusLogger.sh"`
       if [ "$output" == "0" ]; then
             sh /lib/rdk/cronjobs_update.sh "add" "hddStatusLogger.sh" "*/30 * * * * nice -n 19 sh $RDK_PATH/hddStatusLogger.sh"
       fi
    fi
fi

if [ "$DEVICE_NAME" == "X1" ]  && [ -f /etc/os-release ]; then
   if [ -f $RDK_PATH/vitalProcessInfo.sh ]; then
      output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "vitalProcessInfo.sh"`
      if [ "$output" == "0" ]; then
            sh /lib/rdk/cronjobs_update.sh "add" "vitalProcessInfo.sh" "*/10 * * * * nice -n 19 sh $RDK_PATH/vitalProcessInfo.sh | /usr/local/bin/logger -t vitalProcessInfo.sh"
      fi
   fi
   if [ -f $RDK_PATH/getGdlFreeMemory.sh ]; then
      output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "getGdlFreeMemory.sh"`
      if [ "$output" == "0" ]; then
            sh /lib/rdk/cronjobs_update.sh "add" "getGdlFreeMemory.sh" "*/10 * * * * nice -n 19 sh $RDK_PATH/getGdlFreeMemory.sh | /usr/local/bin/logger -t getGdlFreeMemory.sh"
      fi
   fi
   if [ -f $RDK_PATH/hddStatusLogger.sh ]; then
      output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "hddStatusLogger.sh"`
      if [ "$output" == "0" ]; then
            sh /lib/rdk/cronjobs_update.sh "add" "hddStatusLogger.sh" "*/30 * * * * nice -n 19 sh $RDK_PATH/hddStatusLogger.sh"
      fi
   fi
fi

if [ "$ENABLE_MULTI_USER" = "true" ];then
   if [ -d /var/spool ] || [ -h /var/spool ];then
     chown -R root /var/spool/*
     chgrp -R root /var/spool/*
   fi
fi
# Starting the cron service
crond -b -L /dev/null -c ${CRON_SPOOL}
