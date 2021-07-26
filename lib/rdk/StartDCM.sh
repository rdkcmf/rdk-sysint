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
    if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
        echo "Build type is $BUILD_TYPE and has overriden /opt/dcm.properties . Configurable service end-points for RDK connections will not be used !!!"
    else
        DCM_LOG_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogUrl 2>&1)
        DCM_LOG_SERVER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmLogServerPRODUrl 2>&1)
        LOG_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.LogServerUrl 2>&1)
        DCM_SCP_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcmScpServerUrl 2>&1)
    fi
fi

if [[ -z $DCM_LOG_SERVER || -z $DCM_LOG_SERVER_URL || -z $LOG_SERVER || -z $DCM_SCP_SERVER ]]; then
    echo "DCM params read using RFC/tr181 is empty..!!!"
    if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
        . /opt/dcm.properties
    else
        . /etc/dcm.properties
    fi
fi

if [ -f "$RDK_PATH/DCMscript.sh" ]
then
    sh $RDK_PATH/DCMscript.sh $DCM_LOG_SERVER $DCM_LOG_SERVER_URL $LOG_SERVER $REBOOT_FLAG $CHECKON_REBOOT &
else
    echo "$RDK_PATH/DCMscript.sh file not found."
fi
