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

. /etc/device.properties
TR181_BIN="/usr/bin/tr181"

if [ -f "$TR181_BIN" ]; then
    serialNum=`tr181 Device.DeviceInfo.SerialNumber 2>&1 > /dev/null`
else #For Other device models
    serialNum=`cat /proc/cmdline | awk -F"[ ]" '{for(i=1;i<=NF;i++){print $(i)} }' | grep serial_number | cut -d "=" -f2`
fi

#check for empty value
if [ -z "$serialNum" ]; then
    serialNum="Not Available"
fi

echo $serialNum

