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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

SCRIPT_NAME=$(basename "$0")

if [ ! -d "/tmp/AR" ]
then
    mkdir /tmp/AR
fi
if [ ! -d "/opt/AR" ]
then
    mkdir /opt/AR
fi

#Check the arguments count
if [ "$#" -ne 1 ]
then
    echo "**************************************************"
    echo "Usage: $SCRIPT_NAME <Boolean Value>"
    echo "**************************************************"
    exit 1
fi

CRONTAB_DIR="/var/spool/cron/"
CRONTAB_FILE=$CRONTAB_DIR"root"

. /lib/rdk/RebootCondition.sh

FILE_LOCK="/tmp/AR/AutoReboot.lock"
MAX_RETRY_COUNT=10
count=0

#Only one process should schedule cron at a time
while : ; do
    if [ $count -lt $MAX_RETRY_COUNT ]
    then
        if [ -f $FILE_LOCK ]
        then
            echo "$(timestamp) [ScheduleAutoReboot.sh]:another instance is running" >> "$AR_LOG_FILE"
            sleep 1;
            count=$((count+1))
            echo "$(timestamp) Retry count = $count" >> "$AR_LOG_FILE"
            continue;
        else
            # Creating lock to allow one process at a time
            touch $FILE_LOCK
            break;
        fi
    else
        echo "$(timestamp) [ScheduleAutoReboot.sh]: Exiting, another instance is running and max retry reached" >> "$AR_LOG_FILE"
        exit 1
    fi
done

if [ "$1" == "0" ]
then
    Removecron
    rm -f $FILE_LOCK
    exit
fi

calcRebootExecTime()
{
    # Extract maintenance window start and end time
    ExtractMaintenanceTime

    #get local time offset
    if [ -f "$TZ_FILE" ]
    then
        TZ=$(cat "$TZ_FILE")
        #grab offset from UTC
        tz_offset="$(TZ="$TZ" date +"%z" | sed 's/^+0*//' | sed 's/^-0*/-/')"
        tz_offset_hr=$((tz_offset / 100))
        tz_offset_min=$((tz_offset % 100))
        time_offset=$((tz_offset_hr*60*60 + tz_offset_min*60))
    else
        # we dont have the TZ file
        time_offset="$DEF_TIME_OFFSET"
    fi

    #incase if we need to manully override the offset.
    if [ -f "$TIME_OFFSET" ]
    then
        time_offset=$(cat "$TIME_OFFSET")
        echo "$(timestamp) [ScheduleAutoReboot.sh] User set time offset is $time_offset" >> "$AR_LOG_FILE"
    fi

    echo "$(timestamp) [ScheduleAutoReboot.sh] time offset is $time_offset" >> "$AR_LOG_FILE"

    main_start_time=$((start_time-time_offset))
    main_end_time=$((end_time-time_offset))

    #calculate random time in sec
    rand_time_in_sec=$(awk -v min=$main_start_time -v max=$main_end_time -v seed="$(date +%N)" 'BEGIN{srand(seed);print int(min+rand()*(max-min+1))}')

    # To avoid cron to be set beyond 24 hr clock limit
    if [ "$rand_time_in_sec" -ge 86400 ]
    then
        rand_time_in_sec=$((rand_time_in_sec-86400))
        echo "$(timestamp) [ScheduleAutoReboot.sh] Random time in sec exceed 24 hr limit. Setting it correct limit" >> "$AR_LOG_FILE"
    elif [ "$rand_time_in_sec" -le 0 ]
    then
        rand_time_in_sec=$((rand_time_in_sec+86399))
        echo "$(timestamp) [ScheduleAutoReboot.sh] Random time in sec negative. Setting it correct limit" >> "$AR_LOG_FILE"
    fi

    rand_time=$((rand_time_in_sec))
    #conversion of random generated time to HH:MM:SS format
    #calculate random second
    rand_sec=$((rand_time%60))

    #calculate random minute
    rand_time=$((rand_time/60))
    rand_min=$((rand_time%60))

    #calculate random hour
    rand_time=$((rand_time/60))
    rand_hr=$((rand_time%60))

    # correct main_start_time if rollover
    if [ "$main_start_time" -ge 86400 ]
    then
        main_start_time=$((main_start_time-86400))
    elif [ "$main_start_time" -le 0 ]
    then
        main_start_time=$((main_start_time+86399))
    fi

    # correct main_end_time if rollover
    if [ "$main_end_time" -ge 86400 ]
    then
        main_end_time=$((main_end_time-86400))
    elif [ "$main_end_time" -le 0 ]
    then
        main_end_time=$((main_end_time+86399))
    fi
    
    # figure out the day (in UTC to match the start end times above)
    cur_hr="$(date +'%H' | sed 's/^0//')"
    cur_min="$(date +'%M' | sed 's/^0//')"
    cur_sec="$(date +'%S' | sed 's/^0//')"
    cur_time=$((cur_hr*60*60+cur_min*60+cur_sec))

    # if we are after the start of the maintenance window, we'll bump the day
    if [ "$cur_time" -ge "$main_start_time" ]
    then
       rand_day="$(date -d@"$(( `date +%s`+86399))" +'%d' | sed 's/^0*//')"
       rand_mon="$(date -d@"$(( `date +%s`+86399))" +'%m' | sed 's/^0*//')"
    else
       rand_day="$(date +'%d' | sed 's/^0//')"
       rand_mon="$(date +'%m' | sed 's/^0//')"
    fi

    echo "$(timestamp) [ScheduleAutoReboot.sh] start_time: $start_time, end_time: $end_time" >> "$AR_LOG_FILE"
    echo "$(timestamp) [ScheduleAutoReboot.sh] time_offset: $time_offset" >> "$AR_LOG_FILE"
    echo "$(timestamp) [ScheduleAutoReboot.sh] main_start_time: $main_start_time , main_end_time= $main_end_time" >> "$AR_LOG_FILE"
    echo "$(timestamp) [ScheduleAutoReboot.sh] rand_time_in_sec: $rand_time_in_sec ,rand_hr: $rand_hr ,rand_min: $rand_min ,rand_sec: $rand_sec ,day: $rand_day ,month: $rand_mon" >> "$AR_LOG_FILE"

}

ScheduleCron()
{
    output=0 #check cron entry

    output=$(sh /lib/rdk/cronjobs_update.sh "check-entry" "AutoReboot.sh")

    echo "$(timestamp) [ScheduleAutoReboot.sh] Auto Reboot is Scheduled at: $rand_hr:$rand_min on $rand_mon/$rand_day" >> "$AR_LOG_FILE"

    if [ "$output" == "0" ]
    then
        echo "$(timestamp) [ScheduleAutoReboot.sh] Auto Reboot adding the cron job" >> "$AR_LOG_FILE"

        sh /lib/rdk/cronjobs_update.sh "add" "AutoReboot.sh" "$rand_min $rand_hr $rand_day $rand_mon * /bin/sh /lib/rdk/AutoReboot.sh"  >> "$AR_LOG_FILE"
    else
        echo "$(timestamp) [ScheduleAutoReboot.sh] Auto Reboot updating the cron job" >> "$AR_LOG_FILE"

        sh /lib/rdk/cronjobs_update.sh "update" "AutoReboot.sh" "$rand_min $rand_hr $rand_day $rand_mon * /bin/sh /lib/rdk/AutoReboot.sh"  >> "$AR_LOG_FILE"
    fi
}

# Main caller from here
# schedule one cron job

calcRebootExecTime
if [ -f $CRONTAB_FILE ]
then
    if [ "x$ENABLE_MAINTENANCE" != "xtrue" ]
    then
        ScheduleCron
        echo "$(timestamp) [ScheduleAutoReboot.sh] Auto Reboot cron job succesfully scheduled" >> "$AR_LOG_FILE"
    fi
fi
rm -f $FILE_LOCK
