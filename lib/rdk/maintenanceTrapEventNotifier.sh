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
## Script to notify MAINTENANCE MANAGER when a  script is trapped.
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

. /lib/rdk/utils.sh

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ];
    then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

MAINT_DCM_ERROR=1
MAINT_RFC_ERROR=3
MAINT_LOGUPLOAD_ERROR=5
MAINT_FWDOWNLOAD_ERROR=9

#--------------------------------------------------------------------------------------------
# Arguments
#--------------------------------------------------------------------------------------------
if [ -z "$1" ]
  then
    echo "Please pass one agrument atleast to process the request"
    exit 0
fi

Script_Trapped=$1

#if any arguments can be added here

#---------------------------------------------------------------------------------------------
# Variables
#---------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------------------

#DCM trapped
if [ $Script_Trapped -eq 0 ]
  then
    echo "`/bin/timestamp` DCM is trapped and killed in between because of StopMaintenance API in MM plugin" >> $LOG_PATH/tasklogger.log
    echo "`/bin/timestamp` Posting  Events fori DCM, RFC, SWUPDATE and LOGUPLOAD" >> $LOG_PATH/tasklogger.log
    eventSender "MaintenanceMGR" $MAINT_DCM_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_RFC_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
fi

#RFC trapped
if [ $Script_Trapped -eq 1 ]
  then
    echo "`/bin/timestamp` RFC is trapped and killed in between because of StopMaintenance API in MM plugin" >> $LOG_PATH/tasklogger.log
    echo "`/bin/timestamp` Posting  Events for RFC, SWUPDATE and LOGUPLOAD" >> $LOG_PATH/tasklogger.log
    eventSender "MaintenanceMGR" $MAINT_RFC_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
fi

#FWDOWNLOAD trapped
if [ $Script_Trapped -eq 2 ]
  then
    echo "`/bin/timestamp` FWDLND is trapped and killed in between because of StopMaintenance API in MM plugin" >> $LOG_PATH/tasklogger.log
    echo "`/bin/timestamp` Posting  Events for FWDOWNLOAD and LOGUPLOAD" >> $LOG_PATH/tasklogger.log
    eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    sleep 1
    eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
fi

#LOGUPLOAD trapped
if [ $Script_Trapped -eq 3 ]
  then
    echo "`/bin/timestamp` LOGUPLOAD is trapped and killed in between because of StopMaintenance API in MM plugin" >> $LOG_PATH/tasklogger.log
    echo "`/bin/timestamp` Posting  Events for LOGUPLOAD" >> $LOG_PATH/tasklogger.log
    eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
fi



