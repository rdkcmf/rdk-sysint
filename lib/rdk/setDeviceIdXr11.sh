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
setDeviceId()
{
  deviceId=`wget -q -O- http://localhost:50050/device/getDeviceId |  sed -e 's/.*deviceId\"\:\"//' -e 's/\".*$//'`
  echo did:$deviceId
  deviceIdLength=${#deviceId}
  
  if [ $deviceIdLength -gt 0 ] ; then
     /usr/bin/IARMTestApplication -u did:$deviceId
     echo "setting deviceId for Xr-11 successful"
  else
     echo "Cannot read deviceId"
  fi
}

getDeviceId()
{
  deviceId=`wget -q -O- http://localhost:50050/device/getDeviceId |  sed -e 's/.*deviceId\"\:\"//' -e 's/\".*$//'`  
  echo $deviceId
}

echo "setting deviceId for Xr-11"
  setDeviceId
