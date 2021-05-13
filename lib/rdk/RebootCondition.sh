#!/bin/sh
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management,LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# Author: Livin Sunny livin_sunny@comcast.com
# ============================================================================

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
