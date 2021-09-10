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

######################################################################
##    * Get the start time of the maintaince from persistent memory 
########################################################################



#############################################################
##                  Variables
#############################################################

OPT_START_TIME_FILE=/opt/maintainence_start_time.txt
LOG_PATH=/opt/logs/

IARM_BUS_DCM_NEW_START_TIME_EVENT=1

#############################################################
##                 Function
##############################################################

StartTime_eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ];
    then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2 $3
    fi
}

#############################################################
##                  Main
############################################################

if [ -f "$OPT_START_TIME_FILE" ]; then
    
    start_time_sec=`grep "sec" $OPT_START_TIME_FILE  | cut -d ":" -f2`
    start_time_min=`grep "min" $OPT_START_TIME_FILE  | cut -d ":" -f2`
    start_time_hr=`grep "hours" $OPT_START_TIME_FILE  | cut -d ":" -f2`

    echo "`/bin/timestamp` start time got from persistent file : $start_time_hr:$start_time_min:$start_time_sec" >> $LOG_PATH/dcmscript.log
 
    if [ $start_time_hr  -le 24 ] && [ $start_time_min -le 60 ] && [ $start_time_sec -le 60 ] 
    then 
        calc_epoc=$(date -u "+%s" -d $start_time_hr:$start_time_min:$start_time_sec)
        curr_epoc=$(date -u "+%s")
        sec=$((calc_epoc-curr_epoc))
        # bump the maintenance start time returned by Xconf by 24 hours
        # if it is within 4 hours of the current time.
        if [ $sec -le 14400 ]
        then
           calc_epoc=$((calc_epoc+86399))
        fi
        StartTime_eventSender "MaintenanceMGR" $IARM_BUS_DCM_NEW_START_TIME_EVENT $calc_epoc   
        echo $calc_epoc
    else
       echo "`/bin/timestamp` start time values in persistent file is not proper" >> $LOG_PATH/dcmscript.log
       echo -1
    fi
else
    #persistent file not found 
    echo "`/bin/timestamp` start time persistent file not found" >> $LOG_PATH/dcmscript.log
    echo -1
fi

