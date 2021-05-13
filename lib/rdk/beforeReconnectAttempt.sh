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

if [ "$DEVICE_TYPE" = "hybrid" ]; then
     if [ -f /usr/bin/rmfapicaller ]; then
          /usr/bin/rmfapicaller vlDsgCheckAndRecoverConnectivity
     else
          echo "Missing the rmfapicaller for vlDsgCheckAndRecoverConnectivity..!"
     fi
else
     if [ -f /mnt/nfs/bin/vlapicaller ]; then
          /mnt/nfs/bin/vlapicaller vlDsgCheckAndRecoverConnectivity
     else
          echo "Missing the vlapicaller for vlDsgCheckAndRecoverConnectivity..!"
     fi
fi
