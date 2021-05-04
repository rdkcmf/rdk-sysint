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
. /etc/include.properties
. /etc/device.properties

TEMP_LOG="/tmp/logs/messages.txt"
RTL_LOG_FILE="$LOG_PATH/dcmscript.log"

if [ "$LIGHTSLEEP_ENABLE" == "true" ] && [ -f /tmp/.standby ]; then
    if [ ! -d /tmp/logs ] ;then
        mkdir /tmp/logs
    fi
    if [ -f /lib/rdk/cpu-statistics.sh ];then
        sh /lib/rdk/cpu-statistics.sh >> $TEMP_LOG
    fi
    if [ -f /lib/rdk/vm-statistics.sh ];then
        sh /lib/rdk/vm-statistics.sh >> $TEMP_LOG
    fi
    if [ -f /lib/rdk/temperature-telemetry.sh ];then
        sh /lib/rdk/temperature-telemetry.sh >> $TEMP_LOG
    fi
    exit 0
else
    if [ -f $TEMP_LOG ] && [ -f /etc/os-release ]; then
        cat $TEMP_LOG >> $LOG_PATH/messages.txt
        rm $TEMP_LOG
    fi
    if [ -f /lib/rdk/cpu-statistics.sh ];then
        echo "Retrieving CPU instantaneous information for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/cpu-statistics.sh >> $LOG_PATH/messages.txt
    fi
    if [ -f /lib/rdk/vm-statistics.sh ];then
        echo "Retrieving virtual memory information for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/vm-statistics.sh >> $LOG_PATH/messages.txt
    fi
    if [ -f /lib/rdk/temperature-telemetry.sh ];then
        echo "Retrieving CPU Temperature for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/temperature-telemetry.sh >> $LOG_PATH/messages.txt
    fi
fi
