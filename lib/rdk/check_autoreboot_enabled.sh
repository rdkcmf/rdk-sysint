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


# This script with check if the tr181 AutoReboot parameter
# is enabled/not for every restart.

if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi
# lets sleep for 30 min for updating time via NTP.
sleep 1800
AutoReboot=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AutoReboot.Enable 2>&1 > /dev/null)
#Currenty for Platco only
if [ "x$DEVICE_NAME" = "xPLATCO" ] && [ "x$AutoReboot" = "xtrue" ]
then
    sh /lib/rdk/ScheduleAutoReboot.sh 1
fi
