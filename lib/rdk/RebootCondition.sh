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


set -x

FW_START="/opt/AR/.FirmwareUpgradeStartTime"
FW_END="/opt/AR/.FirmwareUpgradeEndTime"
TIME_OFFSET="/opt/AR/.TimeOffset"
AR_LOG_FILE="/opt/logs/autoreboot.log"
TZ_FILE="/opt/persistent/timeZoneDST"
# Default values are here.
# Window is 300Hrs-500Hrs
DEF_START_TIME=10800
DEF_END_TIME=18000
DEF_TIME_OFFSET=-14400
DEVICE_WAITING_TIME=600 #10 min
ABORT_REBOOT="/tmp/AbortReboot"
DEFER_REBOOT="/tmp/.deferringreboot"
ExtractMaintenanceTime()
{
    # Extract maintenance window start and end time
    if [ -f "$FW_START" ] && [ -f "$FW_END" ]
    then
        start_time=$(cat $FW_START)
        end_time=$(cat $FW_END)
    else
        # Time is  0300Hrs - 0500Hrs
        start_time=$DEF_START_TIME
        end_time=$DEF_END_TIME
    fi

    if [ "$start_time" = "$end_time" ]
    then
        start_time=$DEF_START_TIME
        end_time=$DEF_END_TIME
        echo "$start_time" > $FW_START
        echo "$end_time" > $FW_END
    fi
}

Removecron()
{
    output=0 # status for cron
    echo "$(timestamp) AutoReboot parameter is set to false. Removing the AutoReboot crontab" >> "$AR_LOG_FILE"
    output=$(sh /lib/rdk/cronjobs_update.sh "check_entry" "AutoReboot.sh")
    if [ "$output" != "0" ]
    then
        sh /lib/rdk/cronjobs_update.sh "remove" "AutoReboot.sh"
    fi
}
