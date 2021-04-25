#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# ============================================================================
#
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
        calc_epoc=$(date "+%s" -d $start_time_hr:$start_time_min:$start_time_sec)
        curr_epoc=$(date "+%s")
        sec=$((calc_epoc-curr_epoc))
        if [ $sec -le 0 ]
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

