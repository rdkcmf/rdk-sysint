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

coaxConnected=1 

if [ -f /lib/rdk/isMocaNetworkUp.sh ]; then
    mocaNetworkUp=`/lib/rdk/isMocaNetworkUp.sh`
else
    mocaNetworkUp=1
fi

if [ $coaxConnected -eq 0 ]
then
  echo 1
elif [ $mocaNetworkUp -eq 0 ]
then
  echo 2
else
  echo 0
fi 
