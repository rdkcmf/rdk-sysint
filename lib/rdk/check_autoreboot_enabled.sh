#!/bin/sh
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management,LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# Author: Livin Sunny livin_sunny@comcast.com
# ============================================================================

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
