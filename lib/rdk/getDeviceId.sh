#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2019 RDK Management, LLC. All rights reserved.
# ============================================================================

deviceIdFile="/opt/www/authService/deviceid.dat"
partnerIdFile="/opt/www/authService/partnerId3.dat"
wbDeviceIdFile="/opt/www/whitebox/wbdevice.dat"

defaultPartnerId="comcast"

deviceId=""
partnerId=""

if [ -f "${deviceIdFile}" ]; then
    deviceId=`cat ${deviceIdFile}`
elif [ -f "${wbDeviceIdFile}" ]; then
    deviceId=`cat "${wbDeviceIdFile}"`
fi

if [ -f "${partnerIdFile}" ]; then
    partnerId=`cat ${partnerIdFile}`
elif [ "x${deviceId}" != "x" ]; then
    partnerId=${defaultPartnerId}
fi

echo "{ \"deviceId\" : \"${deviceId}\", \"partnerId\" : \"${partnerId}\" }"
