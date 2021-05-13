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
loop=1
while [ $loop -eq 1 ]
do
  sleep 1
  ps | grep mpeos-main | grep -v grep > /dev/null
  if [ $? -ne 0 ]; then
	date "+%Y%m%d%H%M.%S" > /opt/.systime
  else
	echo "updateSysTime.sh : mpeos started"
	exit 0
  fi
done
