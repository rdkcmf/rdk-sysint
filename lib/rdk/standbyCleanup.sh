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

if [ ! -z $1 ] && [ $1 == "--forceShutdown" ];then
  echo "Forcing shutdown without checking RFC"
  /lib/rdk/shutdownReceiver.sh &
else
  _keepReceiverProcessOnStandby=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.KeepReceiverProcessOnStandby.Enable 2>&1 > /dev/null`
  if [ ! -z "$_keepReceiverProcessOnStandby" ]; then
    if [ -f /tmp/retainConnection ] && [[ $_keepReceiverProcessOnStandby == "true" ]]; then
      echo "RFC KeepReceiverProcessOnStandby defined and approved by XRE - Don't shutdown receiver process"
    else
      echo "RFC KeepReceiverProcessOnStandby is not true or RDK-22152 is not approved by XRE - shutdown receiver process"
      /lib/rdk/shutdownReceiver.sh &
    fi
  else
    echo "RFC KeepReceiverProcessOnStandby not defined - shutdown receiver process"
    /lib/rdk/shutdownReceiver.sh &
  fi
fi
