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
if [ $# -ne 1 ]
then
  echo "Usage: setDeviceName.sh <deviceName>"
  exit 1
fi

echo -e 't2p:msg\n{"setDLNAProperties" : {"friendlyName": '$1'\n}}\nt2p:msg' | nc localhost 3773
