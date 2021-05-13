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
  echo "Usage: setVpopEnabled.sh <true|false>"
  exit 1
fi

if [ $1 == "true" ]
then
  echo -e 't2p:msg\n{"setDLNAProperties" : {"dlnaEnabled": true\n}}\nt2p:msg' | nc localhost 3773
else
  echo -e 't2p:msg\n{"setDLNAProperties" : {"dlnaEnabled": false\n}}\nt2p:msg' | nc localhost 3773
fi

