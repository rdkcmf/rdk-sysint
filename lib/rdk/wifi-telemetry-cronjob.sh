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

# Look whether we have already installed cron job for this
tCheck=`sh /lib/rdk/cronjobs_update.sh "check-entry" "wifi-telemetry-cronjob.sh"`
if [ "$tCheck" != "0" ]; then
    # This means, the cron job is install already and execution of this thread is triggered by cron
    systemctl start wifi-telemetry.service
    exit
fi

# Get the RFC..  If RFC is not enabled, set both samplingInterval and Logging Interval to 900s as same as existing code.
if [ ! -f /lib/rdk/isFeatureEnabled.sh ]; then
    echo "No logic to verify the Feature is enabled or not. Assuming RFC_ENABLE_WIFI_TM_DC is false"
    exit
fi

dateVariable=`date "+%Y %b %d %H:%M.%S.%6N"`

. /lib/rdk/isFeatureEnabled.sh WIFI_TM_DC

if [ "$RFC_ENABLE_WIFI_TM_DC" == "true" ] || [ "$RFC_ENABLE_WIFI_TM_DC" == "1" ] ; then
    samplingInterval=$RFC_DATA_WIFI_TM_DC_SAMPLE_INT
    loggingInterval=$RFC_DATA_WIFI_TM_DC_LOG_INT

    echo "$dateVariable RFC_ENABLE_WIFI_TM_DC is $RFC_ENABLE_WIFI_TM_DC" >> /opt/logs/wifi_telemetry.log
    echo "$dateVariable RFC_DATA_WIFI_TM_DC_SAMPLE_INT is $RFC_DATA_WIFI_TM_DC_SAMPLE_INT" >> /opt/logs/wifi_telemetry.log
    echo "$dateVariable RFC_DATA_WIFI_TM_DC_LOG_INT is $RFC_DATA_WIFI_TM_DC_LOG_INT" >> /opt/logs/wifi_telemetry.log
else
    echo "$dateVariable RFC_ENABLE_WIFI_TM_DC is false" >> /opt/logs/wifi_telemetry.log
    # Remove the cron job if it is disabled by the RFC Server
    if [ "$tCheck" != "0" ]; then
        sh /lib/rdk/cronjobs_update.sh "remove" "wifi-telemetry-cronjob.sh"
    fi
    exit
fi

#Cron does not support seconds based timer.. So calculate the time in mins
iterationCnt=`expr $samplingInterval / 60`
variable="*/$iterationCnt * * * * /bin/sh /lib/rdk/wifi-telemetry-cronjob.sh >> /opt/logs/wifi_telemetry.log"

# Set new cron job from the file            
sh /lib/rdk/cronjobs_update.sh "add" "wifi-telemetry-cronjob.sh" "$variable"
# End of Script
