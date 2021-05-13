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
##################################################################
## Script to start Device Configuration Management script
## Author: Ajaykumar/Shakeel/Suraj
##################################################################
. /etc/include.properties
. /etc/device.properties

REBOOT_FLAG=0
CHECKON_REBOOT=1

if [ "$BUILD_TYPE" = "dev" ]; then
    DCM_LOG_SERVER="10.253.97.249"
    DCM_LOG_SERVER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogServerDEVUrl 2>&1)
    LOG_SERVER="10.253.97.249"
    DCM_SCP_SERVER="10.253.97.249"
elif [ "$BUILD_TYPE" = "cqa" ]; then
    DCM_LOG_SERVER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogServerCQAUrl  2>&1)
else
    DCM_LOG_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogUrl 2>&1)
    DCM_LOG_SERVER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogServerPRODUrl 2>&1)
    LOG_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.LogServerUrl 2>&1)
    DCM_SCP_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmScpServerUrl 2>&1)
fi

if [[ -z $DCM_LOG_SERVER || -z $DCM_LOG_SERVER_URL || -z $LOG_SERVER || -z $DCM_SCP_SERVER ]]; then
    echo "DCM params read using RFC/tr181 is empty..!!!"
    . /etc/dcm.properties
fi

if [ -f "$RDK_PATH/DCMscript.sh" ]
then
    sh $RDK_PATH/DCMscript.sh $DCM_LOG_SERVER $DCM_LOG_SERVER_URL $LOG_SERVER $REBOOT_FLAG $CHECKON_REBOOT &
else
    echo "$RDK_PATH/DCMscript.sh file not found."
fi
